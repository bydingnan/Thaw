//
//  RecordingProbeFailureTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Testing
@testable import Thaw

struct RecordingProbeFailureTests {
    private let user = MicrophoneUser(processIdentifier: 42, bundleIdentifier: "test.recorder", name: "Recorder")

    @Test func failedCameraProbePreservesActivity() {
        let previous = RecordingActivity(isCameraInUse: true)
        let merged = RecordingWatchPolicy.merge(previous: previous, microphoneUsers: [], isCameraInUse: nil)
        #expect(merged.isCameraInUse)
        #expect(RecordingWatchPolicy.merge(previous: merged, microphoneUsers: [], isCameraInUse: false).isIdle)
    }

    @Test func failedMicrophoneProbePreservesUsers() {
        let previous = RecordingActivity(microphoneUsers: [user])
        let merged = RecordingWatchPolicy.merge(previous: previous, microphoneUsers: nil, isCameraInUse: false)
        #expect(merged.microphoneUsers == [user])
        #expect(!merged.isIdle)
    }

    @Test func transientFailureDoesNotRetriggerAnnouncement() {
        let previous = RecordingActivity(microphoneUsers: [user], isCameraInUse: true)
        let failed = RecordingWatchPolicy.merge(previous: previous, microphoneUsers: nil, isCameraInUse: nil)
        let recovered = RecordingWatchPolicy.merge(previous: failed, microphoneUsers: [user], isCameraInUse: true)
        #expect(RecordingWatchPolicy.announcements(from: previous, to: failed).isEmpty)
        #expect(RecordingWatchPolicy.announcements(from: failed, to: recovered).isEmpty)
    }

    @Test func transientFailureKeepsRecordingZenEngaged() {
        let previous = RecordingActivity(microphoneUsers: [user], isCameraInUse: true)
        let cameraFailure = RecordingWatchPolicy.merge(previous: previous, microphoneUsers: [], isCameraInUse: nil)
        #expect(!cameraFailure.isIdle)
        let microphoneFailure = RecordingWatchPolicy.merge(previous: previous, microphoneUsers: nil, isCameraInUse: false)
        #expect(!microphoneFailure.isIdle)
    }
}
