//
//  CachedAsyncImage.swift
//  Pari
//
//  Drop-in AsyncImage replacement with URLCache disk caching.
//  Avoids repeated network fetches for avatars, wine labels, etc.
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let img = image {
                content(Image(uiImage: img))
            } else {
                placeholder()
                    .onAppear { load() }
            }
        }
    }

    private func load() {
        guard !isLoading, let url else { return }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let img = UIImage(data: cached.data) {
            image = img
            return
        }
        isLoading = true
        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { isLoading = false }
            guard let data, let img = UIImage(data: data), let response else { return }
            URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            DispatchQueue.main.async { image = img }
        }.resume()
    }
}
