//
//  TemporaryRevealCoordinator.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
import MenuBarModel

@MainActor
final class TemporaryRevealCoordinator {
    struct Lease: Hashable, Sendable {
        let identifier: String
        fileprivate let token = UUID()
    }

    private let reveal: (String) -> Void
    private let conceal: (String) -> Void
    private var leases: [String: Set<Lease>] = [:]
    private var expiryTasks: [Lease: Task<Void, Never>] = [:]
    private var namedLeases: [String: [String: Lease]] = [:]

    init(reveal: @escaping (String) -> Void, conceal: @escaping (String) -> Void) {
        self.reveal = reveal
        self.conceal = conceal
    }

    func acquire(_ identifier: String) -> Lease {
        let lease = Lease(identifier: identifier)
        let first = leases[identifier, default: []].isEmpty
        leases[identifier, default: []].insert(lease)
        if first {
            reveal(identifier)
        }
        return lease
    }

    func release(_ lease: Lease) {
        guard leases[lease.identifier]?.remove(lease) != nil else { return }
        expiryTasks.removeValue(forKey: lease)?.cancel()
        if leases[lease.identifier]?.isEmpty == true {
            leases[lease.identifier] = nil
            conceal(lease.identifier)
        }
    }

    func retain(_ identifier: String, owner: String) {
        guard namedLeases[owner]?[identifier] == nil else { return }
        namedLeases[owner, default: [:]][identifier] = acquire(identifier)
    }

    func release(_ identifier: String, owner: String) {
        guard let lease = namedLeases[owner]?.removeValue(forKey: identifier) else { return }
        if namedLeases[owner]?.isEmpty == true {
            namedLeases[owner] = nil
        }
        release(lease)
    }

    func scheduleRelease(_ lease: Lease, after delay: TimeInterval, menuOpen: @escaping @MainActor () async -> Bool) {
        expiryTasks.removeValue(forKey: lease)?.cancel()
        expiryTasks[lease] = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(max(0, delay)))
                while await menuOpen() {
                    try await Task.sleep(for: .milliseconds(250))
                }
                guard !Task.isCancelled else { return }
                self?.release(lease)
            } catch {}
        }
    }
}

@MainActor
private final class ControllerRevealOwnership {
    weak var controller: (any MenuBarSectionControlling)?
    let coordinator: TemporaryRevealCoordinator

    init(_ controller: any MenuBarSectionControlling) {
        self.controller = controller
        coordinator = TemporaryRevealCoordinator(
            reveal: { [weak controller] in controller?.revealItemTemporarily($0) },
            conceal: { [weak controller] in controller?.concealTemporarilyRevealedItem($0) }
        )
    }

    static var owners: [ObjectIdentifier: ControllerRevealOwnership] = [:]

    static func coordinator(for controller: any MenuBarSectionControlling) -> TemporaryRevealCoordinator {
        owners = owners.filter { $0.value.controller != nil }
        let key = ObjectIdentifier(controller)
        if let existing = owners[key] {
            return existing.coordinator
        }
        let ownership = ControllerRevealOwnership(controller)
        owners[key] = ownership
        return ownership.coordinator
    }
}

extension MenuBarSectionControlling {
    var temporaryReveals: TemporaryRevealCoordinator {
        ControllerRevealOwnership.coordinator(for: self)
    }

    @discardableResult
    func revealForInteraction(_ identifier: String, duration: TimeInterval, menuMonitor: MenuOpenMonitor?) -> TemporaryRevealCoordinator.Lease {
        let lease = temporaryReveals.acquire(identifier)
        temporaryReveals.scheduleRelease(lease, after: duration) {
            await menuMonitor?.isAnyMenuOpen() == true
        }
        return lease
    }
}
