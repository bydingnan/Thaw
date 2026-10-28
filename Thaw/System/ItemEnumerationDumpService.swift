//
//  ItemEnumerationDumpService.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit

@MainActor
final class ItemEnumerationDumpService {
    static let shared = ItemEnumerationDumpService()

    private var pending: (UUID, Task<URL?, Never>)?
    private let operation: @MainActor () -> (@Sendable () -> URL?)
    private let callbackURL: @Sendable (URL, String?) -> URL?
    private let open: @MainActor (URL) -> Void

    init(
        operation: @escaping @MainActor () -> (@Sendable () -> URL?) = {
            let apps = NSWorkspace.shared.runningApplications
            return { ItemEnumerationDump.run(runningApplications: apps) }
        },
        callbackURL: @escaping @Sendable (URL, String?) -> URL? = {
            ItemEnumerationDump.callbackURL(fileURL: $0, callback: $1)
        },
        open: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.operation = operation
        self.callbackURL = callbackURL
        self.open = open
    }

    func request(callback: String?) async {
        let id: UUID
        let task: Task<URL?, Never>
        if let existing = pending {
            (id, task) = existing
        } else {
            id = UUID()
            let work = operation()
            task = Task.detached(priority: .utility) { work() }
            pending = (id, task)
        }
        let file = await task.value
        if pending?.0 == id {
            pending = nil
        }
        guard let file else { return }
        let makeCallback = callbackURL
        let url = await Task.detached(priority: .utility) { makeCallback(file, callback) }.value
        if let url {
            open(url)
        }
    }
}
