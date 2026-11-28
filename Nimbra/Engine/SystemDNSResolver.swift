import dnssd
import Foundation
import NimbraCore

/// The engine's lookups through the system's resolver (`DNSServiceQueryRecord`): MX records
/// for server discovery and TXT records for brand logos. The question goes where every
/// other lookup on the device goes (the network's resolver, or the one the person set),
/// never to a DNS-over-HTTPS service or anyone else. The engine checks what comes back.
nonisolated final class SystemDNSResolver: DnsResolver {
    /// How long a lookup may take before discovery moves on.
    let timeout: Duration

    init(timeout: Duration = .seconds(5)) {
        self.timeout = timeout
    }

    func mx(domain: String) throws -> [MxRecord] {
        try query(domain, type: kDNSServiceType_MX).compactMap(MXRecordData.parse)
    }

    /// A name's TXT records, each one's character strings joined with nothing between
    /// them. Throwing only means no brand logos.
    func txt(name: String) throws -> [String] {
        try query(name, type: kDNSServiceType_TXT).compactMap(TXTRecordData.parse)
    }

    /// The records of one type a name has (none for no such name or record), each as its
    /// raw data, within the timeout.
    private func query(_ name: String, type: Int) throws -> [[UInt8]] {
        let lookup = Lookup(type: UInt16(type))
        let context = Unmanaged.passRetained(lookup)
        defer { context.release() }

        var service: DNSServiceRef?
        let started = DNSServiceQueryRecord(
            &service,
            // Negative answers too (no such name, no record), so they end the wait at once.
            DNSServiceFlags(kDNSServiceFlagsReturnIntermediates),
            0,
            name,
            UInt16(type),
            UInt16(kDNSServiceClass_IN),
            answer,
            context.toOpaque()
        )
        guard started == DNSServiceErrorType(kDNSServiceErr_NoError), let service else {
            throw DnsError.Failed(message: "The lookup could not start (\(started)).")
        }
        defer { DNSServiceRefDeallocate(service) }

        let socket = DNSServiceRefSockFD(service)
        let deadline = ContinuousClock.now + timeout
        while !lookup.isDone {
            let left = deadline - ContinuousClock.now
            guard left > .zero else { throw DnsError.Failed(message: "The lookup timed out.") }
            var descriptor = pollfd(fd: socket, events: Int16(POLLIN), revents: 0)
            let milliseconds = Int32(clamping: left.components.seconds * 1000 + left.components.attoseconds / 1_000_000_000_000_000)
            let ready = poll(&descriptor, 1, max(milliseconds, 1))
            if ready < 0 {
                if errno == EINTR { continue }
                throw DnsError.Failed(message: "The lookup failed.")
            }
            if ready > 0 {
                let processed = DNSServiceProcessResult(service)
                guard processed == DNSServiceErrorType(kDNSServiceErr_NoError) else {
                    throw DnsError.Failed(message: "The lookup failed (\(processed)).")
                }
            }
        }
        if let failure = lookup.failure {
            throw DnsError.Failed(message: "The lookup failed (\(failure)).")
        }
        return lookup.records
    }
}

/// What one lookup collected. Touched only by the thread that runs it (the callback is
/// called from `DNSServiceProcessResult`, on that same thread).
private nonisolated final class Lookup: @unchecked Sendable {
    /// The record type asked for: answers of another type are left out.
    let type: UInt16
    var records: [[UInt8]] = []
    var failure: DNSServiceErrorType?
    var isDone = false

    init(type: UInt16) { self.type = type }
}

/// The resolver's callback: one answer at a time, `MoreComing` while more wait.
private nonisolated func answer(
    _ service: DNSServiceRef?,
    _ flags: DNSServiceFlags,
    _ interface: UInt32,
    _ error: DNSServiceErrorType,
    _ name: UnsafePointer<CChar>?,
    _ type: UInt16,
    _ recordClass: UInt16,
    _ length: UInt16,
    _ data: UnsafeRawPointer?,
    _ ttl: UInt32,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else { return }
    let lookup = Unmanaged<Lookup>.fromOpaque(context).takeUnretainedValue()
    switch error {
    case DNSServiceErrorType(kDNSServiceErr_NoError):
        let isAdd = flags & DNSServiceFlags(kDNSServiceFlagsAdd) != 0
        if isAdd, type == lookup.type, let data {
            lookup.records.append(Array(UnsafeRawBufferPointer(start: data, count: Int(length))))
        }
    case DNSServiceErrorType(kDNSServiceErr_NoSuchRecord), DNSServiceErrorType(kDNSServiceErr_NoSuchName):
        // The name has no such records: an answer, not a failure.
        break
    default:
        lookup.failure = error
    }
    if flags & DNSServiceFlags(kDNSServiceFlagsMoreComing) == 0 {
        lookup.isDone = true
    }
}

/// An MX record's data: a 16-bit preference, then the host as length-prefixed labels.
nonisolated enum MXRecordData {
    static func parse(_ bytes: [UInt8]) -> MxRecord? {
        guard bytes.count >= 3 else { return nil }
        let preference = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        var labels: [String] = []
        var index = 2
        while index < bytes.count {
            let length = Int(bytes[index])
            index += 1
            if length == 0 {
                // The root: the name is whole.
                return labels.isEmpty ? nil : MxRecord(preference: preference, host: labels.joined(separator: "."))
            }
            // A compression pointer (0b11…) or a label past the end: not a name we can read.
            guard length < 64, index + length <= bytes.count,
                  let label = String(bytes: bytes[index ..< index + length], encoding: .utf8) else { return nil }
            labels.append(label)
            index += length
        }
        return nil
    }
}

/// A TXT record's data: one or more character strings, each a length byte and that many
/// bytes, joined with nothing between them (as a long record is split into strings of at
/// most 255 bytes). Nil when a length runs past the end or the text is not UTF-8.
nonisolated enum TXTRecordData {
    static func parse(_ bytes: [UInt8]) -> String? {
        var text: [UInt8] = []
        var index = 0
        while index < bytes.count {
            let length = Int(bytes[index])
            index += 1
            guard index + length <= bytes.count else { return nil }
            text += bytes[index ..< index + length]
            index += length
        }
        return String(bytes: text, encoding: .utf8)
    }
}
