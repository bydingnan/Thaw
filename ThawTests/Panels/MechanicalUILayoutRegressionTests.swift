//
//  MechanicalUILayoutRegressionTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit
import Testing
@testable import Thaw

@MainActor
struct LayoutOwningDisplayRegressionTests {
    @Test func visibleBarUsesWindowScreenForNotch() {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 100), styleMask: [], backing: .buffered, defer: true)
        let view = NSView(frame: .zero)
        window.contentView = view
        #expect(LayoutBarDisplayGeometry.screen(for: view) === window.screen)
        #expect(LayoutBarDisplayGeometry.screen(for: NSView()) == nil)
    }

    @Test func movingLayoutWindowRecalculatesDestinationNotch() {
        let source = LayoutBarDisplayGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1500, height: 1000),
                                              notchFrame: CGRect(x: 700, y: 970, width: 100, height: 30), notchGap: 10)
        let destination = LayoutBarDisplayGeometry(screenFrame: CGRect(x: 1500, y: 0, width: 2000, height: 1200),
                                                   notchFrame: CGRect(x: 2400, y: 1170, width: 200, height: 30), notchGap: 10)
        #expect(source.notchWidth == 110)
        #expect(destination.notchWidth == 210)
        #expect(source.trailingOffset == 697.5)
        #expect(destination.trailingOffset == 897.5)
        #expect(destination.minimumWidth == 1107.5)
    }

    @Test func usesOwningScreenForBrightness() {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 100), styleMask: [], backing: .buffered, defer: true)
        let view = NotchIndicatorView(averageColorInfo: nil)
        window.contentView = view
        let color = MenuBarAverageColorInfo(color: NSColor.gray.cgColor, source: .menuBarWindow)
        view.averageColorInfo = color
        #expect(view.isBright == color.isBright(for: window.screen))
        #expect(LayoutBarDisplayGeometry.screen(for: view) === window.screen)
    }
}

@MainActor
struct HotkeyRecordingCancellationRegressionTests {
    @Test func disappearanceRestoresPreviousBinding() {
        var enabled = true
        var monitoring = false
        let combination = "command-A"
        var enabledCombination: String?
        let session = HotkeyRecordingSession(disableBinding: { enabled = false },
                                             enableBinding: { enabled = true; enabledCombination = combination },
                                             startMonitor: { monitoring = true }, stopMonitor: { monitoring = false })
        session.start()
        #expect(!enabled)
        session.cancel()
        #expect(enabled)
        #expect(!monitoring)
        #expect(!session.isListening)
        #expect(enabledCombination == combination)
    }

    @Test func cancellationStopsMonitorWithoutClearingCombination() {
        var monitorStops = 0
        let combination = "option-B"
        var restored: String?
        let session = HotkeyRecordingSession(disableBinding: {}, enableBinding: { restored = combination },
                                             startMonitor: {}, stopMonitor: { monitorStops += 1 })
        session.start()
        session.cancel()
        session.cancel()
        #expect(monitorStops == 1)
        #expect(restored == "option-B")
    }

    @Test func completedRecordingDoesNotRestoreOldListener() {
        var combination = "old"
        var listeners: [String] = []
        let session = HotkeyRecordingSession(disableBinding: {}, enableBinding: { listeners.append(combination) },
                                             startMonitor: {}, stopMonitor: {})
        session.start()
        combination = "new"
        session.stop()
        session.cancel()
        #expect(listeners == ["new"])
    }
}

@MainActor
struct LayoutAccessibilityRegressionTests {
    private func views() -> (parent: NSView, first: NSView, second: NSView, handle: NSView) {
        let parent = NSView(frame: .zero)
        let first = NSView(frame: CGRect(x: 20, y: 0, width: 10, height: 20))
        let second = NSView(frame: CGRect(x: 50, y: 0, width: 10, height: 20))
        let handle = NSView(frame: CGRect(x: 10, y: 0, width: 8, height: 20))
        [first, second, handle].forEach(parent.addSubview)
        return (parent, first, second, handle)
    }

