//
//  PermissionFileProbe.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation

/// Protected-file probes share a utility queue; security-scope ownership stays on the caller's actor.
enum PermissionFileProbe {
    private static let queue = DispatchQueue(label: "Foldy.PermissionFileProbe", qos: .utility)

    static func read(_ operation: @escaping @Sendable () -> Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: operation()) }
        }
    }

    static func readablePropertyList(at url: URL) async -> Bool {
        await read {
            FileManager.default.isReadableFile(atPath: url.path) && NSDictionary(contentsOf: url) != nil
        }
    }
}

@MainActor
final class PermissionRefreshGate {
    private var generation: UInt64 = 0

    func invalidate() {
        generation &+= 1
    }

    func begin() -> UInt64 {
        generation &+= 1
        return generation
    }

    func refresh(token: UInt64? = nil, probe: () async -> Bool, publish: (Bool) -> Void) async {
        let token = token ?? begin()
        guard token == generation else { return }
        let value = await probe()
        guard token == generation else { return }
        publish(value)
    }
}
