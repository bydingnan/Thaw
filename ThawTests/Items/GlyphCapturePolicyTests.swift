//
//  GlyphCapturePolicyTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import MenuBarModel
import Testing
@testable import Thaw

/// Pins the rules that decide whether a crop is a real glyph and which of two
/// crops the cache keeps: MenuBarItemImageCache.isTrustedGlyph(_:) and
/// preferredCachedImage(existing:candidate:).
@MainActor
@Suite("Glyph capture policy")
struct GlyphCapturePolicyTests {
    /// A crop of the given point width. Opaque white unless blank, which
    /// leaves every pixel transparent.
    private static func capture(
        width: CGFloat,
        scale: CGFloat = 1,
        blank: Bool = false
    ) throws -> MenuBarItemGlyphCapture {
        let pixelWidth = Int(width * scale)
        let pixelHeight = Int(16 * scale)
        let context = try #require(CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        if !blank {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        }
        return try MenuBarItemGlyphCapture(cgImage: #require(context.makeImage()), scale: scale)
    }

    // MARK: isTrustedGlyph

    @Test("A crop exactly at the minimum width is trusted")
    func minimumWidthIsTrusted() throws {
        let width = MenuBarItemImageCache.minimumTrustedGlyphWidth
        #expect(try MenuBarItemImageCache.isTrustedGlyph(Self.capture(width: width)))
        #expect(try MenuBarItemImageCache.isTrustedGlyph(Self.capture(width: width + 9)))
    }

    @Test("A crop one point under the minimum width is chevron bleed")
    func underMinimumWidthIsNotTrusted() throws {
        let width = MenuBarItemImageCache.minimumTrustedGlyphWidth - 1
        #expect(try !MenuBarItemImageCache.isTrustedGlyph(Self.capture(width: width)))
    }

    @Test("The width is measured in points, not device pixels")
    func widthIsMeasuredInPoints() throws {
        // 28 px at 2x is 14 pt: wide enough in pixels, too narrow in points.
        #expect(try !MenuBarItemImageCache.isTrustedGlyph(Self.capture(width: 14, scale: 2)))
        #expect(try MenuBarItemImageCache.isTrustedGlyph(Self.capture(width: 15, scale: 2)))
    }

    @Test("A blank crop is never trusted, however wide")
    func blankIsNotTrusted() throws {
        #expect(try !MenuBarItemImageCache.isTrustedGlyph(Self.capture(width: 24, blank: true)))
    }

    // MARK: preferredCachedImage

    @Test("A blank existing image loses to any candidate")
    func blankExistingLoses() throws {
        let existing = try Self.capture(width: 24, blank: true)
        let narrow = try Self.capture(width: 8)
        let blank = try Self.capture(width: 20, blank: true)

        #expect(MenuBarItemImageCache.preferredCachedImage(existing: existing, candidate: narrow) == narrow)
        #expect(MenuBarItemImageCache.preferredCachedImage(existing: existing, candidate: blank) == blank)
    }

    @Test("A blank candidate loses to a settled glyph")
    func blankCandidateLoses() throws {
        let existing = try Self.capture(width: 20)
        let candidate = try Self.capture(width: 24, blank: true)

        #expect(MenuBarItemImageCache.preferredCachedImage(existing: existing, candidate: candidate) == existing)
    }

    @Test("An untrusted narrow candidate keeps the settled glyph")
    func untrustedNarrowCandidateStillKeepsSettledGlyph() throws {
        let existing = try Self.capture(width: 20)
        let candidate = try Self.capture(width: 14)

        #expect(MenuBarItemImageCache.preferredCachedImage(existing: existing, candidate: candidate) == existing)
    }

    @Test("A trusted legitimate shrink replaces the wide glyph")
    func trustedLegitimateShrinkReplacesWideGlyph() throws {
        let existing = try Self.capture(width: 40)
        let candidate = try Self.capture(width: 15)

        #expect(MenuBarItemImageCache.preferredCachedImage(existing: existing, candidate: candidate) == candidate)
    }

    @Test("A candidate at least as wide replaces the existing glyph")
    func trustedCandidateAtSameWidthReplacesExistingGlyph() throws {
        let existing = try Self.capture(width: 20)
        let same = try Self.capture(width: 20)
        let wider = try Self.capture(width: 32)

        #expect(MenuBarItemImageCache.preferredCachedImage(existing: existing, candidate: same) == same)
        #expect(MenuBarItemImageCache.preferredCachedImage(existing: existing, candidate: wider) == wider)
    }

    private func renderability(blank: Bool) throws -> Bool {
        let appState = AppState()
        let cache = MenuBarItemImageCache(screenIsLocked: { false })
        cache.appState = appState
        let diskTag = MenuBarItemTag(namespace: .string("com.example.renderability"), title: "Glyph", instanceIndex: 0)
        let item = MenuBarItem(
            tag: MenuBarItemTag(namespace: diskTag.namespace, title: diskTag.title, windowID: 301, instanceIndex: 0),
            windowID: 301,
            ownerPID: 999_993,
            sourcePID: 999_993,
            bounds: CGRect(x: 1000, y: 4, width: 24, height: 24),
            title: "Glyph",
            isOnScreen: true
        )
        var inventory = MenuBarItemCache(displayID: 42)
        inventory[.visible] = [item]
        appState.itemManager.itemCache = inventory
        try cache.setCapture(Self.capture(width: 24, blank: blank), for: diskTag)
        return cache.hasNoRenderableItems(in: .visible, hasScreenRecordingPermission: true)
    }

    @Test
    func hasNoRenderableItemsAcceptsDiskLoadedCaptureWithoutWindowID() throws {
        #expect(try !renderability(blank: false))
    }

    @Test
    func hasNoRenderableItemsRejectsEffectivelyBlankCapture() throws {
        #expect(try renderability(blank: true))
    }

    @Test
    func removedItemReappearanceSeedsBaselineWithoutRevealing() throws {
        let tag = MenuBarItemTag(namespace: .string("com.example.alert"), title: "A", instanceIndex: 0)
        var baselines = AlertRevealBaselines()
        let enabled: Set<String> = [tag.tagIdentifier]
        #expect(try baselines.changedIdentifiers(in: [tag: Self.capture(width: 20)], enabled: enabled).isEmpty)
        #expect(baselines.changedIdentifiers(in: [:], enabled: enabled).isEmpty)
        #expect(try baselines.changedIdentifiers(in: [tag: Self.capture(width: 30)], enabled: enabled).isEmpty)
    }

    @Test
    func disabledAndAbsentItemBaselinesArePruned() throws {
        let a = MenuBarItemTag(namespace: .string("com.example.alert"), title: "A", instanceIndex: 0)
        let b = MenuBarItemTag(namespace: .string("com.example.alert"), title: "B", instanceIndex: 0)
        let image = try Self.capture(width: 20)
        var baselines = AlertRevealBaselines()
        _ = baselines.changedIdentifiers(in: [a: image, b: image], enabled: [a.tagIdentifier, b.tagIdentifier])
        _ = baselines.changedIdentifiers(in: [b: image], enabled: [a.tagIdentifier])
        #expect(baselines.captures.isEmpty)
    }

    @Test
    func presentOptedInItemBaselineSurvivesUnrelatedCacheChanges() throws {
        let a = MenuBarItemTag(namespace: .string("com.example.alert"), title: "A", instanceIndex: 0)
        let b = MenuBarItemTag(namespace: .string("com.example.alert"), title: "B", instanceIndex: 0)
        let image = try Self.capture(width: 20)
        var baselines = AlertRevealBaselines()
        _ = baselines.changedIdentifiers(in: [a: image], enabled: [a.tagIdentifier])
        #expect(baselines.changedIdentifiers(in: [a: image, b: image], enabled: [a.tagIdentifier]).isEmpty)
        let changed = try baselines.changedIdentifiers(in: [a: Self.capture(width: 30)], enabled: [a.tagIdentifier])
        #expect(changed == [a.tagIdentifier])
    }
}