    @Test func childrenIncludeGroupHandles() {
        let fixture = views()
        let children = LayoutBarContainer.accessibilityViews(arranged: [fixture.first, fixture.second], handles: [fixture.handle], parent: fixture.parent)
        #expect(children.contains { $0 === fixture.handle })
        #expect(children.count == 3)
    }

    @Test func childrenFollowVisualOrder() {
        let fixture = views()
        let children = LayoutBarContainer.accessibilityViews(arranged: [fixture.second, fixture.first], handles: [fixture.handle], parent: fixture.parent)
        #expect(children.map(\.frame.minX) == [10, 20, 50])
    }

    @Test func removedHandleLeavesAccessibilityChildren() {
        let fixture = views()
        fixture.handle.removeFromSuperview()
        let children = LayoutBarContainer.accessibilityViews(arranged: [fixture.first, fixture.second], handles: [fixture.handle], parent: fixture.parent)
        #expect(!children.contains { $0 === fixture.handle })
        #expect(children.count == 2)
    }
}

@MainActor
struct ItemHintDisplayConversionRegressionTests {
    private func contains(_ item: CGRect, on screen: CGRect) -> Bool {
        let cocoa = NSScreen.cocoaRect(fromCG: item, primaryMaxY: 900)
        return screen.contains(CGPoint(x: cocoa.midX, y: cocoa.midY))
    }

    @Test func itemHintsIncludeItemsOnDisplayAbovePrimary() {
        let screen = CGRect(x: 0, y: 900, width: 1200, height: 800)
        #expect(contains(CGRect(x: 600, y: -800, width: 20, height: 24), on: screen))
    }

    @Test func itemHintsIncludeItemsOnDisplayBelowPrimary() {
        let screen = CGRect(x: 0, y: -800, width: 1200, height: 800)
        #expect(contains(CGRect(x: 600, y: 900, width: 20, height: 24), on: screen))
    }

    @Test func itemHintsRetainSideBySideDisplayBehavior() {
        let screen = CGRect(x: 1200, y: 0, width: 1200, height: 900)
        #expect(contains(CGRect(x: 1800, y: 0, width: 20, height: 24), on: screen))
        #expect(!contains(CGRect(x: 600, y: 0, width: 20, height: 24), on: screen))
    }
}

private final class FolderLabelDefaults: UserDefaults, @unchecked Sendable {
    private(set) var labelWrites = 0

    override func set(_ value: Any?, forKey defaultName: String) {
        if defaultName == GroupFolders.labelsKey {
            labelWrites += 1
        }
        super.set(value, forKey: defaultName)
    }
}

@MainActor
struct FolderLabelInventoryRegressionTests {
    @Test func unnamedFolderAdoptsMemberNamesAfterInitialEmptyInventory() {
        #expect(GroupFolders.folderName(explicitName: nil, memberNames: []) == String(localized: "Folder"))
        #expect(GroupFolders.folderName(explicitName: nil, memberNames: ["Clock"]) == "Clock")
    }

    @Test func folderLabelTracksMemberDisplayNameChanges() {
        let original = GroupFolders.folderName(explicitName: nil, memberNames: ["Before"])
        let updated = GroupFolders.folderName(explicitName: nil, memberNames: ["After"])
        #expect(original == "Before")
        #expect(updated == "After")
        #expect(GroupFolders.folderName(explicitName: "My Folder", memberNames: ["After"]) == "My Folder")
    }

    @Test func unchangedFolderLabelsDoNotPersistAgain() throws {
        let suite = "FolderLabelRegression-" + UUID().uuidString
        let defaults = try #require(FolderLabelDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        GroupFolders.persistLabelsIfChanged(["folder": "Clock"], defaults: defaults)
        GroupFolders.persistLabelsIfChanged(["folder": "Clock"], defaults: defaults)
        #expect(defaults.labelWrites == 1)
        GroupFolders.persistLabelsIfChanged(["folder": "Updated"], defaults: defaults)
        #expect(defaults.labelWrites == 2)
        GroupFolders.persistLabelsIfChanged([:], defaults: defaults)
        #expect(defaults.labelWrites == 3)
    }
}
