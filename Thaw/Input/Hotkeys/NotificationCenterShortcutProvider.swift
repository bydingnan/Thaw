//
//  NotificationCenterShortcutProvider.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation

@MainActor
final class NotificationCenterShortcutProvider {
    private let read: @Sendable () -> [SystemNotificationCenterHotkey]
    private var pending: Task<Void, Never>?
    private(set) var shortcuts = [SystemNotificationCenterHotkey]()

    init(read: @escaping @Sendable () -> [SystemNotificationCenterHotkey] = {
        SystemNotificationCenterHotkey.shortcuts()
    }) {
        self.read = read
    }

    @discardableResult
    func refresh(publish: @escaping @MainActor ([SystemNotificationCenterHotkey]) -> Void) -> Task<Void, Never> {
        if let pending {
            return pending
        }
        let task = Task { [weak self, read] in
            let snapshot = await Task.detached(priority: .utility, operation: read).value
            guard let self else { return }
            pending = nil
            guard snapshot != shortcuts else { return }
            shortcuts = snapshot
            publish(snapshot)
        }
        pending = task
        return task
    }
}
