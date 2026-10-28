//
//  MenuBarAXQueriesTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
import Testing
@testable import Thaw
import ThawAXClient
import ThawAXCore

@MainActor
struct MenuBarAXQueriesTests {
    private actor Calls {
        var fallback = 0
        func pressed() -> AXHelperReply {
            fallback += 1
            return .press(pressed: true, accessibilityTrusted: true)
        }

        func read() -> AXHelperReply {
            fallback += 1
            return .applicationMenuFrames(frames: [], accessibilityTrusted: true)
        }
    }

    private func expectUnknownPressDoesNotFallBack() async {
        let calls = Calls()
        let reply = await MenuBarAXQueries.perform(
            .pressHostedItem(sourcePID: 123),
            helper: { _ in .cancelledOrUnknownAfterSubmission },
            fallback: { await calls.pressed() }
        )
        #expect(reply == nil)
        #expect(await calls.fallback == 0)
    }

    @Test func helperExitAfterSubmittedPressDoesNotPressAgainInProcess() async {
        await expectUnknownPressDoesNotFallBack()
    }

    @Test func helperTimeoutAfterSubmittedPressDoesNotPressAgainInProcess() async {
        await expectUnknownPressDoesNotFallBack()
    }

    @Test func cancelledHelperPressDoesNotFallBackToInProcessPress() async {
        let calls = Calls()
        let task = Task {
            await MenuBarAXQueries.perform(
                .pressHostedItem(sourcePID: 123),
                helper: { _ in .unavailableBeforeSubmission },
                fallback: { await calls.pressed() }
            )
        }
        task.cancel()
        #expect(await task.value == nil)
        #expect(await calls.fallback == 0)
    }

    @Test func cancelledApplicationMenuReadDoesNotIssueInProcessAXRead() async {
        let calls = Calls()
        let task = Task {
            await MenuBarAXQueries.perform(
                .applicationMenuFrames(pid: 123),
                helper: { _ in
                    withUnsafeCurrentTask { $0?.cancel() }
                    return .unavailableBeforeSubmission
                },
                fallback: { await calls.read() }
            )
        }
        #expect(await task.value == nil)
        #expect(await calls.fallback == 0)
    }

    @Test func helperOwnProcessReadDoesNotDuplicateInProcess() async {
        let calls = Calls()
        let expected = AXHelperReply.applicationMenuFrames(frames: [], accessibilityTrusted: true)
        let reply = await MenuBarAXQueries.perform(
            .applicationMenuFrames(pid: getpid()),
            helper: { _ in .answered(expected) },
            fallback: { await calls.read() }
        )
        #expect(reply == expected)
        #expect(await calls.fallback == 0)
    }

    @Test func unavailableBeforeSubmissionCanPressInProcessOnce() async {
        let calls = Calls()
        let reply = await MenuBarAXQueries.perform(
            .pressHostedItem(sourcePID: 123),
            helper: { _ in .unavailableBeforeSubmission },
            fallback: { await calls.pressed() }
        )
        #expect(reply == .press(pressed: true, accessibilityTrusted: true))
        #expect(await calls.fallback == 1)
    }
}
