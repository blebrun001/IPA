// AnimatedLoader.swift
// Displays a looping animation (simulated GIF) during the photogrammetry process.

import SwiftUI

struct AnimatedLoader: View {
    @State private var frameIndex = 0
    let frames = (1...24).map { "img\($0)" } // // Array of image frame names ["img1", "img2", ..., "img24"]

    var body: some View {
        Image(frames[frameIndex])
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100) // Reduced size for compact display
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    frameIndex = (frameIndex + 1) % frames.count
                }
            }
    }
}
