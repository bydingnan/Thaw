//
//  FreshMenuBarInventory.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import MenuBarModel

@MainActor
final class FreshMenuBarInventory {
    private(set) var items: [MenuBarItem] = []
    private var complete = false
    private var completion: Task<Void, Never>?
    private var generation = 0

    func waitForCompletion() async {
        await completion?.value
    }

    func accept(_ candidate: [MenuBarItem], completed: Bool) {
        if completed {
            generation += 1
            items = candidate
            complete = true
        } else if !complete {
            let known = Set(items.map(\.uniqueIdentifier))
            items += candidate.filter { !known.contains($0.uniqueIdentifier) }
        }
    }

    func scheduleCompletion(_ read: @escaping @Sendable () async -> (items: [MenuBarItem], completed: Bool)) {
        guard completion == nil else { return }
        let requestedGeneration = generation
        completion = Task { [weak self] in
            let result = await read()
            guard let self else { return }
            guard generation == requestedGeneration else {
                completion = nil
                return
            }
            accept(result.items, completed: result.completed)
            completion = nil
        }
    }
}
