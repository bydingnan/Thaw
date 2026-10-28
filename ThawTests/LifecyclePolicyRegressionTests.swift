//
//  LifecyclePolicyRegressionTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Testing
@testable import Thaw

@MainActor
struct LifecyclePolicyRegressionTests {
    @Test func replacementControlsRemainAvailableWhenArrangementIsUnavailable() {
        let policy = LayoutSettingsPresentation(isMenuBarAutoHidden: true)
        #expect(!policy.canArrangeLayout)
        #expect(policy.canConfigureReplacements)
        #expect(LayoutSettingsPresentation(isMenuBarAutoHidden: false).canArrangeLayout)
    }

    @Test func quitChoiceSkipsLaunchAndOnboarding() {
        #expect(LaunchPolicy.launchPermissions(conflictAllowsLaunch: false, hasRequiredPermissions: true) == nil)
        #expect(LaunchPolicy.launchPermissions(conflictAllowsLaunch: false, hasRequiredPermissions: false) == nil)
    }

    @Test func continueChoicePreservesExistingLaunchDecision() {
        #expect(LaunchPolicy.launchPermissions(conflictAllowsLaunch: true, hasRequiredPermissions: true) == true)
        #expect(LaunchPolicy.launchPermissions(conflictAllowsLaunch: true, hasRequiredPermissions: false) == false)
    }

    @Test func registrationInvokesDeferredOpenAction() {
        var state = WindowPresentationState<String>()
        #expect(state.request("permissions", hasAction: false) == .deferred)
        #expect(!state.contains("permissions"))
        var calls = 0
        for id in state.deferred where state.request(id, hasAction: true) == .present {
            calls += 1
        }
        #expect(calls == 1)
        #expect(state.deferred.isEmpty)
        #expect(state.request("permissions", hasAction: true) == .coalesced)
    }

    @Test func duplicateDeferredRequestsCoalesce() {
        var state = WindowPresentationState<String>()
        #expect(state.request("settings", hasAction: false) == .deferred)
        #expect(state.request("settings", hasAction: false) == .coalesced)
        #expect(state.deferred == ["settings"])
        state.close("settings")
        #expect(state.isEmpty)
    }

    @Test func presentedWindowDoesNotOpenTwice() {
        var state = WindowPresentationState<String>()
        #expect(state.request("settings", hasAction: true) == .present)
        state.didPresent("settings")
        #expect(state.request("settings", hasAction: true) == .activate)
        #expect(state.presented == ["settings"])
        state.close("settings")
        #expect(state.request("settings", hasAction: true) == .present)
    }

    @Test func closingSettingsWhileWhatsNewIsVisibleKeepsRegularPolicy() {
        var windows = WindowPresentationState<String>()
        windows.didPresent("settings")
        windows.didPresent("whatsNew")
        windows.close("settings")
        #expect(!ActivationOccupancy(hasWindowRequests: !windows.isEmpty).permitsAccessoryPolicy)
    }

    @Test func closingSettingsWhileSearchIsPresentedKeepsRegularPolicy() {
        #expect(!ActivationOccupancy(search: true).permitsAccessoryPolicy)
    }

    @Test func closingLastSettingsSurfaceRestoresAccessoryPolicy() {
        var windows = WindowPresentationState<String>()
        windows.didPresent("settings")
        windows.close("settings")
        #expect(ActivationOccupancy(hasWindowRequests: !windows.isEmpty).permitsAccessoryPolicy)
        // willClose can arrive while AppKit still considers the closing window visible.
        #expect(!ActivationOccupancy(visibleWindows: true).permitsAccessoryPolicy)
    }

    @Test func otherLiveSurfacesKeepRegularPolicy() {
        let occupied = [
            ActivationOccupancy(settings: true), ActivationOccupancy(thawBar: true),
            ActivationOccupancy(layoutEditor: true), ActivationOccupancy(hidesApplicationMenus: true),
            ActivationOccupancy(modal: true),
        ]
        #expect(occupied.allSatisfy { !$0.permitsAccessoryPolicy })
    }

    @Test func deactivateCancelsPendingActivationReassert() {
        var gate = ActivationRequestGate()
        let token = gate.begin()
        gate.invalidate()
        #expect(!gate.isCurrent(token))
    }

    @Test func latestActivationRequestWins() {
        var gate = ActivationRequestGate()
        let first = gate.begin()
        let latest = gate.begin()
        #expect(!gate.isCurrent(first))
        #expect(gate.isCurrent(latest))
    }

    @Test func staleActivationDoesNotChangeFrontmostApp() {
        var gate = ActivationRequestGate()
        let stale = gate.begin()
        gate.invalidate()
        var frontmost = "other-app"
        if gate.isCurrent(stale) {
            frontmost = "foldy"
        }
        #expect(frontmost == "other-app")
    }

    @Test func displayReplacementWithSameCountRefreshesItemCache() {
        var topology = DisplayTopologyChange(identities: [1, 2])
        topology.observe([1, 3])
        let change = topology.consume()
        #expect(change.requiresInventoryRefresh)
        #expect(change.requiresCaptureCleanup)
        #expect(change.added == [3])
        #expect(change.removed == [2])
        #expect(!topology.requiresInventoryRefresh)
    }

    @Test func disconnectReconnectWithinDebounceProducesTopologyChange() {
        var topology = DisplayTopologyChange(identities: [1, 2])
        topology.observe([1])
        topology.observe([1, 2])
        #expect(topology.consume().requiresInventoryRefresh)
    }

    @Test func resolutionOnlyChangeDoesNotRebuildInventory() {
        var topology = DisplayTopologyChange(identities: [1, 2])
        topology.observe([1, 2])
        #expect(!topology.consume().requiresInventoryRefresh)
    }
}

@MainActor
struct RelaunchArgumentRegressionTests {
    @Test func bundlePathIsPassedAsPositionalArgument() {
        let path = "/Applications/Foldy.app"
        let arguments = AppRelauncher.watcherArguments(bundlePath: path, pid: 42)
        #expect(arguments[3] == path)
        #expect(arguments[1].contains("open \"$1\""))
    }

    @Test func shellMetacharactersInBundlePathAreNotEmbeddedInScript() {
        let path = "/Applications/$(touch injected); `echo bad` \' \" Foldy.app"
        let arguments = AppRelauncher.watcherArguments(bundlePath: path, pid: 42)
        #expect(arguments[3] == path)
        #expect(!arguments[1].contains(path))
        #expect(arguments[1] == AppRelauncher.watcherArguments(bundlePath: "/safe.app", pid: 99)[1])
    }

    @Test func pidIsPassedSeparatelyFromScript() {
        let arguments = AppRelauncher.watcherArguments(bundlePath: "/safe.app", pid: 9876)
        #expect(arguments[4] == "9876")
        #expect(!arguments[1].contains("9876"))
        #expect(arguments[1].contains("kill -0 \"$2\""))
    }
}
