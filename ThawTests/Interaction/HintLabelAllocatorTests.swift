//
//  HintLabelAllocatorTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Testing
@testable import Thaw

struct HintLabelAllocatorTests {
    @Test func twentySevenItemsReceiveUniqueActionableHints() throws {
        let identifiers = (0 ..< 27).map { "item-\($0)" }
        let labels = HintLabelAllocator.labels(for: identifiers)
        #expect(labels.count == 27)
        #expect(Set(labels.values).count == 27)
        #expect(labels.values.allSatisfy { $0.count == 2 })
        for identifier in identifiers {
            let label = try #require(labels[identifier])
            var session = HintInputSession(labels: Set(labels.values))
            for character in label.dropLast() {
                #expect(session.receive(.text(String(character))) == .pending)
            }
            #expect(try session.receive(.text(String(#require(label.last)))) == .choose(label))
        }
    }

    @Test func labelsRemainStableAcrossUnrelatedInventoryChanges() {
        let identifiers = (0 ..< 30).map { "item-\($0)" }
        let before = HintLabelAllocator.labels(for: identifiers)
        let after = HintLabelAllocator.labels(for: ["new-item"] + identifiers, previous: before)
        for identifier in identifiers {
            #expect(after[identifier] == before[identifier])
        }
        #expect(Set(after.values).count == 31)
    }

    @Test func singleLetterHintsRemainForSmallBars() {
        let identifiers = (0 ..< 26).map { "item-\($0)" }
        let labels = HintLabelAllocator.labels(for: identifiers)
        #expect(labels.values.allSatisfy { $0.count == 1 })
        #expect(labels["item-0"] == "a")
        #expect(labels["item-25"] == "m")
        var session = HintInputSession(labels: Set(labels.values))
        #expect(session.receive(.text("a")) == .choose("a"))
    }

    @Test func escapeCancelsMultiCharacterHint() {
        var session = HintInputSession(labels: ["aa", "as"])
        #expect(session.receive(.text("a")) == .pending)
        #expect(session.receive(.escape) == .cancelled)
        #expect(session.prefix.isEmpty)
    }

    @Test func backspaceEditsPrefixWithoutCancelling() {
        var session = HintInputSession(labels: ["aa", "sa"])
        #expect(session.receive(.text("a")) == .pending)
        #expect(session.receive(.backspace) == .pending)
        #expect(session.prefix.isEmpty)
        #expect(session.receive(.text("s")) == .pending)
        #expect(session.receive(.text("a")) == .choose("sa"))
    }

    @Test func shorterLabelsReturnWhenDenseBarShrinks() {
        let dense = HintLabelAllocator.labels(for: (0 ..< 27).map { "item-\($0)" })
        let ordinary = HintLabelAllocator.labels(for: ["item-0", "item-26"], previous: dense)
        #expect(ordinary.values.allSatisfy { $0.count == 1 })
        #expect(Set(ordinary.values).count == 2)
    }
}
