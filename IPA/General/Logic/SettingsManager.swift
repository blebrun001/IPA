//  SettingsManager.swift
//  Centralized manager for user settings using AppStorage keys.

import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    static let instance = SettingsManager()
    @AppStorage("dataverseToken") var dataverseToken: String = ""
    @AppStorage("dataverseAddress") var dataverseAddress: String = ""
    @AppStorage("enableSound") var enableSound: Bool = true
}
