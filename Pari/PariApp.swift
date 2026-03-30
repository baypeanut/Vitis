//
//  PariApp.swift
//  Pari
//
//  Created by Noah Ahmet Dericioglu on 1/25/26.
//

import SwiftUI

@main
struct PariApp: App {
    init() {
        _ = SupabaseManager.shared
        AnalyticsService.setup()
        URLCache.shared = URLCache(
            memoryCapacity: 30 * 1024 * 1024,   // 30 MB in-memory
            diskCapacity: 150 * 1024 * 1024,    // 150 MB on-disk
            diskPath: "pari_image_cache"
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // 1. Auth callbacks (Supabase magic link / OAuth)
                    Task {
                        let handled = await AuthStore.shared.handleIncomingURL(url)
                        if handled { return }
                        // 2. Password recovery deep link
                        if url.absoluteString.contains("auth/reset") {
                            AuthRecoveryState.shared.handleIncomingURL(url)
                            return
                        }
                        // 3. Universal Links / app routes (wine, profile)
                        _ = DeepLinkRouter.shared.handle(url)
                    }
                }
        }
    }
}
