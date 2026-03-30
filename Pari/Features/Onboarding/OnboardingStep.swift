//
//  OnboardingStep.swift
//  Pari
//
//  Condensed onboarding: Phone → Account (email+password) → Identity (name+username)
//  Photo is deferred to profile settings to reduce signup friction.
//

import Foundation

enum OnboardingStep: Int, CaseIterable {
    case phone = 0
    case account      // email + password
    case identity     // first name, last name, username

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
