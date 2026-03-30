//
//  DeepLinkRouter.swift
//  Pari
//
//  Parses Universal Link and custom-scheme URLs into app routes.
//

import Foundation

@MainActor
@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    enum Route: Equatable {
        case wine(id: UUID)
        case profile(username: String)
    }

    /// Set by PariApp on .onOpenURL; observed by RootView to navigate.
    var pendingRoute: Route?

    /// Returns true if the URL was handled as a deep link route.
    func handle(_ url: URL) -> Bool {
        // Universal Links: https://pari.app/wine/{id}, https://pari.app/@{username}
        // Custom scheme:   pari://wine/{id},          pari://profile/{username}
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if let first = pathComponents.first {
            switch first {
            case "wine":
                if let idString = pathComponents.dropFirst().first,
                   let wineId = UUID(uuidString: idString) {
                    pendingRoute = .wine(id: wineId)
                    return true
                }
            default:
                // @username format in path: /@ is split into ["@username"] or ["@", "username"]
                if first.hasPrefix("@") {
                    let username = String(first.dropFirst())
                    if !username.isEmpty {
                        pendingRoute = .profile(username: username)
                        return true
                    }
                }
            }
        }

        // Check host for custom scheme: pari://wine/{id}, pari://profile/{username}
        if url.scheme == "pari" {
            let host = url.host ?? ""
            switch host {
            case "wine":
                if let idString = pathComponents.first, let wineId = UUID(uuidString: idString) {
                    pendingRoute = .wine(id: wineId)
                    return true
                }
            case "profile":
                if let username = pathComponents.first, !username.isEmpty {
                    pendingRoute = .profile(username: username)
                    return true
                }
            default:
                break
            }
        }

        return false
    }

    func consumeRoute() -> Route? {
        defer { pendingRoute = nil }
        return pendingRoute
    }
}
