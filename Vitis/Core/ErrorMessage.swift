//
//  ErrorMessage.swift
//  Vitis
//
//  Minimal user-facing error messages. English only. Do not clear UI state on error.
//

import Foundation

enum ErrorMessage {
    static let networkTimeout = "Something went wrong. Please try again."
    static let noConnection = "No internet connection."
    static let unauthorized = "Please sign in to continue."
    static let unknown = "Something went wrong. Please try again."

    /// Maps common errors to consistent user-facing strings. Does NOT leak PII.
    static func userFacing(for error: Error) -> String {
        if (error as NSError).domain == NSURLErrorDomain {
            switch (error as NSError).code {
            case NSURLErrorTimedOut: return networkTimeout
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost: return noConnection
            default: break
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return networkTimeout
            case .notConnectedToInternet, .networkConnectionLost: return noConnection
            case .cancelled: return unknown
            default: break
            }
        }
        let msg = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
        let lower = msg.lowercased()
        if lower.contains("timed out") || lower.contains("timeout") { return networkTimeout }
        if lower.contains("internet") || lower.contains("network") || lower.contains("offline") { return noConnection }
        if lower.contains("unauthorized") || lower.contains("401") || lower.contains("session") { return unauthorized }
        return unknown
    }
}
