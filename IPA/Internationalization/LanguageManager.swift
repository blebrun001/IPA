//  LanguageManager.swift
//  Manages the application's language preference using UserDefaults.


import Foundation

class LanguageManager: ObservableObject {
    private static let supportedLanguages = ["en", "fr", "es", "ca"]

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
        let storedLanguage = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first
        if let storedLanguage, LanguageManager.supportedLanguages.contains(storedLanguage) {
            self.selectedLanguage = storedLanguage
        } else {
            self.selectedLanguage = "en"
            UserDefaults.standard.set([self.selectedLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
    
    // Returns the list of available language codes supported by the app
    func availableLanguages() -> [String] {
        return LanguageManager.supportedLanguages
    }
}
