//
//  DevAccount.swift
//  Vitis
//
//  Mirrors dev_accounts table. Used by DevLoginService.
//

import Foundation

struct DevAccount: Sendable {
    let id: UUID
    let email: String?
    let phoneE164: String?
    let fullName: String?
    let username: String?
    let createdAt: Date?
}
