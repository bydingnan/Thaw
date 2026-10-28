//
//  ChevronProbeReading.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics

nonisolated enum ChevronProbeReading {
    static func absenceIsFresh(
        lastAbsentAt: ContinuousClock.Instant?,
        now: ContinuousClock.Instant,
        cooldown: Duration,
        newerThan cutoff: ContinuousClock.Instant?
    ) -> Bool {
        guard let lastAbsentAt, now - lastAbsentAt < cooldown else { return false }
        return cutoff.map { lastAbsentAt > $0 } ?? true
    }

    static func maskedObservation(
        hint: CGRect?,
        lastAbsentAt: ContinuousClock.Instant?,
        now: ContinuousClock.Instant,
        cooldown: Duration,
        newerThan cutoff: ContinuousClock.Instant? = nil
    ) -> NativeOverflowObservation {
        if let hint {
            return .present([hint])
        }
        return absenceIsFresh(lastAbsentAt: lastAbsentAt, now: now, cooldown: cooldown, newerThan: cutoff)
            ? .absent : .unavailable
    }

    static func observation(
        hint: CGRect?,
        lastAbsentAt: ContinuousClock.Instant?,
        now: ContinuousClock.Instant,
        cooldown: Duration,
        isMasked: Bool,
        displayBounds: CGRect,
        newerThan cutoff: ContinuousClock.Instant?,
        sweep: (CGRect) -> NativeOverflowObservation,
        record: (CGRect?) -> Void
    ) -> NativeOverflowObservation {
        if isMasked {
            return maskedObservation(hint: hint, lastAbsentAt: lastAbsentAt, now: now, cooldown: cooldown, newerThan: cutoff)
        }
        if let hint {
            switch sweep(narrowedProbeRect(around: hint, in: displayBounds)) {
            case let .present(frames):
                record(frames.first)
                return .present(frames)
            case .unavailable:
                return .unavailable
            case .absent:
                break
            }
        } else if absenceIsFresh(lastAbsentAt: lastAbsentAt, now: now, cooldown: cooldown, newerThan: cutoff) {
            return .absent
        }
        let full = sweep(displayBounds)
        switch full {
        case let .present(frames): record(frames.first)
        case .absent: record(nil)
        case .unavailable: break
        }
        return full
    }

    private static func narrowedProbeRect(around hint: CGRect, in displayBounds: CGRect) -> CGRect {
        let padding: CGFloat = 60
        let minX = max(displayBounds.minX, hint.minX - padding)
        let maxX = min(displayBounds.maxX, hint.maxX + padding)
        guard maxX > minX else { return displayBounds }
        return CGRect(x: minX, y: displayBounds.minY, width: maxX - minX, height: displayBounds.height)
    }
}
