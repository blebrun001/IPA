//  SettingsView.swift
//  Displays global application preferences, including Dataverse defaults and sound toggle.

import SwiftUI


struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("General", comment: "Settings section title"))) {
                TextField(NSLocalizedString("Default API token:", comment: "Settings field label for API token"), text: $settings.dataverseToken)
                TextField(NSLocalizedString("Default Dataverse address:", comment: "Settings field label for Dataverse address"), text: $settings.dataverseAddress)
                Toggle(NSLocalizedString("Activate sounds", comment: "Toggle to enable sound effects"), isOn: $settings.enableSound)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
