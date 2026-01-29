//
//  SupabaseManager.swift
//  Vitis
//
//  Shared singleton for Supabase connection. Uses SupabaseConfig for credentials.
//

import Foundation
import Supabase

/// Central Supabase client. All services use this shared instance.
final class SupabaseManager {
    static let shared = SupabaseManager()

    private let client: SupabaseClient

    private init() {
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true)
        )
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: options
        )
    }

    /// Use for Auth, Postgrest, Storage, Realtime.
    var supabase: SupabaseClient { client }
}
