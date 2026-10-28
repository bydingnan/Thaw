//
//  AppRelauncher.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit

/// Quits Thaw and opens it again.
@MainActor
enum AppRelauncher {
    static func watcherArguments(bundlePath: String, pid: Int32) -> [String] {
        [
            "-c",
            "while /bin/kill -0 \"$2\" 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open \"$1\"",
            "foldy-relaunch",
            bundlePath,
            String(pid),
        ]
    }

    /// Starts the child while failure can still preserve the running instance.
    /// Closing the gate arms the PID watcher only after cleanup has finished.
    static func prepareWatcher() throws -> () -> Void {
        let process = Process()
        let gate = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        var arguments = watcherArguments(
            bundlePath: Bundle.main.bundlePath,
            pid: ProcessInfo.processInfo.processIdentifier
        )
        arguments[1] = "/bin/cat >/dev/null; " + arguments[1]
        process.arguments = arguments
        process.standardInput = gate
        try process.run()
        gate.fileHandleForReading.closeFile()
        return {
            gate.fileHandleForWriting.closeFile()
            _ = process
        }
    }

    /// A detached shell waits for this PID to exit before reopening, since an
    /// overlapping launch can leave two copies. Foundation Process because
    /// Subprocess ties the child to a task that dies with the app.
    ///
    /// Throws and keeps the app running if the watcher cannot start.
    static func relaunch() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let bundlePath = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = watcherArguments(bundlePath: bundlePath, pid: pid)
        try process.run()
        NSApp.terminate(nil)
    }
}
