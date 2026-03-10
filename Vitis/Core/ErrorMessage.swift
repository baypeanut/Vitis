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
    /// Cross-checks NWPathMonitor before claiming "No internet connection" to avoid
    /// false positives from transient iOS socket errors on app foreground / WiFi handoff.
    static func userFacing(for error: Error) -> String {
        let nsErr = error as NSError
        if nsErr.domain == NSURLErrorDomain {
            switch nsErr.code {
            case NSURLErrorTimedOut: return networkTimeout
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return NetworkMonitor.shared.isConnected ? unknown : noConnection
            default: break
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return networkTimeout
            case .notConnectedToInternet, .networkConnectionLost:
                return NetworkMonitor.shared.isConnected ? unknown : noConnection
            case .cancelled: return unknown
            default: break
            }
        }
        let msg = nsErr.userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
        let lower = msg.lowercased()
        if lower.contains("timed out") || lower.contains("timeout") { return networkTimeout }
        if lower.contains("internet") || lower.contains("offline") {
            return NetworkMonitor.shared.isConnected ? unknown : noConnection
        }
        if lower.contains("unauthorized") || lower.contains("401") || lower.contains("session") { return unauthorized }
        return unknown
    }
}
