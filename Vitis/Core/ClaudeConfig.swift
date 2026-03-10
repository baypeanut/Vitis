//
//  ClaudeConfig.swift
//  Vitis
//
//  Claude Vision API key. Read from Info.plist (injected via Secrets.xcconfig at build time).
//  Never hardcode the key — keep it in xcconfig and gitignore the file.
//

import Foundation

enum ClaudeConfig {
    static var apiKey: String? {
        guard let key = Bundle.main.infoDictionary?["CLAUDE_API_KEY"] as? String,
              !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }

    static var isEnabled: Bool { apiKey != nil }
}
