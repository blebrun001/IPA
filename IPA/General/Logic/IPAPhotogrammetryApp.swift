//  IPAPhotogrammetryApp.swift
//  Application entry point that wires up environment objects and manages lifecycle tasks.

import SwiftUI
import AppKit

@main
struct IPAPhotogrammetryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var languageManager = LanguageManager()
    @StateObject var settings = SettingsManager.instance
    @StateObject private var measureViewModel = MeasureViewModel()
    @StateObject private var photogrammetryViewModel = PhotogrammetryViewModel()
    @StateObject private var autoScaleViewModel = AutoScaleViewModel()
    @StateObject private var objScalerViewModel = OBJScalerViewModel()
    @StateObject private var objRenamerViewModel = OBJRenamerViewModel()
    @StateObject private var readmeGeneratorViewModel = ReadmeGeneratorViewModel()
    @StateObject private var folderStructureViewModel = FolderStructureViewModel()
    @StateObject private var boneFolderViewModel = BoneFolderViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                .environmentObject(measureViewModel)
                .environmentObject(photogrammetryViewModel)
                .environmentObject(autoScaleViewModel)
                .environmentObject(objScalerViewModel)
                .environmentObject(objRenamerViewModel)
                .environmentObject(readmeGeneratorViewModel)
                .environmentObject(folderStructureViewModel)
                .environmentObject(boneFolderViewModel)
                .environmentObject(settings)
        }
        .onChange(of: scenePhase) { newPhase, _ in
            if newPhase == .background {
                cleanupTempDirectory()
            }
        }
        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }

    private func cleanupTempDirectory() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Failed to remove temporary file: \(error)")
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
                        // Splash screen duration: 2 seconds
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
