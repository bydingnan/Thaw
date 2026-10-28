//
//  MenuBarAXQueries.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import CoreGraphics
import Foundation
import MenuBarModel
import ThawAXClient
import ThawAXCore

/// Pointer-path AX reads and presses, kept off the main thread: the input taps
/// run there, so an AX round trip would stall every click until the app answered.
/// They run in the AX helper when enabled, otherwise on the concurrent pool.
/// The helper gives them their own lanes, so they never queue behind a walk.
nonisolated enum MenuBarAXQueries {
    /// A pointer read that takes longer than this is no use to the pointer.
    private static let timeoutSeconds = 1.0

    private static func viaHelper(_ request: AXHelperRequest) async -> AXSubmissionOutcome {
        guard !Task.isCancelled else { return .cancelledOrUnknownAfterSubmission }
        guard let client = MenuBarAXSubprocess.client else { return .unavailableBeforeSubmission }
        return await client.sendOutcome(request, timeoutSeconds: timeoutSeconds)
    }

    static func perform(
        _ request: AXHelperRequest,
        helper: @Sendable (AXHelperRequest) async -> AXSubmissionOutcome,
        fallback: @Sendable () async -> AXHelperReply?
    ) async -> AXHelperReply? {
        guard !Task.isCancelled else { return nil }
        switch await helper(request) {
        case let .answered(reply):
            return Task.isCancelled ? nil : reply
        case .unavailableBeforeSubmission:
            guard !Task.isCancelled else { return nil }
            return await fallback()
        case .cancelledOrUnknownAfterSubmission:
            return nil
        }
    }

    // MARK: Application menu

    /// Frames of the app's menu bar titles, or nil when they could not be read.
    @concurrent
    static func applicationMenuFrames(pid: pid_t) async -> [CGRect]? {
        guard case let .applicationMenuFrames(frames, _) = await perform(
            .applicationMenuFrames(pid: pid),
            helper: viaHelper,
            fallback: {
                guard let frames = await ApplicationMenuGeometryExecution.read(
                    pid: pid,
                    operation: { AXPrimitives.applicationMenuFrames(pid: pid) }
                ) else { return nil }
                return .applicationMenuFrames(frames: frames, accessibilityTrusted: true)
            }
        ) else { return nil }
        return frames
    }

    // MARK: Foreign widget hit-test

    /// Whether the element under point belongs to a third-party widget that
    /// should get the click instead of Thaw, as opposed to empty menu bar
    /// space, Thaw itself, or the front app's own menu bar.
    @concurrent
    static func isForeignWidget(at point: CGPoint) async -> Bool {
        let reply = await perform(
            .hitTest(x: point.x, y: point.y),
            helper: viaHelper,
            fallback: {
                guard let element = AXHelpers.element(at: point), let pid = AXHelpers.pid(for: element) else { return nil }
                return .hitTest(AXHitTestResult(pid: pid, role: AXHelpers.roleString(for: element)), accessibilityTrusted: true)
            }
        )
        guard case let .hitTest(hit?, _) = reply, hit.pid > 0, hit.pid != getpid() else { return false }
        // SystemUIServer, and on macOS 27 MenuBarAgent, render the menu bar
        // background, so a hit on them is empty menu bar space. WindowServer
        // renders menu bar surfaces too but has no bundle identifier.
        switch NSRunningApplication(processIdentifier: hit.pid)?.bundleIdentifier {
        case "com.apple.systemuiserver", SharedConstants.menuBarHostingBundleID:
            return false
        default:
            break
        }
        if isWindowServer(hit.pid) {
            return false
        }
        // Between File/Edit/View the front app's menu bar answers with its own
        // PID but a menu-bar-class role; that is the app's menu, not a widget.
        switch hit.role {
        case "AXMenuBar", "AXMenu", "AXMenuItem", "AXMenuBarItem":
            return false
        default:
            return true
        }
    }

    private static func isWindowServer(_ pid: pid_t) -> Bool {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = buffer.withUnsafeMutableBufferPointer { pointer -> Int32 in
            guard let base = pointer.baseAddress else { return -1 }
            return proc_name(pid, base, UInt32(pointer.count))
        }
        guard length > 0 else { return false }
        let name = buffer.prefix { $0 != 0 }.map(UInt8.init)
        return String(bytes: name, encoding: .utf8) == "WindowServer"
    }

    // MARK: Presses

    /// Presses one of pid's own status items. With several, only the one
    /// whose frame centre lies within 10 pt of target is pressed.
    @concurrent
    static func pressStatusItem(pid: pid_t, target: CGPoint) async -> Bool {
        let tolerance = 10.0
        guard case let .press(pressed, _) = await perform(
            .pressStatusItem(pid: pid, targetX: target.x, targetY: target.y, tolerance: tolerance),
            helper: viaHelper,
            fallback: {
                .press(pressed: AXPrimitives.pressNearestStatusItem(pid: pid, target: target, tolerance: tolerance), accessibilityTrusted: true)
            }
        ) else { return false }
        return pressed
    }

    /// Presses a status item MenuBarAgent hosts on behalf of sourcePID.
    @concurrent
    static func pressHostedItem(sourcePID: pid_t) async -> Bool {
        guard case let .press(pressed, _) = await perform(
            .pressHostedItem(sourcePID: sourcePID),
            helper: viaHelper,
            fallback: {
                .press(pressed: MenuBarItemAXProvider.pressHostedItem(sourcePID: sourcePID), accessibilityTrusted: true)
            }
        ) else { return false }
        return pressed
    }
}
