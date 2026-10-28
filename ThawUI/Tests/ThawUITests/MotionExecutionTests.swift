//
//  MotionExecutionTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Testing
import ThawUI

@MainActor
struct MotionExecutionTests {
    @Test func animatedOperationExecutesExactlyOnceAndReturnsItsValue() {
        var transitions = [Int]()
        let result = withThawAnimation(ThawMotion.quick) {
            transitions.append(42)
            return transitions.last
        }
        #expect(transitions == [42])
        #expect(result == 42)
    }

    @Test func failedAnimatedOperationPreservesOriginalErrorWithoutRetry() {
        enum Failure: Error, Equatable { case rejected }
        var attempts = 0
        do {
            try withThawAnimation(ThawMotion.settle) {
                attempts += 1
                throw Failure.rejected
            }
            Issue.record("Expected the operation's failure")
        } catch {
            #expect(error as? Failure == .rejected)
        }
        #expect(attempts == 1)
    }
}
