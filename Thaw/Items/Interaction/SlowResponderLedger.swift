//
//  SlowResponderLedger.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

/// Doubles cooldowns on consecutive AX misses and suppresses overlapping probes to avoid parking threads behind hung apps.
/// Timely answers clear the owner; callers supply the clock and check Window Server responsiveness outside the ledger lock.
nonisolated struct SlowResponderLedger: Sendable {
    enum Decision: Equatable, Sendable {
        case probe
        /// A slow owner whose cooldown ended: probe unless the window server
        /// flags it as not responding.
        case probeIfResponsive
        /// The probe that timed out has not returned yet.
        case skipInFlight
        case skipCoolingDown
    }

    static let baseCooldown: Duration = .seconds(5)
    static let maximumCooldown: Duration = .seconds(30)

    private struct Record: Sendable {
        var strikes = 0
        var retryAt: ContinuousClock.Instant
        var inFlightSince: ContinuousClock.Instant?
    }

    private var records: [Int32: Record] = [:]

    func strikes(for owner: Int32) -> Int {
        records[owner]?.strikes ?? 0
    }

    func decision(for owner: Int32, now: ContinuousClock.Instant = .now) -> Decision {
        guard let record = records[owner] else {
            return .probe
        }
        if record.inFlightSince != nil {
            return .skipInFlight
        }
        if now < record.retryAt {
            return .skipCoolingDown
        }
        return .probeIfResponsive
    }

    /// Claims an owner before starting AX, including calls later abandoned by cancellation.
    mutating func beginProbe(_ owner: Int32, now: ContinuousClock.Instant = .now) -> Bool {
        guard records[owner]?.inFlightSince == nil else { return false }
        var record = records[owner] ?? Record(retryAt: now)
        record.inFlightSince = now
        records[owner] = record
        return true
    }

    /// Records a probe that missed its deadline and is still running.
    ///
    /// - Returns: the cooldown the owner now sits out.
    @discardableResult
    mutating func timedOut(_ owner: Int32, now: ContinuousClock.Instant = .now) -> Duration {
        var record = records[owner] ?? Record(retryAt: now)
        let cooldown = Self.strike(&record, now: now)
        record.inFlightSince = now
        records[owner] = record
        return cooldown
    }

    /// Records an owner the window server flagged when its cooldown ended.
    /// It takes a strike without being probed.
    @discardableResult
    mutating func stillUnresponsive(_ owner: Int32, now: ContinuousClock.Instant = .now) -> Duration {
        var record = records[owner] ?? Record(retryAt: now)
        let cooldown = Self.strike(&record, now: now)
        records[owner] = record
        return cooldown
    }

    /// The probe that timed out finally returned. The cooldown stands: one
    /// late answer says nothing about the next.
    mutating func lateAnswerArrived(_ owner: Int32) {
        records[owner]?.inFlightSince = nil
    }

    mutating func answered(_ owner: Int32) {
        records[owner] = nil
    }

    mutating func retain(runningOwners: Set<Int32>) {
        records = records.filter { runningOwners.contains($0.key) }
    }

    private static func strike(_ record: inout Record, now: ContinuousClock.Instant) -> Duration {
        record.strikes += 1
        let doublings = min(record.strikes - 1, 8)
        let cooldown = min(baseCooldown * (1 << doublings), maximumCooldown)
        record.retryAt = now + cooldown
        return cooldown
    }
}
