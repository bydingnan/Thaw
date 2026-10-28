//
//  NotificationCenterShortcutProviderTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
import Testing
@testable import Thaw

@MainActor
struct NotificationCenterShortcutProviderTests {
    @Test func refreshDoesNotSynchronizePreferencesOnMain() async {
        let provider = NotificationCenterShortcutProvider(read: {
            #expect(!Thread.isMainThread)
            return [.systemDefault]
        })
        await provider.refresh { _ in }.value
        #expect(provider.shortcuts == [.systemDefault])
    }

    @Test func unchangedSnapshotDoesNotReconfigureTap() async {
        let provider = NotificationCenterShortcutProvider(read: { [.systemDefault] })
        var publications = 0
        await provider.refresh { _ in publications += 1 }.value
        await provider.refresh { _ in publications += 1 }.value
        #expect(publications == 1)
    }

    @Test func changedBindingsPublishOnMainActor() async {
        let provider = NotificationCenterShortcutProvider(read: { [.systemDefault] })
        var published = [SystemNotificationCenterHotkey]()
        await provider.refresh {
            MainActor.assertIsolated()
            published = $0
        }.value
        #expect(published == [.systemDefault])
    }
}
