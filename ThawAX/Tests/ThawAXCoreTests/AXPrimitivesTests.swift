//
//  AXPrimitivesTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import ApplicationServices
import CoreGraphics
import Foundation
import Testing
@testable import ThawAXCore

struct AXPrimitivesTests {
    @Test
    func rawChildrenReceiveDefaultMessagingTimeout() {
        assertDescendantTimeout(attribute: kAXChildrenAttribute, array: true)
    }

    @Test
    func rawExtrasMenuBarReceivesDefaultMessagingTimeout() {
        assertDescendantTimeout(attribute: kAXExtrasMenuBarAttribute, array: false)
    }

    @Test
    func menuBarAgentWindowDescendantsReceiveDefaultMessagingTimeout() {
        assertDescendantTimeout(attribute: kAXWindowsAttribute, array: true)
        assertDescendantTimeout(attribute: kAXChildrenAttribute, array: true)
    }

    @Test
    func rawHitTestElementReceivesMessagingTimeout() throws {
        let child = AXUIElementCreateApplication(-2)
        let point = CGPoint(x: 123, y: 456)
        let timeout: Float = 0.125
        var events: [String] = []
        let result = AXPrimitives.hitTestElement(
            at: point,
            messagingTimeout: timeout,
            hitTest: { _, requestedPoint, element in
                #expect(requestedPoint == point)
                #expect(events == ["root timeout"])
                events.append("hit test")
                element = child
                return .success
            },
            setTimeout: { element, requestedTimeout in
                #expect(requestedTimeout == timeout)
                events.append(element == child ? "child timeout" : "root timeout")
            }
        )
        let returned = try #require(result)
        #expect(returned == child)
        let read: (AXUIElement, String) -> Void = { element, attribute in
            #expect(element == child)
            #expect(events.contains("child timeout"))
            events.append(attribute)
        }
        read(returned, "PID")
        read(returned, "role")
        #expect(events == ["root timeout", "hit test", "child timeout", "PID", "role"])
    }

    @Test
    func rawHitTestFailureDoesNotReturnOrConfigureDescendant() {
        let child = AXUIElementCreateApplication(-2)
        var configured: [AXUIElement] = []
        let result = AXPrimitives.hitTestElement(
            at: .zero,
            hitTest: { _, _, element in
                element = child
                return .cannotComplete
            },
            setTimeout: { element, _ in configured.append(element) }
        )
        #expect(result == nil)
        #expect(configured.count == 1)
        #expect(!configured.contains(child))
    }

    @Test
    func rawHitTestMissingElementRemainsNil() {
        var timeoutCount = 0
        let result = AXPrimitives.hitTestElement(
            at: .zero,
            hitTest: { _, _, _ in .success },
            setTimeout: { _, _ in timeoutCount += 1 }
        )
        #expect(result == nil)
        #expect(timeoutCount == 1)
    }

    private func assertDescendantTimeout(attribute: String, array: Bool) {
        let parent = AXUIElementCreateApplication(-1)
        let child = AXUIElementCreateApplication(-2)
        var configured: [AXUIElement] = []
        let setTimeout: (AXUIElement, Float) -> Void = { element, timeout in
            #expect(timeout == AXPrimitives.defaultMessagingTimeout)
            configured.append(element)
        }
        let read: (AXUIElement, String) -> CFTypeRef? = { _, requested in
            #expect(requested == attribute)
            if array {
                return [child] as CFArray
            }
            return child
        }
        if attribute == kAXChildrenAttribute {
            #expect(AXPrimitives.children(of: parent, read: read, setTimeout: setTimeout) == [child])
        } else if array {
            #expect(AXPrimitives.elementArrayAttribute(parent, attribute, read: read, setTimeout: setTimeout) == [child])
        } else {
            #expect(AXPrimitives.elementAttribute(parent, attribute, read: read, setTimeout: setTimeout) == child)
        }
        #expect(configured == [child])
    }

    @Test
    func applicationMenuFramesExcludeStatusItemHosts() {
        #expect(!AXMenuTitle.includes(role: "AXGroup", isEnabled: true))
        #expect(!AXMenuTitle.includes(role: "AXButton", isEnabled: true))
    }

