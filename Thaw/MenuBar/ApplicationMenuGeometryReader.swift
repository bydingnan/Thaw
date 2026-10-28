//
//  ApplicationMenuGeometryReader.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit
import MenuBarModel
import ThawAXCore

nonisolated enum ApplicationMenuGeometryExecution {
    @concurrent
    static func read<Value: Sendable>(
        pid: pid_t,
        operation: @Sendable () -> Value
    ) async -> Value {
        if pid == getpid() {
            return await MainActor.run { operation() }
        }
        return operation()
    }
}

@MainActor
final class ApplicationMenuGeometryReader {
    nonisolated struct Request: Equatable, Sendable {
        let displayID: CGDirectDisplayID
        let pid: pid_t
        let bundleIdentifier: String?
        let displayBounds: CGRect
    }

    nonisolated struct Snapshot: Equatable, Sendable {
        let pid: pid_t
        let titles: [MenuBarTitleFrame]
        let frame: CGRect
        let focus: DesktopFocusState
    }

    private struct Entry {
        var request: Request
        var generation: UInt64
        var snapshot: Snapshot?
        var task: Task<Void, Never>?
        var refreshedAt: ContinuousClock.Instant?
    }

    static let shared = ApplicationMenuGeometryReader()

    private let operation: @Sendable (Request) async -> Snapshot?
    private var entries: [CGDirectDisplayID: Entry] = [:]
    private var generation: UInt64 = 0

    init(operation: @escaping @Sendable (Request) async -> Snapshot? = { request in
        await ApplicationMenuGeometryExecution.read(pid: request.pid) {
            ApplicationMenuGeometryReader.readSnapshot(request)
        }
    }) {
        self.operation = operation
    }

    func snapshot(_ request: Request) async -> Snapshot? {
        _ = cached(request)
        await entries[request.displayID]?.task?.value
        guard !Task.isCancelled, entries[request.displayID]?.request == request else { return nil }
        return entries[request.displayID]?.snapshot
    }

    func snapshot(on screen: NSScreen) async -> Snapshot? {
        guard let request = request(on: screen) else { return nil }
        return await snapshot(request)
    }

    func cached(on screen: NSScreen, refresh: Bool = false) -> Snapshot? {
        guard let request = request(on: screen) else { return nil }
        return cached(request, refresh: refresh)
    }

    private func request(on screen: NSScreen) -> Request? {
        guard let owner = NSWorkspace.shared.menuBarOwningApplication ?? NSWorkspace.shared.frontmostApplication else { return nil }
        return Request(
            displayID: screen.displayID,
            pid: owner.processIdentifier,
            bundleIdentifier: owner.bundleIdentifier,
            displayBounds: CGDisplayBounds(screen.displayID)
        )
    }

    func cached(_ request: Request, refresh: Bool = false) -> Snapshot? {
        let previous = entries[request.displayID]
        if let previous, previous.request == request {
            if previous.task != nil {
                return previous.snapshot
            }
            if !refresh, let refreshedAt = previous.refreshedAt, ContinuousClock.now - refreshedAt < .milliseconds(250) {
                return previous.snapshot
            }
        }
        generation &+= 1
        let token = generation
        previous?.task?.cancel()
        entries[request.displayID] = Entry(
            request: request, generation: token, snapshot: previous?.snapshot
        )
        let operation = operation
        let task = Task { [weak self] in
            let snapshot = await operation(request)
            guard let self, entries[request.displayID]?.generation == token else { return }
            entries[request.displayID]?.task = nil
            entries[request.displayID]?.refreshedAt = .now
            if let snapshot {
                entries[request.displayID]?.snapshot = snapshot
            }
        }
        entries[request.displayID]?.task = task
        return previous?.snapshot
    }

    func removeDisconnectedDisplays(keeping displays: Set<CGDirectDisplayID>) {
        for (id, entry) in entries where !displays.contains(id) {
            entry.task?.cancel()
            entries.removeValue(forKey: id)
        }
    }

    private static nonisolated func readSnapshot(_ request: Request) -> Snapshot? {
        guard !Task.isCancelled else { return nil }
        let app = AXElement.application(request.pid)
        app.setMessagingTimeout(AXPrimitives.defaultMessagingTimeout)
        let attributes = app.values([kAXMenuBarAttribute, kAXFocusedWindowAttribute])
        guard let menuBar = attributes[kAXMenuBarAttribute] as? AXElement else { return nil }
        menuBar.setMessagingTimeout(AXPrimitives.defaultMessagingTimeout)
        let menuAttributes = menuBar.values([kAXChildrenAttribute, "AXFrame"])
        guard let children = menuAttributes[kAXChildrenAttribute] as? [AXElement] else { return nil }
        let titles = children.map { child in
            child.setMessagingTimeout(AXPrimitives.defaultMessagingTimeout)
            let values = child.values([kAXRoleAttribute, "AXFrame", kAXEnabledAttribute])
            return MenuBarTitleFrame(
                role: values[kAXRoleAttribute] as? String,
                frame: values["AXFrame"] as? CGRect ?? .null,
                isEnabled: values[kAXEnabledAttribute] as? Bool ?? false
            )
        }
        let union = titles.reduce(into: CGRect.null) { result, title in
            if AXMenuTitle.includes(role: title.role, isEnabled: title.isEnabled), !title.frame.isEmpty, !title.frame.isNull {
                result = result.union(title.frame)
            }
        }
        guard !union.isNull, !union.isEmpty, !Task.isCancelled else { return nil }
        let barOrigin = (menuAttributes["AXFrame"] as? CGRect)?.origin ?? .zero
        let offsetX = request.displayBounds.minX - barOrigin.x
        let offsetY = request.displayBounds.minY - barOrigin.y
        let normalized = titles.map {
            MenuBarTitleFrame(role: $0.role, frame: $0.frame.offsetBy(dx: offsetX, dy: offsetY), isEnabled: $0.isEnabled)
        }
        let focused = attributes[kAXFocusedWindowAttribute] as? AXElement
        focused?.setMessagingTimeout(AXPrimitives.defaultMessagingTimeout)
        let focus = DesktopFocusState.classify(
            frontmostBundleIdentifier: request.bundleIdentifier,
            hasFocusedWindow: focused != nil,
            focusedWindowSubrole: request.bundleIdentifier == ApplicationMenuCoverPolicy.finderBundleIdentifier
                ? focused?.value(kAXSubroleAttribute) as? String : nil
        )
        return Snapshot(pid: request.pid, titles: normalized, frame: union.offsetBy(dx: offsetX, dy: offsetY), focus: focus)
    }
}
