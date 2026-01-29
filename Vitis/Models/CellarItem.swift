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
}
