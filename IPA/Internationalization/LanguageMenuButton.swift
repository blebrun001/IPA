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
                    if lang == languageManager.selectedLanguage {
                        Label(label(for: lang), systemImage: "checkmark")
                    } else {
                        Text(label(for: lang))
                    }
                }
            }
        } label: {
            // Menu button icon
            Label(NSLocalizedString("Language", comment: "Toolbar language picker label"), systemImage: "globe")
                .labelStyle(IconOnlyLabelStyle())
                .imageScale(.large)
        }
        .help(NSLocalizedString("Change the application language.", comment: "Language picker tooltip"))
        .alert(NSLocalizedString("Change language?", comment: "Language picker confirmation title"), isPresented: $showRestartAlert) {
            Button(NSLocalizedString("Cancel", comment: "Cancel language change"), role: .cancel) {
                pendingLanguage = nil
            }
            Button(NSLocalizedString("Restart", comment: "Confirm language change and restart"), role: .destructive) {
                if let lang = pendingLanguage {
                    languageManager.selectedLanguage = lang
                    restartApp()
                }
            }
        } message: {
            Text(NSLocalizedString("The application will restart to apply the selected language.", comment: "Language picker confirmation message"))
        }
    }

    // Translates language codes to human-readable labels
    func label(for code: String) -> String {
        switch code {
        case "fr": return NSLocalizedString("French", comment: "French language name")
        case "en": return NSLocalizedString("English", comment: "English language name")
        case "es": return NSLocalizedString("Spanish", comment: "Spanish language name")
        case "ca": return NSLocalizedString("Catalan", comment: "Catalan language name")
        default: return code
        }
    }
}
