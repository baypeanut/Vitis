//
//  ReportService.swift
//  Vitis
//
//  Submits user reports to the `reports` Supabase table.
//  Apple App Store Section 1.2 requirement for UGC apps.
//
//  ⚠️ MANUAL SUPABASE STEP REQUIRED — create the `reports` table before this will work.
//  See: docs/supabase_manual_steps.md
//

import Foundation
import Supabase

enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "spam"
    case inappropriate = "inappropriate"
    case harassment = "harassment"
    case misinformation = "misinformation"
    case underage = "underage"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .inappropriate: return "Inappropriate content"
        case .harassment: return "Harassment"
        case .misinformation: return "Misinformation"
        case .underage: return "Underage content"
        case .other: return "Other"
        }
    }
}

enum ReportContentType: String {
    case post = "post"
    case comment = "comment"
    case user = "user"
}

enum ReportService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Submit a content report. Requires `reports` table in Supabase (see manual steps).
    static func submitReport(
        contentType: ReportContentType,
        contentId: UUID,
        reportedUserId: UUID,
        reason: ReportReason
    ) async throws {
        guard let reporterId = await AuthService.currentUserId() else { return }
        let payload: [String: AnyJSON] = [
            "reporter_id": .string(reporterId.uuidString),
            "content_type": .string(contentType.rawValue),
            "content_id": .string(contentId.uuidString),
            "reported_user_id": .string(reportedUserId.uuidString),
            "reason": .string(reason.rawValue)
        ]
        try await supabase
            .from("reports")
            .insert(payload)
            .execute()
    }
}
