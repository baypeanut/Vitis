//
//  SocialDiscoveryService.swift
//  Pari
//
//  Social discovery backend: global search + suggestions from contacts and Taste Twins.
//  Privacy-first: contacts are normalized to E.164 and SHA-256 hashed on-device; only hashes are sent.
//

import Foundation
import Supabase
import CryptoKit
import Contacts

struct DiscoveryUser: Identifiable, Sendable {
    enum Source: Sendable {
        case search
        case contacts
        case tasteTwin
    }

    let id: UUID
    let username: String
    let fullName: String?
    let avatarURL: String?
    let similarity: TasteSimilarity?
    let source: Source

    var displayName: String {
        if let full = fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
            return full
        }
        return username
    }
}

struct InviteContact: Identifiable, Sendable {
    let id = UUID()
    let displayName: String
    let phoneE164: String
}

enum SocialDiscoveryService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    // MARK: - Phone hashing

    private static func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func phoneHash(forE164 phone: String) -> String? {
        // Very small guard; we expect Supabase Auth to already store E.164.
        guard PhoneNumberFormatter.validateE164(phone) else { return nil }
        return sha256Hex(phone)
    }

    /// Best-effort sync: hash the current user's phone (if present) into profiles.phone_hash.
    static func syncOwnPhoneHashIfPossible() async {
        guard let snapshot = await AuthService.currentUserSnapshot(),
              let phone = snapshot.phone,
              PhoneNumberFormatter.validateE164(phone),
              let hash = phoneHash(forE164: phone)
        else { return }

        struct Payload: Encodable { let phone_hash: String }
        do {
            try await supabase
                .from("profiles")
                .update(Payload(phone_hash: hash))
                .eq("id", value: snapshot.userId)
                .execute()
        } catch {
            #if DEBUG
            print("[SocialDiscoveryService] syncOwnPhoneHashIfPossible error: \(error)")
            #endif
        }
    }

    // MARK: - Contacts-based suggestions

    /// Fetch Pari users that match the user's contacts by phone hash.
    /// Returns (matches, inviteCandidates) — inviteCandidates are normalized contacts with no Pari profile.
    static func fetchContactsSuggestions(defaultCountry: Country) async -> ([DiscoveryUser], [InviteContact]) {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [CNContactPhoneNumbersKey as CNKeyDescriptor,
                                       CNContactGivenNameKey as CNKeyDescriptor,
                                       CNContactFamilyNameKey as CNKeyDescriptor]
        do {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            if status == .notDetermined {
                try await store.requestAccess(for: .contacts)
            } else if status != .authorized {
                return ([], [])
            }
        } catch {
            return ([], [])
        }

        var allE164: [String] = []
        var nameByPhone: [String: String] = [:]

        do {
            let request = CNContactFetchRequest(keysToFetch: keys)
            try store.enumerateContacts(with: request) { contact, _ in
                let displayName = [contact.givenName, contact.familyName]
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                for number in contact.phoneNumbers {
                    let raw = number.value.stringValue
                    if let e164 = PhoneNumberFormatter.toE164(country: defaultCountry, rawInput: raw) {
                        allE164.append(e164)
                        if !displayName.isEmpty {
                            nameByPhone[e164] = displayName
                        }
                    }
                }
            }
        } catch {
            #if DEBUG
            print("[SocialDiscoveryService] enumerateContacts error: \(error)")
            #endif
            return ([], [])
        }

        guard !allE164.isEmpty else { return ([], []) }

        // Hash all phones and build lookup from hash → original.
        var hashToPhone: [String: String] = [:]
        for p in allE164 {
            if let h = phoneHash(forE164: p) {
                hashToPhone[h] = p
            }
        }
        let hashes = Array(hashToPhone.keys)
        guard !hashes.isEmpty else { return ([], []) }

        struct Row: Decodable {
            let id: UUID
            let username: String
            let full_name: String?
            let avatar_url: String?
            let phone_hash: String?
        }

        var matched: [DiscoveryUser] = []
        var seenPhones: Set<String> = []

        do {
            let rows: [Row] = try await supabase
                .from("profiles")
                .select("id, username, full_name, avatar_url, phone_hash")
                .in("phone_hash", values: hashes)
                .execute()
                .value

            for r in rows {
                guard let ph = r.phone_hash, let phone = hashToPhone[ph] else { continue }
                seenPhones.insert(phone)
                matched.append(
                    DiscoveryUser(
                        id: r.id,
                        username: r.username,
                        fullName: r.full_name,
                        avatarURL: r.avatar_url,
                        similarity: nil,
                        source: .contacts
                    )
                )
            }
        } catch {
            #if DEBUG
            print("[SocialDiscoveryService] fetchContactsSuggestions query error: \(error)")
            #endif
        }

        // Remaining phones become invite candidates.
        var invites: [InviteContact] = []
        for p in allE164 where !seenPhones.contains(p) {
            let name = nameByPhone[p] ?? ""
            invites.append(InviteContact(displayName: name.isEmpty ? p : name, phoneE164: p))
        }

        return (matched, invites)
    }

    // MARK: - Taste Twin suggestions

    static func fetchTasteTwinSuggestions() async -> [DiscoveryUser] {
        guard let uid = await AuthService.currentUserId() else { return [] }
        let twins = await TasteSimilarityService.fetchTasteTwins(userId: uid, limit: 20)
        return twins.map { twin in
            DiscoveryUser(
                id: twin.id,
                username: twin.username,
                fullName: twin.fullName,
                avatarURL: twin.avatarURL,
                similarity: twin.similarity,
                source: .tasteTwin
            )
        }
    }

    // MARK: - Global search

    static func searchProfiles(query: String, limit: Int = 30) async -> [DiscoveryUser] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        struct Row: Decodable {
            let id: UUID
            let username: String
            let full_name: String?
            let avatar_url: String?
        }

        do {
            // Search by username OR full_name via two ilike queries.
            let rows: [Row] = try await supabase
                .from("profiles")
                .select("id, username, full_name, avatar_url")
                .or("username.ilike.%\(trimmed)%,full_name.ilike.%\(trimmed)%")
                .limit(limit)
                .execute()
                .value

            var results: [DiscoveryUser] = []
            // Enrich with similarity badges if available.
            let currentId = await AuthService.currentUserId()

            if let uid = currentId {
                for r in rows {
                    // Do not surface the current user's own profile in discovery search.
                    guard r.id != uid else { continue }
                    var similarity: TasteSimilarity?
                    if r.id != uid {
                        similarity = await TasteSimilarityService.fetchSimilarity(targetUserId: r.id)
                    }
                    results.append(
                        DiscoveryUser(
                            id: r.id,
                            username: r.username,
                            fullName: r.full_name,
                            avatarURL: r.avatar_url,
                            similarity: similarity,
                            source: .search
                        )
                    )
                }
            } else {
                results = rows.map {
                    DiscoveryUser(
                        id: $0.id,
                        username: $0.username,
                        fullName: $0.full_name,
                        avatarURL: $0.avatar_url,
                        similarity: nil,
                        source: .search
                    )
                }
            }

            return results
        } catch {
            #if DEBUG
            print("[SocialDiscoveryService] searchProfiles error: \(error)")
            #endif
            return []
        }
    }
}

