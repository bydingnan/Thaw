//
//  PostSourceOverflowEvidenceTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics
import Testing
@testable import Thaw

@MainActor
struct PostSourceOverflowEvidenceTests {
    @Test(arguments: [-1, 0])
    func postSourceOverflowValidationDoesNotReusePreCaptureChevronAbsenceMemo(offsetMilliseconds: Int) async {
        let now = ContinuousClock.now
        let cutoff = now - .seconds(1)
        let absentAt = cutoff + .milliseconds(offsetMilliseconds)
        let chevron = CGRect(x: 1200, y: 0, width: 24, height: 24)
        let gate = OverflowWalkGate<NativeOverflowObservation> { _, requestedCutoff in
            ChevronProbeReading.observation(
                hint: nil,
                lastAbsentAt: absentAt,
                now: now,
                cooldown: .seconds(12),
                isMasked: false,
                displayBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                newerThan: requestedCutoff,
                sweep: { _ in .present([chevron]) },
                record: { _ in }
            )
        }
        // A walk started after the cutoff can still reuse an older inner absence.
        #expect(await gate.observation(on: 1) == .absent)
        #expect(await gate.observation(on: 1, newerThan: cutoff) == .present([chevron]))
    }

    @Test(arguments: [-1, 0, 1])
    func postSourceOverflowValidationDoesNotUsePreCaptureMaskedAbsence(offsetMilliseconds: Int) async {
        let now = ContinuousClock.now
        let cutoff = now - .seconds(1)
        let absentAt = cutoff + .milliseconds(offsetMilliseconds)
        let gate = OverflowWalkGate<NativeOverflowObservation> { _, requestedCutoff in
            ChevronProbeReading.observation(
                hint: nil,
                lastAbsentAt: absentAt,
                now: now,
                cooldown: .seconds(12),
                isMasked: true,
                displayBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                newerThan: requestedCutoff,
                sweep: { _ in Issue.record("A masked bar cannot supply a new sweep"); return .absent },
                record: { _ in Issue.record("A masked bar must not renew absence") }
            )
        }
        #expect(await gate.observation(on: 1) == .absent)
        let observation = await gate.observation(on: 1, newerThan: cutoff)
        #expect(observation == (offsetMilliseconds > 0 ? .absent : .unavailable))
    }
}
