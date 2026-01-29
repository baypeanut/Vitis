//
//  CellarItem.swift
//  Vitis
//
//  Had | Wishlist cellar entry. Joins wines for display.
//

import Foundation

struct CellarItem: Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let wineId: UUID
    let status: CellarStatus
    let createdAt: Date
    let consumedAt: Date?
    let wine: Wine

    enum CellarStatus: String, Sendable {
        case had
        case wishlist
    }
}

extension CellarItem {
    /// Timestamp for list display: Had uses consumed_at else created_at; Wishlist uses created_at.
    var displayDate: Date {
        switch status {
        case .had: return consumedAt ?? createdAt
        case .wishlist: return createdAt
        }
    }

    /// Activity statement for display in profile recent activity
    func activityStatement(username: String) -> String {
        let producer = wine.producer
        let wineName = wine.vintage.map { "\($0) \(wine.name)" } ?? wine.name
        let fullName = "\(producer)'s \(wineName)"
        switch status {
        case .had:
            return "\(username) had \(fullName)."
        case .wishlist:
            return "\(username) wants \(fullName)."
        }
    }

    /// Statement parts for display (before, name, after). Name is highlighted.
    func statementParts(username: String) -> (before: String, name: String, after: String) {
        let s = activityStatement(username: username)
        guard let r = s.range(of: username) else { return (s, "", "") }
        return (String(s[..<r.lowerBound]), username, String(s[r.upperBound...]))
    }
}
