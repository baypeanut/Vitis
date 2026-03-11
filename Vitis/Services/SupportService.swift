//
//  SupportService.swift
//  Pari
//
//  Pari Concierge: submit support tickets to Supabase. No third-party SDKs.
//

import Foundation
import Supabase

enum SupportTicketSubject: String, CaseIterable, Identifiable {
    case technical = "Technical Issue"
    case feature = "Feature Request"
    case feedback = "Feedback"
    case other = "Other"

    var id: String { rawValue }
}

enum SupportService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Submit a support ticket. Uses current user id from AuthService.
    static func submitTicket(subject: String, message: String, contactEmail: String) async throws {
        guard let userId = await AuthService.currentUserId() else {
            throw NSError(domain: "SupportService", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be signed in to send a message."])
        }
        let trimmedEmail = contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedSubject.isEmpty, !trimmedMessage.isEmpty else {
            throw NSError(domain: "SupportService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please complete all fields."])
        }

        struct Row: Encodable {
            let user_id: UUID
            let email: String
            let subject: String
            let message: String
        }
        try await supabase
            .from("support_tickets")
            .insert(Row(user_id: userId, email: trimmedEmail, subject: trimmedSubject, message: trimmedMessage))
            .execute()
    }
}
