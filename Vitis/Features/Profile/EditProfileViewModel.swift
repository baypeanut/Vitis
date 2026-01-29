//
//  EditProfileViewModel.swift
//  Vitis
//
//  Edit profile form: bio, taste snapshot, weekly goal, Instagram handle.
//

import Foundation

@MainActor
@Observable
final class EditProfileViewModel {
    var bio: String = ""
    var lovesId: String = "none"
    var avoidsId: String = "none"
    var moodId: String = "none"
    var weeklyGoalId: String = "none"
    var instagramHandleInput: String = ""
    /// New photo picked + cropped; uploaded on save.
    var avatarJpegData: Data?

    var isSaving = false
    var saveError: String?

    let bioLimit = 140

    var bioCount: Int { bio.count }
    var bioOverLimit: Bool { bio.count > bioLimit }

    func apply(profile: Profile) {
        bio = profile.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        lovesId = profile.tasteSnapshotLoves ?? "none"
        avoidsId = profile.tasteSnapshotAvoids ?? "none"
        moodId = profile.tasteSnapshotMood ?? "none"
        weeklyGoalId = profile.weeklyGoal ?? "none"
        let h = profile.instagramHandle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        instagramHandleInput = h.isEmpty ? "" : "@\(h)"
        avatarJpegData = nil
    }

    /// Normalize raw input to stored handle (no leading @).
    /// Accepts: "ahmet.derici", "@ahmet.derici", "instagram.com/ahmet.derici", "https://instagram.com/ahmet.derici/".
    static func normalizeInstagramHandle(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }
        let lower = s.lowercased()
        if lower.contains("instagram.com") {
            let urlString = s.hasPrefix("http") ? s : "https://\(s)"
            guard let url = URL(string: urlString),
                  let comp = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return s
            }
            let path = comp.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let last = path.split(separator: "/").last.map(String.init) ?? path
            if !last.isEmpty { s = last }
        }
        if s.hasPrefix("@") { s = String(s.dropFirst()) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Valid handle: empty allowed; if non-empty, ^[A-Za-z0-9._]{1,30}$.
    static func isValidInstagramHandle(_ handle: String) -> Bool {
        if handle.isEmpty { return true }
        guard let regex = try? NSRegularExpression(pattern: "^[A-Za-z0-9._]{1,30}$") else { return false }
        let range = NSRange(handle.startIndex..<handle.endIndex, in: handle) ?? NSRange(location: 0, length: 0)
        return regex.firstMatch(in: handle, range: range) != nil
    }

    func save(userId: UUID) async {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        let trimmedBio = String(bio.prefix(bioLimit)).trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = Self.normalizeInstagramHandle(instagramHandleInput)
        if !Self.isValidInstagramHandle(handle) {
            saveError = "Invalid Instagram username"
            isSaving = false
            return
        }
        do {
            var avatarURL: String?
            if let data = avatarJpegData {
                do {
                    avatarURL = try await AvatarStorageService.uploadAvatar(userId: userId, jpegData: data)
                } catch {
                    saveError = "Avatar upload failed: \(error.localizedDescription)"
                    isSaving = false
                    return
                }
            }
            do {
                try await AuthService.updateProfile(
                    userId: userId,
                    avatarURL: avatarURL,
                    bio: trimmedBio.isEmpty ? nil : trimmedBio,
                    instagramHandle: handle.isEmpty ? nil : handle,
                    tasteSnapshotLoves: lovesId == "none" ? nil : lovesId,
                    tasteSnapshotAvoids: avoidsId == "none" ? nil : avoidsId,
                    tasteSnapshotMood: moodId == "none" ? nil : moodId,
                    weeklyGoal: weeklyGoalId == "none" ? nil : weeklyGoalId
                )
            } catch {
                saveError = "Profile update failed: \(error.localizedDescription)"
                isSaving = false
                return
            }
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}
