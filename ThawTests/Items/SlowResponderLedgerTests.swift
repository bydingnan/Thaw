//
//  SlowResponderLedgerTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Testing
@testable import Thaw

struct SlowResponderLedgerTests {
    @Test
    func slowOwnerIsNotReprobedWhileOriginalAXCallIsStillInFlight() {
        var ledger = SlowResponderLedger()
        let now = ContinuousClock.now
        let firstProbe = ledger.beginProbe(42, now: now)
        #expect(firstProbe)
        ledger.timedOut(42, now: now)
        #expect(ledger.decision(for: 42, now: now + .seconds(3600)) == .skipInFlight)
        let secondProbe = ledger.beginProbe(42, now: now + .seconds(3600))
        #expect(!secondProbe)
    }

    @Test
    func lateAnswerReleasesSingleFlightOwner() {
        var ledger = SlowResponderLedger()
        let now = ContinuousClock.now
        let firstProbe = ledger.beginProbe(42, now: now)
        #expect(firstProbe)
        ledger.timedOut(42, now: now)
        ledger.lateAnswerArrived(42)
        #expect(ledger.decision(for: 42, now: now) == .skipCoolingDown)
        #expect(ledger.decision(for: 42, now: now + .seconds(60)) == .probeIfResponsive)
        let secondProbe = ledger.beginProbe(42, now: now + .seconds(60))
        #expect(secondProbe)
    }

    @Test
    func terminatedOwnerReleasesSingleFlightState() {
        var ledger = SlowResponderLedger()
        let firstProbe = ledger.beginProbe(42)
        #expect(firstProbe)
        ledger.timedOut(42)
        ledger.retain(runningOwners: [])
        #expect(ledger.decision(for: 42) == .probe)
        let secondProbe = ledger.beginProbe(42)
        #expect(secondProbe)
    }

    @Test
    func cancelledWalkKeepsProbeClaimUntilAnswer() {
        var ledger = SlowResponderLedger()
        let now = ContinuousClock.now
        let firstProbe = ledger.beginProbe(42, now: now)
        #expect(firstProbe)
        #expect(ledger.decision(for: 42, now: now + .seconds(3600)) == .skipInFlight)
        #expect(ledger.strikes(for: 42) == 0)
        ledger.lateAnswerArrived(42)
        let secondProbe = ledger.beginProbe(42, now: now + .seconds(3600))
        #expect(secondProbe)
    }
}
