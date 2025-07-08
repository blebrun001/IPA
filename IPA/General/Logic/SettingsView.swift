import SwiftUI


struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        Form {
            Section(header: Text("General")) {
                TextField("Jeton de l'API par défaut:", text: $settings.dataverseToken)
                TextField("Adresse du Dataverse par défaut:", text: $settings.dataverseAddress)
                Toggle("Activate sounds", isOn: $settings.enableSound)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
