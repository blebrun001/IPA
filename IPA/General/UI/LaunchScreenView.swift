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

                Text("IPA")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding(.top, 10)

                Text("Integrated Photogrammetry Assistant")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding(.top, 0)

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.top, 5)

                Text("© 2025 Brice Lebrun")
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
