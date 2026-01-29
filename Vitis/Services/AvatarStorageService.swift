//
//  AvatarStorageService.swift
//  Vitis
//
//  Upload avatar to Supabase storage bucket "avatars". Path: {userId}/avatar.jpg
//

import Foundation
import Supabase

enum AvatarStorageService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    private static let bucket = "avatars"
    private static let filename = "avatar.jpg"
    private static let contentType = "image/jpeg"

    /// Upload JPEG data to avatars/{userId}/avatar.jpg. Returns public URL or throws.
    static func uploadAvatar(userId: UUID, jpegData: Data) async throws -> String {
        let path = "\(userId.uuidString)/\(filename)"
        _ = try await supabase.storage
            .from(bucket)
            .upload(
                path,
                data: jpegData,
                options: FileOptions(contentType: contentType, upsert: true)
            )
        let url = try supabase.storage.from(bucket).getPublicURL(path: path)
        return url.absoluteString
    }
}
