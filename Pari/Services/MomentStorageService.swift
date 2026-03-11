//
//  MomentStorageService.swift
//  Pari
//
//  Upload "wine night" photo for feed. Path: moment_images/{userId}/{uuid}.jpg
//

import Foundation
import Supabase

enum MomentStorageService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    private static let bucket = "moment_images"
    private static let contentType = "image/jpeg"

    /// Upload JPEG data. Returns public URL or throws.
    static func uploadMoment(userId: UUID, jpegData: Data) async throws -> String {
        let name = "\(userId.uuidString)/\(UUID().uuidString).jpg"
        _ = try await supabase.storage
            .from(bucket)
            .upload(
                name,
                data: jpegData,
                options: FileOptions(contentType: contentType, upsert: false)
            )
        let url = try supabase.storage.from(bucket).getPublicURL(path: name)
        return url.absoluteString
    }
}
