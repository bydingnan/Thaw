//
//  MenuBarItemAlertRevealWatcher.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import Combine
import Foundation
import MenuBarModel
import ThawCapture

// MARK: - MenuBarItemAlertReveals

/// Defaults-backed store of the items the user opted into revealing when
/// their icon changes, keyed by MenuBarItemTag.tagIdentifier.
@MainActor
enum MenuBarItemAlertReveals {
    static func identifiers() -> Set<String> {
        Set(Defaults.stringArray(forKey: .menuBarItemAlertReveals) ?? [])
    }

    static func contains(_ identifier: String) -> Bool {
        identifiers().contains(identifier)
    }

    static func setEnabled(_ enabled: Bool, for identifier: String) {
        var current = identifiers()
        if enabled {
            current.insert(identifier)
        } else {
            current.remove(identifier)
        }
        Defaults.set(current.sorted(), forKey: .menuBarItemAlertReveals)
    }
}

// MARK: - AlertRevealPolicy

/// Pure decision logic for whether an icon change should reveal an item,
/// kept separate from the watcher so the throttling is unit-testable.
nonisolated struct AlertRevealPolicy {
    /// The minimum time between reveals of the same item, so an icon that
    /// animates continuously can't bounce its item in and out of the bar.
    /// Seeded from the default and kept in step with the user's setting by
    /// the watcher; see AdvancedSettings.menuBarItemAlertRevealCooldown.
    var cooldown: TimeInterval = Defaults.DefaultValue.menuBarItemAlertRevealCooldown

    private(set) var lastRevealDates: [String: Date] = [:]

    /// Returns whether identifier may reveal now, recording the reveal
    /// date when it may.
    mutating func shouldReveal(_ identifier: String, now: Date) -> Bool {
        if let last = lastRevealDates[identifier], now.timeIntervalSince(last) < cooldown {
            return false
        }
        lastRevealDates[identifier] = now
        return true
    }
}

/// Tracks only enabled items present in the current capture inventory.
nonisolated struct AlertRevealBaselines {
    private(set) var captures: [String: MenuBarItemGlyphCapture] = [:]

    mutating func changedIdentifiers(
        in images: [MenuBarItemTag: MenuBarItemGlyphCapture],
        enabled: Set<String>
    ) -> Set<String> {
        let present = Set(images.keys.map(\.tagIdentifier))
        captures = captures.filter { enabled.contains($0.key) && present.contains($0.key) }
        var changed = Set<String>()
        for (tag, image) in images where enabled.contains(tag.tagIdentifier) {
            let identifier = tag.tagIdentifier
            if let baseline = captures[identifier], !MenuBarItemGlyphCapture.isVisuallyEqual(baseline, image) {
                changed.insert(identifier)
            }
            captures[identifier] = image
        }
        return changed
    }
}

// MARK: - MenuBarItemAlertRevealWatcher

/// Temporarily reveals concealed items when their captured icon changes,
/// the "surface the item only when it's alerting" behavior. Piggybacks on
/// the image cache's capture stream, so it adds no captures of its own,
/// and reuses the section controller's temporary-reveal path (macOS 27).
@MainActor
final class MenuBarItemAlertRevealWatcher {
    private let diagLog = DiagLog(category: "MenuBarItemAlertRevealWatcher")

    /// The last-seen image per opted-in identifier. The first sighting only
    /// seeds the baseline; reveals require a change against it.
    private var baselines = AlertRevealBaselines()

    private var policy = AlertRevealPolicy()
    private var cancellables = Set<AnyCancellable>()
    private var captureScheduler: AlertRevealCaptureScheduler<MenuBarItem>?

    private(set) weak var appState: AppState?

    func performSetup(with appState: AppState) {
        self.appState = appState
        cancellables.removeAll()
        let scheduler = AlertRevealCaptureScheduler<MenuBarItem>(
            inventory: { [weak appState] in appState?.itemManager.managedItems ?? [] },
            identifier: { $0.tag.tagIdentifier },
            capture: { [weak appState] items in
                await ScreenCapture.withOneshotCaptureTicket { @MainActor in
                    guard let appState, appState.isPermissionGranted(.screenRecording), !appState.itemManager.isResettingLayout, !appState.isDraggingMenuBarItem
                    else { return }
                    await appState.imageCache.beginConcealedPrewarm()
                    defer { appState.imageCache.endConcealedPrewarm() }
                    guard !Task.isCancelled else { return }
                    let displayID = appState.itemManager.itemDisplayID ?? CGMainDisplayID()
                    let controller = appState.menuBarManager.sectionController
                    guard !controller.isNativeOverflowActive(on: displayID), let screen = NSScreen.screen(for: displayID)
                    else { return }
                    await appState.imageCache.captureConcealedItemsByGroupedReveal(
                        items,
                        controller: controller,
                        displayID: displayID,
                        scale: screen.backingScaleFactor,
                        missPolicy: .keepExisting
                    )
                }
            }
        )
        captureScheduler = scheduler
        scheduler.update(identifiers: MenuBarItemAlertReveals.identifiers())
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak scheduler] _ in
                scheduler?.update(identifiers: MenuBarItemAlertReveals.identifiers())
            }
            .store(in: &cancellables)
        // MenuBarItemImageCache is @Observable, so captures arrive through
        // an Observations sequence.
        let task = Task { @MainActor [weak self, imageCache = appState.imageCache] in
            let changes = Observations { imageCache.capturesByTag }
            for await images in changes {
                guard let self else { return }
                process(images)
            }
        }
        AnyCancellable { task.cancel() }
            .store(in: &cancellables)
    }

    private func process(_ images: [MenuBarItemTag: MenuBarItemGlyphCapture]) {
        let enabled = MenuBarItemAlertReveals.identifiers()
        guard !enabled.isEmpty else {
            baselines = AlertRevealBaselines()
            return
        }
        guard let appState else {
            return
        }
        // Non-optional: before setup this is an InertSectionController, whose
        // reveal calls are no-ops, so no extra guard is needed here.
        let sectionController = appState.menuBarManager.sectionController
        // Re-read each batch: the setting is live, and the policy carries the
        // reveal history that a freshly constructed one would discard.
        policy.cooldown = appState.settings.advanced.menuBarItemAlertRevealCooldown

        let changed = baselines.changedIdentifiers(in: images, enabled: enabled)
        for identifier in changed {
            // Only concealed items need surfacing; a visible item's icon
            // change is already on screen.
            guard let section = sectionController.sectionAssignment[identifier], section != .visible, policy.shouldReveal(identifier, now: Date()) else {
                continue
            }
            diagLog.info("Icon change detected for \(identifier); revealing temporarily")
            sectionController.revealForInteraction(
                identifier,
                duration: appState.settings.general.tempShowInterval,
                menuMonitor: appState.itemManager.menuOpenMonitor
            )
        }
    }
}
