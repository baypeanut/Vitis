//
//  MuteService.swift
//  Vitis
//
//  Local mute list — stores muted user UUIDs in UserDefaults.
//  Posts from muted users are filtered out of the feed client-side.
//

import Foundation

enum MuteService {
    private static let key = "vitis_muted_user_ids"

    static func mutedUserIds() -> Set<UUID> {
        let strings = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    static func isMuted(_ userId: UUID) -> Bool {
        mutedUserIds().contains(userId)
    }

    static func mute(_ userId: UUID) {
        var current = mutedUserIds()
        current.insert(userId)
        save(current)
    }

    static func unmute(_ userId: UUID) {
        var current = mutedUserIds()
        current.remove(userId)
        save(current)
    }

    static func toggle(_ userId: UUID) {
        isMuted(userId) ? unmute(userId) : mute(userId)
    }

    private static func save(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: key)
        NotificationCenter.default.post(name: .vitisMuteListChanged, object: nil)
    }
}

extension Notification.Name {
    static let vitisMuteListChanged = Notification.Name("vitisMuteListChanged")
}
