import SwiftUI
import AppKit

// Entry point of the IPA Photogrammetry macOS application.
@main
struct IPAPhotogrammetryApp: App {
    
    // Manages the localization/internationalization of the app.
    @StateObject private var languageManager = LanguageManager()
    
    //Manages settings
    @StateObject var settings = SettingsManager()
    
    // Instanciation des ViewModels persistants pour chaque module
    @StateObject private var measureViewModel = MeasureViewModel()
    @StateObject private var photogrammetryViewModel = PhotogrammetryViewModel()
    @StateObject private var objScalerViewModel = OBJScalerViewModel()
    @StateObject private var objRenamerViewModel = OBJRenamerViewModel()
    @StateObject private var readmeGeneratorViewModel = ReadmeGeneratorViewModel()
    @StateObject private var dataverseViewModel = DataverseViewModel()
    @StateObject private var folderStructureViewModel = FolderStructureViewModel()
    @StateObject private var boneFolderViewModel = BoneFolderViewModel()
    
    var body: some Scene {
        WindowGroup {
            // Inject all ViewModels into the environment so they can be accessed throughout the UI
            ContentView()
                .environmentObject(languageManager)
                .environmentObject(measureViewModel)
                .environmentObject(photogrammetryViewModel)
                .environmentObject(objScalerViewModel)
                .environmentObject(objRenamerViewModel)
                .environmentObject(readmeGeneratorViewModel)
                .environmentObject(dataverseViewModel)
                .environmentObject(folderStructureViewModel)
                .environmentObject(boneFolderViewModel)
                .environmentObject(settings)
        }
        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

// Intermediate view that manages the splash screen and the transition to the main interface.
struct ContentView: View {
    @State private var showLaunchScreen = true
    
    var body: some View {
        Group {
            if showLaunchScreen {
                LaunchScreenView()
                    .onAppear {
                        print("Splash screen started")
                        // Durée du splash screen : 2 secondes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            print("Switching to MainView")
                            withAnimation {
                                showLaunchScreen = false
                            }
                        }
                    }
            } else {
                MainView() // MainView inherits all the previously injected environment objects.
            }
        }
    }
}
