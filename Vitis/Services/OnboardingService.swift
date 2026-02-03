//
//  OnboardingService.swift
//  Vitis
//
//  Complete onboarding: sign up, profile, user_private, avatar upload.
//

import Foundation
import Supabase

enum OnboardingService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    private static func userFacing(_ key: String) -> String {
        switch key {
        case "signup": return "Sign up failed. Please try again."
        case "session": return "Could not get session. Please try again."
        case "profile": return "Could not update profile. Please try again."
        case "phone": return "Could not save phone number. Please try again."
        default: return ErrorMessage.unknown
        }
    }

    static func complete(
        phoneE164: String,
        email: String,
        password: String,
        firstName: String,
        lastName: String?,
        username: String,
        avatarJpegData: Data?
    ) async throws {
        throw NSError(
            domain: "OnboardingService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Email onboarding is no longer supported."]
        )
    }
}
