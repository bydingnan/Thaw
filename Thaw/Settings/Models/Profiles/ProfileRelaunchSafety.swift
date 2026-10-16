//
//  ProfileRelaunchSafety.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

/// Applying a profile may make spacing relaunches safer, never less safe.
/// Only the user, in Settings, can turn confirmation off or switch back to relaunching.
nonisolated enum ProfileRelaunchSafety {
    /// The two settings that decide whether a spacing change relaunches apps.
    struct Settings: Equatable {
        var confirmRelaunch: Bool
        var applyMode: SpacingApplyMode
    }

    /// A profile saved before the mode existed keeps the current mode.
    static func merged(
        current: Settings,
        profileConfirmRelaunch: Bool,
        profileApplyMode: SpacingApplyMode?
    ) -> Settings {
        let profileMode = profileApplyMode ?? current.applyMode
        let applyMode: SpacingApplyMode = current.applyMode == .writeOnly || profileMode == .writeOnly
            ? .writeOnly
            : .relaunchApps
        return Settings(
            confirmRelaunch: current.confirmRelaunch || profileConfirmRelaunch,
            applyMode: applyMode
        )
    }

    @MainActor
    static func apply(_ profile: Profile, to displaySettings: DisplaySettingsManager) {
        let settings = merged(
            current: Settings(
                confirmRelaunch: displaySettings.confirmSpacingRelaunch,
                applyMode: displaySettings.spacingApplyMode
            ),
            profileConfirmRelaunch: profile.confirmSpacingRelaunch,
            profileApplyMode: profile.spacingApplyMode
        )
        displaySettings.spacingApplyMode = settings.applyMode
        displaySettings.confirmSpacingRelaunch = settings.confirmRelaunch
    }
}
