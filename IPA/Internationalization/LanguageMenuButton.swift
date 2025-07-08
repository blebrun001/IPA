//  LanguageMenuButton.swift
//  Button component for selecting the application language and restarting the app.


import SwiftUI
import AppKit

// Relaunches the app to apply the new language
func restartApp() {
    let appPath = Bundle.main.bundlePath
    let script = """
    (sleep 0.5; open "\(appPath)") &
    """

    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", script]
    task.launch()

    NSApp.terminate(nil)
}

struct LanguageMenuButton: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    // Temporary storage for the selected language before confirmation
    @State private var pendingLanguage: String? = nil
    
    // Controls whether the restart confirmation alert is shown
    @State private var showRestartAlert = false

    var body: some View {
        Menu {
            // Generate a menu entry for each available language
            ForEach(languageManager.availableLanguages(), id: \.self) { lang in
                Button {
                    pendingLanguage = lang
                    showRestartAlert = true
                } label: {
                    // Add a checkmark to the currently selected language
                    Label(label(for: lang), systemImage: lang == languageManager.selectedLanguage ? "checkmark" : "")
                }
            }
        } label: {
            // Menu button icon
            Label("Langue", systemImage: "globe")
                .labelStyle(IconOnlyLabelStyle())
                .imageScale(.large)
        }
        .help("Changer la langue de l'application")
        .alert("Changer la langue ?", isPresented: $showRestartAlert) {
            Button("Annuler", role: .cancel) {
                pendingLanguage = nil
            }
            Button("Redémarrer", role: .destructive) {
                if let lang = pendingLanguage {
                    languageManager.selectedLanguage = lang
                    restartApp()
                }
            }
        } message: {
            Text("L'application va redémarrer pour appliquer la langue.")
        }
    }

    // Translates language codes to human-readable labels
    func label(for code: String) -> String {
        switch code {
        case "fr": return "Français"
        case "en": return "English"
        case "sp": return "Español"
        case "ca": return "Catalán"
        default: return code
        }
    }
}
