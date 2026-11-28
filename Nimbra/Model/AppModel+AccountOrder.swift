import Foundation
import NimbraCore

/// The accounts' order and profile photos (06 · Mailboxes · Edit accounts): the order is
/// every list of accounts' (Mailboxes, All inboxes, From), as on the Mac.
extension AppModel {
    // MARK: Order

    /// Moves the accounts at `source` before `destination`, as a list's reorder hands
    /// them over (a place in the list before the move). Shown at once, kept by the engine,
    /// and put back as the engine has it when it refuses (the alert says why).
    func moveAccounts(from source: IndexSet, to destination: Int) async {
        guard let first = source.first, source.count == 1, accounts.indices.contains(first) else { return }
        // The engine takes the place after the move.
        let place = destination > first ? destination - 1 : destination
        guard place != first else { return }
        let id = accounts[first].id
        accounts.move(fromOffsets: source, toOffset: destination)
        await engine(for: id, report: true) { try $0.moveAccount(accountId: id, to: UInt32(place)) }
        await reloadAccounts()
    }

    // MARK: Photos

    /// Each account's photo: as kept at once, then as the provider has it now, once per run.
    /// No photo (or none Nimbra may see) leaves the initials. Disk, then network.
    func loadAccountPhotos() async {
        for account in accounts {
            let id = account.id
            if accountPhotos[id] == nil, let kept = await engine(for: id, work: { try $0.keptAccountPhoto(accountId: id) }) ?? nil {
                accountPhotos[id] = kept
            }
        }
        for account in accounts where !photosAsked.contains(account.id) {
            let id = account.id
            photosAsked.insert(id)
            guard let photo = await engine(for: id, work: { try $0.accountPhoto(accountId: id) }) else {
                // Offline: asked again on the next run.
                photosAsked.remove(id)
                continue
            }
            switch photo {
            case .image(let bytes), .unchecked(let bytes): accountPhotos[id] = bytes
            case .noPhoto: accountPhotos[id] = nil
            // Signed in before Nimbra asked for the profile: what was kept stays.
            case .notAllowed: break
            }
        }
    }
}
