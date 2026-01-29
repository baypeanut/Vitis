//
//  SupabaseConfig.example.swift
//  Vitis
//
//  Copy this file to SupabaseConfig.swift and fill in your project URL and anon key.
//  SupabaseConfig.swift is gitignored. Do not commit real keys.
//  Dashboard → Project Settings → API → Project URL, anon public key.
//

import Foundation

enum SupabaseConfig {
    static let url = URL(string: "https://YOUR_PROJECT_REF.supabase.co")!
    static let anonKey = "YOUR_ANON_KEY"

    /// URL is https with valid host, key non-empty. Does not test network.
    static var isValid: Bool {
        url.scheme == "https" && (url.host?.isEmpty == false) && !anonKey.isEmpty
    }
}
