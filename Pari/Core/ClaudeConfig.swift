//
//  ClaudeConfig.swift
//  Pari
//
//  Claude Vision is proxied through the claude-vision Supabase Edge Function.
//  The Anthropic API key is stored as a Supabase secret (server-side only).
//  Run: supabase secrets set CLAUDE_API_KEY=sk-ant-...
//

import Foundation

enum ClaudeConfig {
    /// Label scanning is available whenever Supabase is reachable.
    static var isEnabled: Bool { SupabaseConfig.isValid }
}
