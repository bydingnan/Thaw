//
//  DevelopmentRunnerTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
import Testing

struct DevelopmentRunnerTests {
    @Test func builtFoldyDebugProductPassesProductCheck() async throws {
        try await Task.detached {
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [root.appendingPathComponent("scripts/tests/test-devrun-output.sh").path]
            var environment = ProcessInfo.processInfo.environment
            environment["TMPDIR"] = "/tmp/"
            process.environment = environment
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            process.waitUntilExit()
            #expect(process.terminationStatus == 0, "\(output)")
            #expect(output.contains("devrun output: all scenarios passed"))
        }.value
    }
}