    @Test
    func applicationMenuFramesExcludeDisabledTitles() {
        #expect(!AXMenuTitle.includes(role: "AXMenuBarItem", isEnabled: false))
        #expect(!AXMenuTitle.includes(role: "AXMenuItem", isEnabled: nil))
    }

    @Test
    func applicationMenuFramesRetainEnabledMenuRoles() {
        #expect(AXMenuTitle.includes(role: "AXMenuBarItem", isEnabled: true))
        #expect(AXMenuTitle.includes(role: "AXMenuItem", isEnabled: true))
    }

    @Test
    func `only this process counts as its own`() {
        #expect(AXPrimitives.isOwnProcess(getpid()))
        #expect(!AXPrimitives.isOwnProcess(getppid()))
        #expect(!AXPrimitives.isOwnProcess(0))
    }

    @Test
    func `frame is within uses the midpoint`() {
        let display = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(AXPrimitives.frame(CGRect(x: 90, y: 90, width: 20, height: 20), isWithin: display))
        #expect(!AXPrimitives.frame(CGRect(x: 95, y: 95, width: 20, height: 20), isWithin: display))
    }

    @Test
    func `a parked frame belongs to no display`() {
        let display = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(AXPrimitives.frame(CGRect(x: -1, y: 500, width: 20, height: 20), isWithin: display))
    }

    @Test
    func `an item frame overflowing the bar is cut to the bar its centre implies`() {
        // A 24 pt item reported as a 258 pt box centred on a 31 pt bar.
        let frame = CGRect(x: 3411, y: -113.5, width: 24, height: 258)
        #expect(AXPrimitives.itemFrame(frame, maximumHeight: 40, displayTop: 0)
            == CGRect(x: 3411, y: 0, width: 24, height: 31))
    }

    @Test
    func `popovers and off-centre boxes stay rejected`() {
        // Hangs below the bar.
        #expect(AXPrimitives.itemFrame(CGRect(x: 100, y: 24, width: 300, height: 250), maximumHeight: 40, displayTop: 0) == nil)
        // Reaches above the display but its centre implies no bar.
        #expect(AXPrimitives.itemFrame(CGRect(x: 100, y: -300, width: 24, height: 258), maximumHeight: 40, displayTop: 0) == nil)
        // Display unknown.
        #expect(AXPrimitives.itemFrame(CGRect(x: 100, y: -113.5, width: 24, height: 258), maximumHeight: 40, displayTop: nil) == nil)
    }

    @Test
    func `an ordinary item frame is kept as is`() {
        let frame = CGRect(x: 100, y: 3.5, width: 24, height: 24)
        #expect(AXPrimitives.itemFrame(frame, maximumHeight: 40, displayTop: nil) == frame)
        #expect(AXPrimitives.itemFrame(CGRect(x: 100, y: 0, width: 24, height: 0), maximumHeight: 40, displayTop: 0) == nil)
    }

    @Test
    func `press treats success as opened`() {
        var askedOwner = false
        let opened = AXPrimitives.press(perform: { .success }, ownerPID: {
            askedOwner = true
            return nil
        })
        #expect(opened)
        #expect(!askedOwner)
    }

    @Test
    func `press treats a plain failure as not opened`() {
        #expect(!AXPrimitives.press(perform: { .failure }, ownerPID: { nil }))
    }

    @Test
    func `press cannot complete without an owner is not opened`() {
        #expect(!AXPrimitives.press(perform: { .cannotComplete }, ownerPID: { nil }))
    }

    @Test
    func `press cannot complete without an open menu is not opened`() {
        // The test process has no window on the popup menu layer, so a
        // cannotComplete that no open menu explains is a failure.
        #expect(!AXPrimitives.press(perform: { .cannotComplete }, ownerPID: { getpid() }))
    }

    @Test
    func `no process is tracking an open menu at a bogus pid`() {
        #expect(!AXPrimitives.isTrackingOpenMenu(pid: -1))
    }
}
