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
        case "signup": return "Kayıt yapılamadı."
        case "session": return "Oturum alınamadı. Lütfen tekrar deneyin."
        case "profile": return "Profil güncellenemedi. Lütfen tekrar deneyin."
        case "phone": return "Telefon numarası kaydedilemedi. Lütfen tekrar deneyin."
        default: return "Bir hata oluştu. Lütfen tekrar deneyin."
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
        let result = await AuthService.signUp(email: email, password: password, username: username)
        switch result {
        case .success:
            break
        case .failure(let msg):
            #if DEBUG
            print("[OnboardingService] signUp failed: \(msg)")
            #endif
            throw NSError(domain: "OnboardingService", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        guard let uid = await AuthService.currentUserId() else {
            #if DEBUG
            print("[OnboardingService] currentUserId nil after signUp – Confirm email kapalı mı?")
            #endif
            throw NSError(domain: "OnboardingService", code: -2, userInfo: [NSLocalizedDescriptionKey: userFacing("session")])
        }

        var avatarURL: String?
        if let data = avatarJpegData {
            do {
                avatarURL = try await AvatarStorageService.uploadAvatar(userId: uid, jpegData: data)
            } catch {
                #if DEBUG
                print("[OnboardingService] avatar upload failed: \(error)")
                #endif
                // Profil fotoğrafı olmadan devam et; kullanıcıyı bloklama.
            }
        }

        let fullName = [firstName, lastName?.trimmingCharacters(in: .whitespaces)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        do {
            try await AuthService.updateProfile(userId: uid, fullName: fullName.isEmpty ? nil : fullName, avatarURL: avatarURL)
        } catch {
            #if DEBUG
            print("[OnboardingService] updateProfile failed: \(error)")
            #endif
            throw NSError(domain: "OnboardingService", code: -3, userInfo: [NSLocalizedDescriptionKey: userFacing("profile")])
        }

        struct Row: Encodable {
            let user_id: UUID
            let phone_e164: String
        }
        do {
            try await supabase.from("user_private")
                .upsert(Row(user_id: uid, phone_e164: phoneE164), onConflict: "user_id")
                .execute()
        } catch {
            #if DEBUG
            print("[OnboardingService] user_private upsert failed: \(error)")
            #endif
            throw NSError(domain: "OnboardingService", code: -4, userInfo: [NSLocalizedDescriptionKey: userFacing("phone")])
        }
    }
}
