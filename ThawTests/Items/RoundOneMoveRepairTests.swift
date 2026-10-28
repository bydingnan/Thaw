//
//  RoundOneMoveRepairTests.swift
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
struct RoundOneMoveRepairTests {
    @Test func lowerDisplayRestrictionRepairDoesNotPulseForSeatedItems() {
        let seated = item("seated", id: 1, bounds: CGRect(x: 100, y: 1080, width: 24, height: 24))
        let displays = [CGRect(x: 0, y: 1080, width: 1920, height: 1080)]
        #expect(ParkedItems.parkedSetAndBarMidY(in: [seated], displays: displays).parkedIDs.isEmpty)
    }

    @Test func lowerDisplayVisibleItemsAreNotReportedNotShown() {
        let seated = item("seated", id: 1, bounds: CGRect(x: 100, y: 1080, width: 24, height: 24))
        let displays = [CGRect(x: 0, y: 1080, width: 1920, height: 1080)]
        #expect(!NotShownOnBar.looksNotShown(seated, among: [seated], displays: displays))
    }

    @Test func lowerDisplaySeatedItemsRemainInPointerBoundsCache() {
        let seated = item("seated", id: 1, bounds: CGRect(x: 100, y: 1080, width: 24, height: 24))
        let displays = [CGRect(x: 0, y: 1080, width: 1920, height: 1080)]
        #expect(HIDEventManager.shouldIncludeItemInMenuBarBoundsLookup(seated, section: .visible, displays: displays))
    }

    @Test func parkedHiddenControlFallsBackToRightmostVisibleItem() {
        let stuck = item("stuck", id: 1, bounds: CGRect(x: 100, y: 0, width: 24, height: 24))
        let hidden = item("hidden", id: 2, bounds: CGRect(x: -1, y: 0, width: 24, height: 24))
        let visible = item("visible", id: 3, bounds: CGRect(x: 200, y: 0, width: 24, height: 24))
        let anchor = MoveTargeting.recoveryAnchor(stuck: stuck, items: [stuck, hidden, visible], hiddenControlItemWindowNumber: 2, section: { _ in .visible })
        #expect(anchor?.windowID == visible.windowID)
    }

    @Test func collapsedHiddenControlFallsBackToRightmostVisibleItem() {
        let stuck = item("stuck", id: 1, bounds: CGRect(x: 100, y: 0, width: 24, height: 24))
        let hidden = item("hidden", id: 2, bounds: .zero)
        let visible = item("visible", id: 3, bounds: CGRect(x: 200, y: 0, width: 24, height: 24))
        let anchor = MoveTargeting.recoveryAnchor(stuck: stuck, items: [stuck, hidden, visible], hiddenControlItemWindowNumber: 2, section: { _ in .visible })
        #expect(anchor?.windowID == visible.windowID)
    }

    private func item(_ title: String, id: UInt32, bounds: CGRect) -> MenuBarItem {
        MenuBarItem(
            tag: MenuBarItemTag(namespace: .string("example"), title: title, instanceIndex: 0),
            windowID: id, ownerPID: 100, sourcePID: 200, bounds: bounds,
            title: title, isOnScreen: true
        )
    }

    @Test func cancelledProfileApplyStopsBeforeOverflowMutation() {
        #expect(!ProfileLayoutApplySequence.mayContinue(isCancelled: true))
    }

    @Test func cancelledProfileApplyDoesNotPersistSuccessOrScheduleRefresh() {
        #expect(!ProfileLayoutApplySequence.mayContinue(isCancelled: true))
    }

    @Test func currentProfileApplyCompletesAllStages() {
        #expect(ProfileLayoutApplySequence.mayContinue(isCancelled: false))
    }

    @Test func rollbackOutcomePreservesOriginalOrder() {
        let feedback = LayoutBarFeedbackCenter()
        let outcome = LayoutApplyOutcome.restored(originalOrder: ["a", "b"], requestedOrder: ["b", "a"])
        feedback.authoredLayoutFailed(outcome: outcome, retry: {}, showItems: {})
        #expect(feedback.layoutOutcome == outcome)
        feedback.clear()
    }

    @Test func retryRecomputesPlanFromCurrentInventory() {
        let feedback = LayoutBarFeedbackCenter()
        var inventory = ["old"]
        var planned: [String] = []
        feedback.authoredLayoutFailed(
            outcome: .restored(originalOrder: inventory, requestedOrder: ["desired"]),
            retry: { planned = inventory }, showItems: {}
        )
        inventory = ["new", "arrival"]
        feedback.retry()
        #expect(planned == inventory)
        feedback.clear()
    }

    @Test func cancelledPhysicalSeatAttemptKeepsForcedDragMarker() {
        var ledger = PendingPhysicalSeatLedger()
        ledger.insert("item")
        #expect(ledger.contains("item"))
    }

    @Test func failedPhysicalSeatAttemptKeepsForcedDragMarker() {
        var ledger = PendingPhysicalSeatLedger()
        ledger.insert("item")
        #expect(ledger.contains("item"))
        #expect(ledger.contains("item"))
    }

    @Test func verifiedPhysicalSeatClearsForcedDragMarker() {
        var ledger = PendingPhysicalSeatLedger()
        ledger.insert("item")
        ledger.remove("item")
        #expect(!ledger.contains("item"))
    }

    @Test func unchangedOriginalProcessIsNotSuccessfulRelaunch() {
        #expect(!SpacingRelaunchVerification.hasFreshProcess(currentPIDs: [12], replacing: [12]))
    }

    @Test func fallbackRecoveryRequiresFreshProcess() {
        #expect(!SpacingRelaunchVerification.hasFreshProcess(currentPIDs: [], replacing: [12]))
        #expect(!SpacingRelaunchVerification.hasFreshProcess(currentPIDs: [12, 13], replacing: [12, 13]))
    }

    @Test func freshReplacementProcessIsSuccessfulRelaunch() {
        #expect(SpacingRelaunchVerification.hasFreshProcess(currentPIDs: [14], replacing: [12]))
    }

    @Test func failedAuthoredLayoutPublishesActionableOutcome() {
        let feedback = LayoutBarFeedbackCenter()
        var retried = false
        var shown = false
        feedback.authoredLayoutFailed(outcome: .restored(originalOrder: ["old"], requestedOrder: ["new"]), retry: { retried = true }, showItems: { shown = true })
        #expect(feedback.refusal != nil)
        feedback.retry()
        feedback.showItems()
        #expect(retried && shown)
        feedback.clear()
    }

    @Test func successfulApplyLeavesFeedbackDismissed() {
        let feedback = LayoutBarFeedbackCenter()
        feedback.authoredLayoutFailed(outcome: .restored(originalOrder: ["old"], requestedOrder: ["new"]), retry: {}, showItems: {})
        feedback.clear()
        #expect(feedback.refusal == nil)
        #expect(feedback.retryAction == nil)
    }
}
