//
//  ClaudeVisionService.swift
//  Vitis
//
//  Sends a wine label image to Claude Vision (haiku-4-5) and returns structured extraction.
//  Stateless enum — matches WineService / TastingService pattern.
//

import UIKit
import Foundation

enum ClaudeVisionError: LocalizedError {
    case notConfigured
    case networkError(Error)
    case apiError(status: Int, message: String)
    case invalidResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Label scanning is not configured. Please add your API key."
        case .networkError: return ErrorMessage.networkTimeout
        case .apiError(_, let msg): return msg
        case .invalidResponse: return ErrorMessage.unknown
        case .decodingError: return "Could not read the label. Please try again with a clearer photo."
        }
    }
}

enum ClaudeVisionService {

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"
    private static let maxImageDimension: CGFloat = 1568
    private static let jpegQuality: CGFloat = 0.7

    private static let systemPrompt = """
    You are a wine label analyzer. Given an image, determine if it shows a wine bottle label. \
    Respond with ONLY valid JSON, no markdown, no code fences.

    If the image does NOT show a wine label, respond:
    {"is_wine": false}

    If the image shows a wine label, extract:
    {"is_wine": true, "name": "wine name without vintage", "producer": "winery or château", \
    "vintage": 2020, "variety": "grape variety if visible", "region": "appellation or region if visible", \
    "category": "Red"}

    Rules:
    - vintage: 4-digit integer or null
    - category: exactly Red, White, Sparkling, Rose, or null
    - Use null for any field you cannot determine from the label
    - Do not guess — only extract what is visible
    """

    // MARK: - Public API

    /// Analyze a wine label image via Claude Vision. Returns structured extraction.
    static func analyzeLabel(image: UIImage) async throws -> LabelScanResult {
        guard let apiKey = ClaudeConfig.apiKey else { throw ClaudeVisionError.notConfigured }

        let base64 = try prepareImage(image)
        let body = buildRequestBody(base64Image: base64)
        let data = try await post(body: body, apiKey: apiKey)
        return try parseResponse(data)
    }

    // MARK: - Image Preparation

    /// Resize to ≤1568px longest edge, compress to JPEG, base64-encode.
    private static func prepareImage(_ image: UIImage) throws -> String {
        let resized = resizeIfNeeded(image)
        guard let jpegData = resized.jpegData(compressionQuality: jpegQuality) else {
            throw ClaudeVisionError.invalidResponse
        }
        return jpegData.base64EncodedString()
    }

    private static func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxImageDimension else { return image }

        let scale = maxImageDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Request

    private static func buildRequestBody(base64Image: String) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 512,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Analyze this image. Is it a wine label? If yes, extract the wine details."
                        ]
                    ]
                ]
            ]
        ]
    }

    private static func post(body: [String: Any], apiKey: String) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw ClaudeVisionError.networkError(error)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeVisionError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw ClaudeVisionError.invalidResponse }

        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
                ?? "API error (HTTP \(http.statusCode))"
            throw ClaudeVisionError.apiError(status: http.statusCode, message: message)
        }

        return data
    }

    // MARK: - Response Parsing

    private static func parseResponse(_ data: Data) throws -> LabelScanResult {
        // Extract content[0].text from the Messages API response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ClaudeVisionError.invalidResponse
        }

        // Strip markdown code fences if Claude wrapped the JSON despite instructions
        let cleaned = stripCodeFences(text)

        do {
            let result = try JSONDecoder().decode(LabelScanResult.self, from: Data(cleaned.utf8))
            return result
        } catch {
            throw ClaudeVisionError.decodingError(error)
        }
    }

    /// Remove ```json ... ``` fences if present.
    private static func stripCodeFences(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            // Remove opening fence (with optional language tag)
            if let newlineIdx = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: newlineIdx)...])
            }
        }
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
