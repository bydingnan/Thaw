//
//  WindowPresentationState.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation

/// Separates scene requests from windows that have actually been presented.
struct WindowPresentationState<ID: Hashable> {
    enum Request: Equatable {
        case present, activate, deferred, coalesced
    }

    private(set) var requested = Set<ID>()
    private(set) var presented = Set<ID>()
    private(set) var deferred = Set<ID>()

    var isEmpty: Bool {
        requested.isEmpty && presented.isEmpty && deferred.isEmpty
    }

    func contains(_ id: ID) -> Bool {
        requested.contains(id) || presented.contains(id)
    }

    mutating func request(_ id: ID, hasAction: Bool) -> Request {
        if presented.contains(id) {
            return .activate
        }
        if requested.contains(id) {
            return .coalesced
        }
        guard hasAction else {
            return deferred.insert(id).inserted ? .deferred : .coalesced
        }
        deferred.remove(id)
        requested.insert(id)
        return .present
    }

    mutating func didPresent(_ id: ID) {
        requested.remove(id)
        deferred.remove(id)
        presented.insert(id)
    }

    mutating func close(_ id: ID) {
        requested.remove(id)
        deferred.remove(id)
        presented.remove(id)
    }
}

struct ActivationRequestGate {
    private var generation: UInt64 = 0

    mutating func begin() -> UInt64 {
        generation &+= 1
        return generation
    }

    mutating func invalidate() {
        generation &+= 1
    }

    func isCurrent(_ token: UInt64) -> Bool {
        token == generation
    }
}

struct ActivationOccupancy {
    var hasWindowRequests = false
    var settings = false
    var thawBar = false
    var search = false
    var layoutEditor = false
    var hidesApplicationMenus = false
    var modal = false
    var visibleWindows = false

    var permitsAccessoryPolicy: Bool {
        !hasWindowRequests && !settings && !thawBar && !search && !layoutEditor
            && !hidesApplicationMenus && !modal && !visibleWindows
    }
}

enum LaunchPolicy {
    /// Nil means the conflict warning requested that launch stop entirely.
    static func launchPermissions(conflictAllowsLaunch: Bool, hasRequiredPermissions: Bool) -> Bool? {
        conflictAllowsLaunch ? hasRequiredPermissions : nil
    }
}
