//
//  MenuBarAgentIdentityStore.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
import os

public final class MenuBarAgentIdentityStore: Sendable {
    public struct Token: Sendable {
        fileprivate let storeID: UUID
        fileprivate let generation: UInt64
        fileprivate let previous: [MenuBarItem]
    }

    public struct Snapshot: Sendable {
        public let items: [MenuBarItem]
        public let freshItems: [MenuBarItem]
    }

    private struct State {
        var generation: UInt64 = 0
        var published: UInt64 = 0
        var items: [MenuBarItem] = []
    }

    private let id = UUID()
    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() {}

    public func begin() -> Token {
        state.withLock {
            $0.generation &+= 1
            return Token(storeID: id, generation: $0.generation, previous: $0.items)
        }
    }

    public func reconcile(
        items: [MenuBarItem],
        freshItems: [MenuBarItem],
        token: Token,
        publish: Bool = true
    ) -> Snapshot {
        precondition(token.storeID == id)
        let result = MenuBarAgentIdentityReconciler.reconcile(fresh: items, previous: token.previous)
        let fresh: [MenuBarItem] = if result.restoredCount == 0 {
            freshItems
        } else {
            freshItems.map { item in
                guard let index = items.firstIndex(of: item) else { return item }
                return result.items[index]
            }
        }
        if publish {
            state.withLock {
                guard token.generation > $0.published else { return }
                $0.published = token.generation
                if result.items.contains(where: {
                    $0.tag.namespace == .menuBarAgent && !$0.tag.isControlCenterGenericItem
                }) {
                    $0.items = result.items
                }
            }
        }
        return Snapshot(items: result.items, freshItems: fresh)
    }
}
