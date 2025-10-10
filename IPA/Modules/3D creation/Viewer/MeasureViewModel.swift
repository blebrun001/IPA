//  MeasureViewModel.swift
//  Global ViewModel to store the uncalibrated measurement value.


import SwiftUI

// Uncalibrated measurement as a string (e.g. from user input)
class MeasureViewModel: ObservableObject {
    @Published var uncalibrated: String = ""
}
