//
//  InventoryRefreshRepairTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
import MenuBarModel
import Testing
@testable import Thaw

@MainActor
struct InventoryRefreshRepairTests {
    @Test func lateAXOnlyArrivalForcesRecheckWithUnchangedWindowList() {
        let recheck = LateItemAttachmentRecheck(initialIdentifiers: ["old"])
        #expect(recheck.shouldForceAXRead)
    }

    @Test func lateAttachmentRechecksStopAfterSuccessfulInventoryRefresh() {
        var recheck = LateItemAttachmentRecheck(initialIdentifiers: ["old"])
        recheck.observed(["old"])
        #expect(recheck.shouldForceAXRead)
        recheck.observed(["old", "late"])
        #expect(!recheck.shouldForceAXRead)
    }

    @Test func ordinaryPollingStillUsesCheapWindowGate() {
        var gate = PeriodicCacheRefreshGate()
        gate.complete([1])
        #expect(!gate.needsRefresh([1]))
    }

    @Test func windowChangeDuringMoveCooldownRetriesAfterCooldown() {
        var gate = PeriodicCacheRefreshGate()
        gate.complete([1])
        #expect(gate.needsRefresh([2]))
        #expect(gate.needsRefresh([2]))
        gate.complete([2])
        #expect(!gate.needsRefresh([2]))
    }

    @Test func windowChangeDuringCommandDragIsNotConsumed() {
        var gate = PeriodicCacheRefreshGate()
        gate.complete([1])
        #expect(gate.needsRefresh([1, 2]))
        #expect(gate.signature == [1])
    }

    @Test func confirmedStabilityCandidateSurvivesDeferredCachePass() {
        var gate = PeriodicCacheRefreshGate()
        gate.complete([1])
        gate.deferRefresh()
        #expect(gate.needsRefresh([1]))
    }

    @Test func coldIncompleteWalkDoesNotRequestUnboundedMainActorWalk() {
        let inventory = FreshMenuBarInventory()
        inventory.accept([], completed: false)
        #expect(inventory.items.isEmpty)
    }

    @Test func incompleteColdWalkRetainsProvisionalInventoryUntilCompleteAnswer() {
        let inventory = FreshMenuBarInventory()
        inventory.accept([item("first", id: 1)], completed: false)
        inventory.accept([item("second", id: 2)], completed: false)
        #expect(inventory.items.map(\.windowID) == [1, 2])
        inventory.accept([item("second", id: 2)], completed: true)
        inventory.accept([item("first", id: 1)], completed: false)
        #expect(inventory.items.map(\.windowID) == [2])
    }

    @Test func completeBackgroundWalkReplacesProvisionalInventory() async {
        let inventory = FreshMenuBarInventory()
        inventory.accept([item("first", id: 1)], completed: false)
        let replacement = item("second", id: 2)
        inventory.scheduleCompletion { ([replacement], true) }
        await inventory.waitForCompletion()
        #expect(inventory.items.map(\.windowID) == [2])
    }

    private func item(_ title: String, id: UInt32) -> MenuBarItem {
        MenuBarItem(
            tag: MenuBarItemTag(namespace: .string("example"), title: title, instanceIndex: 0),
            windowID: id, ownerPID: 100, sourcePID: 200,
            bounds: CGRect(x: 10, y: 0, width: 24, height: 24),
            title: title, isOnScreen: true
        )
    }
}
