//  SoundPlayer.swift
//  Utility class to play sound effects from app bundle.

import Foundation
import AVFoundation

class SoundPlayer {
    static var player: AVAudioPlayer?

    static func playSound(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("Erreur : son '\(name).wav' introuvable")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Erreur lors de la lecture audio : \(error.localizedDescription)")
        }
    }
}
