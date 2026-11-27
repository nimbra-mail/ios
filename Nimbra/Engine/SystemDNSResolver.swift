import dnssd
import Foundation
import NimbraCore

/// MX lookups for server discovery through the system's resolver (`DNSServiceQueryRecord`):
/// the question goes where every other lookup on the device goes (the network's resolver,
/// or the one the person set), never to a DNS-over-HTTPS service or anyone else. The engine
/// checks what comes back.
nonisolated final class SystemDNSResolver: DnsResolver {
    /// How long a lookup may take before discovery moves on.
    let timeout: Duration

    init(timeout: Duration = .seconds(5)) {
        self.timeout = timeout
    }

    func mx(domain: String) throws -> [MxRecord] {
        let lookup = MXLookup()
        let context = Unmanaged.passRetained(lookup)
        defer { context.release() }

        var service: DNSServiceRef?
        let started = DNSServiceQueryRecord(
            &service,
            // Negative answers too (no such domain, no MX), so they end the wait at once.
            DNSServiceFlags(kDNSServiceFlagsReturnIntermediates),
            0,
            domain,
            UInt16(kDNSServiceType_MX),
            UInt16(kDNSServiceClass_IN),
            mxAnswer,
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
private nonisolated final class MXLookup: @unchecked Sendable {
    var records: [MxRecord] = []
    var failure: DNSServiceErrorType?
    var isDone = false
}

/// The resolver's callback: one answer at a time, `MoreComing` while more wait.
private nonisolated func mxAnswer(
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
    let lookup = Unmanaged<MXLookup>.fromOpaque(context).takeUnretainedValue()
    switch error {
    case DNSServiceErrorType(kDNSServiceErr_NoError):
        let isAdd = flags & DNSServiceFlags(kDNSServiceFlagsAdd) != 0
        if isAdd, type == UInt16(kDNSServiceType_MX), let data,
           let record = MXRecordData.parse(UnsafeRawBufferPointer(start: data, count: Int(length))) {
            lookup.records.append(record)
        }
    case DNSServiceErrorType(kDNSServiceErr_NoSuchRecord), DNSServiceErrorType(kDNSServiceErr_NoSuchName):
        // The domain has no MX records: an answer, not a failure.
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
    static func parse(_ bytes: UnsafeRawBufferPointer) -> MxRecord? {
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
