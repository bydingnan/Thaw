//
//  InputInteractionState.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit
import Observation
import os.lock

nonisolated struct InputPauseCoordinator {
    struct Lease: Hashable, Sendable {
        fileprivate let id = UUID()
    }

    private var owners = Set<Lease>()
    var isPaused: Bool {
        !owners.isEmpty
    }

    mutating func acquire() -> Lease {
        let lease = Lease()
        owners.insert(lease)
        return lease
    }

    mutating func release(_ lease: Lease) {
        owners.remove(lease)
    }
}

@MainActor
@Observable
final class MenuBarDragSession {
    private(set) var isActive = false

    func begin() {
        isActive = true
    }

    @discardableResult
    func end() -> Bool {
        let wasActive = isActive
        isActive = false
        return wasActive
    }

    @discardableResult
    func cancel() -> Bool {
        end()
    }

    func reconcile(isButtonDown: Bool) {
        if !isButtonDown {
            cancel()
        }
    }
}

nonisolated struct PointerInteractionRouting<Display: Equatable> {
    let pointerDisplay: Display?
    let activeMenuBarDisplay: Display?
    let fallbackDisplay: Display?

    var bookkeepingDisplay: Display? {
        pointerDisplay ?? fallbackDisplay
    }

    var revealDisplay: Display? {
        activeMenuBarDisplay ?? fallbackDisplay
    }
}

nonisolated enum ScrollRevealIntent {
    enum Action: Equatable { case show, hide }

    static func action(deltaX: CGFloat, deltaY: CGFloat, isMomentum: Bool, threshold: CGFloat = 5) -> Action? {
        guard !isMomentum else { return nil }
        let delta = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
        guard abs(delta) > threshold else { return nil }
        return delta > 0 ? .show : .hide
    }
}

final nonisolated class PointerBoundsCache: @unchecked Sendable {
    typealias Entry = (windowID: CGWindowID, bounds: CGRect)
    private let storage = OSAllocatedUnfairLock(initialState: [Entry]())

    var entries: [Entry] {
        storage.withLock { $0 }
    }

    func refresh(live: [Entry], onScreen: [Entry], managed: [Entry]) {
        var seen = Set<CGWindowID>()
        var result = [Entry]()
        for batch in [live, onScreen, managed] {
            for entry in batch where !entry.bounds.isEmpty && seen.insert(entry.windowID).inserted {
                result.append(entry)
            }
        }
        storage.withLock { [result] in $0 = result }
    }
}
