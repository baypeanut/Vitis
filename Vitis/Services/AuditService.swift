//
//  AuditService.swift
//  Pari
//
//  Server-side audit trail. Inserts via RPC; table is server-only readable.
//

import Foundation
import Supabase

enum AuditService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Log an audit event. Call after sensitive actions (privacy change, phone/email change, delete request).
    static func log(userId: UUID, eventType: String, metadata: [String: String] = [:]) async {
        let metaJson = (try? JSONSerialization.data(withJSONObject: metadata))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let params: [String: String] = [
            "p_user_id": userId.uuidString,
            "p_event_type": eventType,
            "p_metadata": metaJson
        ]
        _ = try? await supabase.rpc("audit_log_insert", params: params).execute()
    }
}
