//  SoundPlayer.swift
//  Utility class to play sound effects from app bundle.

import Foundation
import AVFoundation

class SoundPlayer {
    static var player: AVAudioPlayer?

    static func playSound(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("Error: sound '\(name).wav' not found")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Error while playing audio: \(error.localizedDescription)")
        }
    }
}
