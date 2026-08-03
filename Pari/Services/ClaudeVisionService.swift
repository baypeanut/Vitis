//
//  ClaudeVisionService.swift
//  Pari
//
//  Sends a wine label image to the claude-vision Supabase Edge Function.
//  The Anthropic API key lives server-side as a Supabase secret — never in the app binary.
//

import UIKit
import Foundation
import Supabase

enum ClaudeVisionError: LocalizedError {
    case networkError(Error)
    case apiError(status: Int, message: String)
    case invalidResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .networkError: return ErrorMessage.networkTimeout
        case .apiError(_, let msg): return msg
        case .invalidResponse: return ErrorMessage.unknown
        case .decodingError: return "Could not read the label. Please try again with a clearer photo."
        }
    }
}

enum ClaudeVisionService {

    private static let maxImageDimension: CGFloat = 1568
    private static let jpegQuality: CGFloat = 0.7

    private static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    // MARK: - Public API

    /// Analyze a wine label image via the claude-vision Edge Function.
    static func analyzeLabel(image: UIImage) async throws -> LabelScanResult {
        let base64 = try prepareImage(image)
        return try await invokeEdgeFunction(base64Image: base64)
    }

    // MARK: - Image Preparation

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

    // MARK: - Edge Function

    private static func invokeEdgeFunction(base64Image: String) async throws -> LabelScanResult {
        struct Payload: Encodable {
            let image_base64: String
        }

        let data: Data
        do {
            data = try await supabase.functions
                .invoke("claude-vision", options: FunctionInvokeOptions(body: Payload(image_base64: base64Image)))
        } catch let fnError as FunctionsError {
            switch fnError {
            case .httpError(let code, _):
                throw ClaudeVisionError.apiError(status: code, message: message(forStatus: code))
            default:
                throw ClaudeVisionError.networkError(fnError)
            }
        } catch {
            throw ClaudeVisionError.networkError(error)
        }

        do {
            return try JSONDecoder().decode(LabelScanResult.self, from: data)
        } catch {
            throw ClaudeVisionError.decodingError(error)
        }
    }

    /// The edge function gates scans on auth, payload size and a per-user quota. Each of
    /// those is something the person can act on, so say which one it was.
    private static func message(forStatus code: Int) -> String {
        switch code {
        case 401:
            return "Sign in to scan wine labels."
        case 413:
            return "That photo is too large. Try again with a closer shot of the label."
        case 429:
            return "You've hit the scan limit for now. Try again in a little while."
        case 503:
            return "Label scanning is temporarily unavailable. Please try again shortly."
        default:
            return "Label scanning unavailable (HTTP \(code))."
        }
    }
}
