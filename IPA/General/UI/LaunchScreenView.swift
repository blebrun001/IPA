// LaunchScreenView.swift
// Displays the splash screen shown when the application starts.

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color(nsColor: NSColor.windowBackgroundColor) // Background color matches the main interface window
                    .edgesIgnoringSafeArea(.all)
            VStack {
                Image("logoSplashScreen2048") // App logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)

                Text(NSLocalizedString("IPA", comment: "Application acronym displayed on splash screen"))
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding(.top, 10)

                Text(NSLocalizedString("Integrated Photogrammetry Assistant", comment: "Full application name on splash screen"))
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding(.top, 0)

                Text(NSLocalizedString("Version 1.1.0", comment: "Splash screen version number"))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.top, 5)

                Text(NSLocalizedString("© 2025 Brice Lebrun", comment: "Splash screen copyright"))
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .padding(.top, 0)
            }
        }
    }
}

struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
    }
}
