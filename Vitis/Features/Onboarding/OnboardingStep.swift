//
//  OnboardingStep.swift
//  Vitis
//

import Foundation

enum OnboardingStep: Int, CaseIterable {
    case phone = 0
    case email
    case password
    case name
    case username
    case photo

    var progressLabel: String? {
        let n = rawValue + 1
        let total = Self.allCases.count
        return "\(n)/\(total)"
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
