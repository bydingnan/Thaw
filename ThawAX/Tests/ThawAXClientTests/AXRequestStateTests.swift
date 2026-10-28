//
//  AXRequestStateTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
import Testing
@testable import ThawAXClient
import ThawAXCore

struct AXRequestStateTests {
    @Test func cancellationBeforeRegistrationIsRememberedWithoutGrowingGlobalState() {
        weak var released: AXRequestState?
        do {
            let state = AXRequestState()
            released = state
            state.cancel()
            #expect(!state.beginSubmission())
            state.complete()
        }
        #expect(released == nil)
    }

    @Test func cancellationRacingCompletedReplyDoesNotRetainRequestID() {
        weak var released: AXRequestState?
        do {
            let state = AXRequestState()
            released = state
            #expect(state.beginSubmission())
            state.complete()
            state.cancel()
            #expect(!state.isCancelled)
        }
        #expect(released == nil)
    }

    @Test func cancellationRacingTimeoutDoesNotRetainRequestID() {
        weak var released: AXRequestState?
        do {
            let state = AXRequestState()
            released = state
            #expect(state.beginSubmission())
            state.complete()
            if case .cancelledOrUnknownAfterSubmission = state.failureOutcome(for: AXWire.WireError.timedOut, callerCancelled: false) {
                state.cancel()
            } else {
                Issue.record("A submitted timeout must remain ambiguous")
            }
            #expect(!state.isCancelled)
        }
        #expect(released == nil)
    }

    @Test(arguments: [AXSubprocessError.helperExited, .helperNotRunning])
    func submittedHelperFailureCannotPermitAnotherPress(_ error: AXSubprocessError) {
        let state = AXRequestState()
        #expect(state.beginSubmission())
        if case .cancelledOrUnknownAfterSubmission = state.failureOutcome(for: error, callerCancelled: false) {
            return
        }
        Issue.record("A submitted request must not be retried in-process")
    }

    @Test func cancellationBeforeSubmissionStillForbidsFallback() {
        let state = AXRequestState()
        state.cancel()
        if case .cancelledOrUnknownAfterSubmission = state.failureOutcome(for: CancellationError(), callerCancelled: true) {
            return
        }
        Issue.record("Cancellation must not start an in-process request")
    }

    @Test func unavailableHelperBeforeSubmissionAllowsFallback() async {
        let client = AXSubprocessClient(configuration: .init(helperURL: URL(fileURLWithPath: "/nonexistent/foldy-ax-test-helper")))
        let outcome = await client.sendOutcome(.pressHostedItem(sourcePID: 123))
        if case .unavailableBeforeSubmission = outcome {
            return
        }
        Issue.record("Launch failure occurred before any request was submitted")
    }
}
