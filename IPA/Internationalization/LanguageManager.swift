//  LanguageManager.swift
//  Manages the application's language preference using UserDefaults.


import Foundation

class LanguageManager: ObservableObject {
    // Currently selected language code (e.g., "en", "fr", etc.)
    @Published var selectedLanguage: String {
        didSet {
            // Update the system language setting
            UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
    
    // Initialize the manager with the current system language
    init() {
        let current = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first
        self.selectedLanguage = current ?? Locale.current.language.languageCode?.identifier ?? "fr"
    }
    
    // Returns the list of available language codes supported by the app
    func availableLanguages() -> [String] {
        return ["fr", "en", "sp", "ca"]
    }
}
