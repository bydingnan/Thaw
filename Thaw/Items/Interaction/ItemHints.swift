//
//  ItemHints.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import MenuBarModel

/// Type an item's hint after the shortcut to open it as if clicked.
/// Concealed frames are stale, so reveal the section or use search for those items.
@MainActor
final class ItemHints {
    private static let hintHeight: CGFloat = 22

    private weak var appState: AppState?
    private var panel: HintPanel?
    private var previousLabels: [String: String] = [:]
    private let diagLog = DiagLog(category: "ItemHints")

    func performSetup(with appState: AppState) {
        self.appState = appState
    }

    var isShowing: Bool {
        panel != nil
    }

    func toggle() {
        if isShowing {
            close()
        } else {
            show()
        }
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        panel.unregisterAsMenuBarOverlay()
        panel.orderOut(nil)
    }

    private func show() {
        guard let appState, let screen = NSScreen.screenWithActiveMenuBar ?? NSScreen.main else { return }
        let targets = Self.itemsOnBar(appState: appState, screen: screen)
        guard !targets.isEmpty else {
            diagLog.info("No menu bar items to hint on display \(screen.displayID)")
            return
        }
        let labels = HintLabelAllocator.labels(for: targets.map(\.uniqueIdentifier), previous: previousLabels)
        previousLabels = labels
        let hints = targets.compactMap { item in
            labels[item.uniqueIdentifier].map { Hint(label: $0, item: item) }
        }

        let barHeight = screen.getMenuBarHeight() ?? screen.getMenuBarHeightEstimate()
        let frame = CGRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - barHeight - Self.hintHeight - 4,
            width: screen.frame.width,
            height: Self.hintHeight + 4
        )
        let panel = HintPanel(contentRect: frame)
        panel.contentView = HintView(hints: hints, screenFrame: screen.frame) { [weak self] hint in
            self?.choose(hint, on: screen.displayID)
        } onCancel: { [weak self] in
            self?.close()
        }
        panel.onResignKey = { [weak self] in self?.close() }
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        panel.registerAsMenuBarOverlay()
        diagLog.info("Showing \(hints.count) item hint(s) on display \(screen.displayID)")
    }

    private func choose(_ hint: Hint, on displayID: CGDirectDisplayID) {
        close()
        guard let appState else { return }
        diagLog.info("Hint \(hint.label) opens \(hint.item.logString)")
        Task {
            await appState.itemManager.clickConcealedItem(item: hint.item, with: .left, on: displayID)
        }
    }

    /// Left-to-right items in shown sections on this screen, excluding Thaw controls.
    private static func itemsOnBar(appState: AppState, screen: NSScreen) -> [MenuBarItem] {
        let controller = appState.menuBarManager.sectionController
        // The kit reports Visible as hidden when nothing is revealed, but Visible is always on the bar.
        let shown = MenuBarSection.Name.allCases.filter { $0 == .visible || !controller.isSectionHidden($0) }
        return shown
            .flatMap { appState.itemManager.managedItems(for: $0) }
            .filter { item in
                !item.isControlItem
                    && item.bounds.width > 0
                    && NSScreen.cocoaRect(fromCG: item.bounds).map { screen.frame.contains(CGPoint(x: $0.midX, y: $0.midY)) } == true
                    && !appState.itemManager.isThawBarOnly(item)
            }
            .sorted { $0.bounds.minX < $1.bounds.minX }
    }

    fileprivate struct Hint {
        let label: String
        let item: MenuBarItem
    }

    /// Takes hint key presses without activating Thaw, preserving the front app's menus.
    private final class HintPanel: NSPanel {
        var onResignKey: (() -> Void)?

        init(contentRect: CGRect) {
            super.init(
                contentRect: contentRect,
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            isFloatingPanel = true
            level = .mainMenu + 1
            backgroundColor = .clear
            isOpaque = false
            hasShadow = false
            hidesOnDeactivate = false
            collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle, .canJoinAllSpaces, .stationary]
            sharingType = .none
            animationBehavior = .none
        }

        override var canBecomeKey: Bool {
            true
        }

        override func resignKey() {
            super.resignKey()
            onResignKey?()
        }
    }

    /// Escape cancels; backspace edits a partial multi-character hint.
    private final class HintView: NSView {
        private let hints: [Hint]
        private var input: HintInputSession
        private let screenFrame: CGRect
        private let onChoose: (Hint) -> Void
        private let onCancel: () -> Void

        init(hints: [Hint], screenFrame: CGRect, onChoose: @escaping (Hint) -> Void, onCancel: @escaping () -> Void) {
            self.hints = hints
            self.input = HintInputSession(labels: Set(hints.map(\.label)))
            self.screenFrame = screenFrame
            self.onChoose = onChoose
            self.onCancel = onCancel
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool {
            true
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            let key: HintInputSession.Key = switch event.keyCode {
            case 53: .escape
            case 51, 117: .backspace
            default: .text(event.charactersIgnoringModifiers ?? "")
            }
            switch input.receive(key) {
            case .pending:
                needsDisplay = true
            case let .choose(label):
                if let hint = hints.first(where: { $0.label == label }) {
                    onChoose(hint)
                }
            case .cancelled:
                onCancel()
            }
        }

        override func draw(_: NSRect) {
            let font = NSFont.systemFont(ofSize: 12, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            for hint in hints {
                guard hint.label.hasPrefix(input.prefix) else { continue }
                let text = hint.label.uppercased() as NSString
                let size = text.size(withAttributes: attributes)
                let badgeWidth = max(size.width + 10, ItemHints.hintHeight - 2)
                // Bounds use top-left global coordinates; view x starts at the screen's left edge.
                let centerX = hint.item.bounds.midX - screenFrame.minX
                let badge = CGRect(
                    x: centerX - badgeWidth / 2,
                    y: 2,
                    width: badgeWidth,
                    height: ItemHints.hintHeight - 2
                )
                let path = NSBezierPath(roundedRect: badge, xRadius: 5, yRadius: 5)
                NSColor.systemYellow.setFill()
                path.fill()
                NSColor.black.withAlphaComponent(0.35).setStroke()
                path.lineWidth = 0.5
                path.stroke()
                text.draw(
                    at: CGPoint(x: badge.midX - size.width / 2, y: badge.midY - size.height / 2),
                    withAttributes: attributes
                )
            }
        }
    }
}
