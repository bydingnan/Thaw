//
//  AboutSettingsPane.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// The About pane displays only the installed version.
struct AboutSettingsPane: View {
    var body: some View {
        Text(verbatim: Constants.versionString)
            .font(.callout.monospaced())
            .textSelection(.enabled)
            .accessibilityLabel(Text("Version"))
            .accessibilityValue(Text(verbatim: Constants.versionString))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                BehindWindowMaterialBackground(material: .sidebar)
                    .ignoresSafeArea()
            }
    }
}
