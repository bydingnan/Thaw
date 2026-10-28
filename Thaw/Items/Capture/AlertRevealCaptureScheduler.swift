//
//  AlertRevealCaptureScheduler.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation

@MainActor
final class AlertRevealCaptureScheduler<Item> {
    private let inventory: () -> [Item]
    private let identifier: (Item) -> String
    private let capture: ([Item]) async -> Void
    private let cadence: Duration
    private var identifiers = Set<String>()
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0

    var isRunning: Bool {
        task != nil
    }

    init(
        cadence: Duration = .seconds(1),
        inventory: @escaping () -> [Item],
        identifier: @escaping (Item) -> String,
        capture: @escaping ([Item]) async -> Void
    ) {
        self.cadence = cadence
        self.inventory = inventory
        self.identifier = identifier
        self.capture = capture
    }

    static func plan(items: [Item], optedIn: Set<String>, identifier: (Item) -> String) -> [Item] {
        items.filter { optedIn.contains(identifier($0)) }
    }

    func update(identifiers: Set<String>) {
        self.identifiers = identifiers
        guard !identifiers.isEmpty else {
            generation &+= 1
            task?.cancel()
            task = nil
            return
        }
        guard task == nil else { return }
        generation &+= 1
        let current = generation
        task = Task { [weak self, cadence] in
            while !Task.isCancelled {
                guard self?.generation == current, let targets = self?.plannedTargets(), let capture = self?.capture
                else { return }
                if !targets.isEmpty {
                    await capture(targets)
                }
                do {
                    try await Task.sleep(for: cadence)
                } catch { return }
            }
        }
    }

    private func plannedTargets() -> [Item] {
        Self.plan(items: inventory(), optedIn: identifiers, identifier: identifier)
    }

    isolated deinit { task?.cancel() }
}
