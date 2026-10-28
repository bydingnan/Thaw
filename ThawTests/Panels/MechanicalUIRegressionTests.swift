//
//  MechanicalUIRegressionTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit
import Testing
@testable import Thaw

@MainActor
struct AssistedPanelOversizeRegressionTests {
    private let visible = CGRect(x: 50, y: 30, width: 300, height: 200)

    @Test func acceptsPanelWiderThanVisibleFrame() {
        let frame = AssistedPanelPlacement.frame(near: CGPoint(x: 200, y: 180), in: visible, size: CGSize(width: 600, height: 80))
        #expect(frame.minX == visible.minX)
        #expect(frame.width == 600)
    }

    @Test func acceptsPanelTallerThanVisibleFrame() {
        let frame = AssistedPanelPlacement.frame(near: CGPoint(x: 200, y: 180), in: visible, size: CGSize(width: 100, height: 600))
        #expect(frame.minY == visible.minY)
        #expect(frame.height == 600)
    }

    @Test func stillPrefersBelowThenFlipsAboveWhenItFits() {
        let size = CGSize(width: 100, height: 50)
        let below = AssistedPanelPlacement.frame(near: CGPoint(x: 200, y: 180), in: visible, size: size)
        let above = AssistedPanelPlacement.frame(near: CGPoint(x: 200, y: 40), in: visible, size: size)
        #expect(below.maxY == 180 - AssistedPanelPlacement.pointerGap)
        #expect(above.minY == 40 + AssistedPanelPlacement.pointerGap)
    }
}

@MainActor
struct ChangelogNumberedStepRegressionTests {
    private var blocks: [ChangelogDocument.Block] {
        ChangelogDocument.parse("## [3.0]\n### Notes\n1. First step\n   wrapped continuation\n2. Second step\n- Ordinary bullet\n")
            .releases[0].sections[0].themes[0].bullets
    }

    @Test func numberedStepsRemainDistinctBlocks() {
        #expect(blocks.count == 3)
        guard case let .numberedStep(first) = blocks[0], case let .numberedStep(second) = blocks[1] else {
            Issue.record("Numbered steps must retain their block kind")
            return
        }
        #expect(String(first.characters) == "1. First step wrapped continuation")
        #expect(String(second.characters) == "2. Second step")
    }

    @Test func numberedStepsDoNotGainBulletMarkers() {
        #expect(blocks[0].unorderedMarker == nil)
        #expect(blocks[1].unorderedMarker == nil)
        #expect(blocks[2].unorderedMarker == "•")
    }
}

@MainActor
struct LeadingEdgeInvalidationRegressionTests {
    private let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)

    @Test func noSeatedAnchorClearsPublishedEdge() {
        let edge = MenuBarLeadingEdgeSample(x: 900, screenFrame: screen)
        #expect(edge.retained(among: [screen], hasSeatedAnchor: false) == nil)
        #expect(edge.retained(among: [screen], hasSeatedAnchor: true) == edge)
    }

    @Test func displayRemovalInvalidatesDisconnectedScreenEdge() {
        let edge = MenuBarLeadingEdgeSample(x: 900, screenFrame: screen)
        #expect(edge.retained(among: [screen.offsetBy(dx: 1200, dy: 0)], hasSeatedAnchor: true) == nil)
    }

    @Test func nilLeadingEdgeCannotOverrideNewerAXSnapshot() {
        let start = ContinuousClock.now
        let edge = MenuBarLeadingEdgeSample(x: 900, screenFrame: screen)
        var observation = MenuBarLeadingEdgeObservation()
        observation.update(edge, at: start + .milliseconds(10))
        #expect(observation.sample(newerThan: start) == edge)
        observation.update(nil, at: start + .milliseconds(20))
        #expect(observation.sample(newerThan: start) == nil)
        #expect(observation.sample(newerThan: start + .milliseconds(30)) == nil)
    }
}

@MainActor
struct PassiveOutsideClickRegressionTests {
    private func event(at point: CGPoint, type: NSEvent.EventType = .leftMouseDown) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                                        windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
    }

    @Test func localOutsideClickDismissesWithoutConsumingEvent() throws {
        var dismissed = false
        let event = try event(at: CGPoint(x: 300, y: 300), type: .otherMouseDown)
        let observe = EventMonitor.passiveHandlers { _ in dismissed = true }.local
        #expect(observe(event) === event)
        #expect(dismissed)
        let monitor = EventMonitor.passive(for: [.leftMouseDown, .rightMouseDown, .otherMouseDown], scope: .universal) { _ in }
        #expect(monitor.scope == .universal)
        #expect(!monitor.isRunning)
    }

    @Test func globalOutsideClickStillDismisses() throws {
        var dismissed = false
        let observe = EventMonitor.passiveHandlers { _ in dismissed = true }.global
        try observe(event(at: CGPoint(x: 300, y: 300)))
        #expect(dismissed)
    }

    @Test func insideClicksRemainOpenForBothScopes() throws {
        let panel = CGRect(x: 0, y: 0, width: 100, height: 100)
        var dismissals = 0
        let handler: (NSEvent) -> Void = { event in
            if !panel.contains(event.locationInWindow) {
                dismissals += 1
            }
        }
        let event = try event(at: CGPoint(x: 50, y: 50))
        let handlers = EventMonitor.passiveHandlers(handler)
        #expect(handlers.local(event) === event)
        handlers.global(event)
        #expect(dismissals == 0)
    }
}

@MainActor
struct EmptySplitPillRegressionTests {
    @Test func zeroWidthLeadingPillIsMissing() {
        let bounds = MenuBarSplitPillGeometry.leadingBounds(
            applicationMenuFrame: CGRect(x: 0, y: 0, width: 10, height: 24), trailingContentMinX: 3,
            in: CGRect(x: 0, y: 0, width: 100, height: 24), screenFrame: CGRect(x: 0, y: 0, width: 100, height: 800),
            trailingPadding: 0, leadingMargin: 8, notchFrame: nil, notchMargin: 0
        )
        #expect(bounds == .zero)
    }

    @Test func zeroWidthTrailingPillDoesNotReplaceStableGeometry() {
        let leading = CGRect(x: 8, y: 0, width: 100, height: 24)
        let trailing = CGRect(x: 200, y: 0, width: 100, height: 24)
        let result = MenuBarSplitPillGeometry.resolveSplitPathBounds(
            leading: CGRect(x: 8, y: 0, width: 0, height: 24),
            trailing: CGRect(x: 200, y: 0, width: 0, height: 24), geometryFrozen: false,
            lastStableLeading: leading, lastStableTrailing: trailing
        )
        #expect(result.leading == leading)
        #expect(result.trailing == trailing)
        #expect(result.nextStableTrailing == trailing)
    }

    @Test func splitShapeDrawsOnlyTrailingPillWhenLeadingIsEmpty() throws {
        let screen = try #require(NSScreen.screens.first)
        let trailing = CGRect(x: 200, y: 0, width: 100, height: 24)
        let path = MenuBarShapePathBuilder.splitShapePath(
            leadingPathBounds: CGRect(x: 8, y: 0, width: 0, height: 24), trailingPathBounds: trailing,
            info: .defaultValue, in: CGRect(x: 0, y: 0, width: 400, height: 24), leftMargin: 0, rightMargin: 0, screen: screen
        )
        // Rounded path bounds inset inside the trailing rect; require coverage, not equality.
        #expect(trailing.contains(path.bounds))
        #expect(abs(path.bounds.midX - trailing.midX) < 1)
        #expect(!path.contains(CGPoint(x: 50, y: 12)))
    }
}
