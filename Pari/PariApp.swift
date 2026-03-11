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
                    Task {
                        let handled = await AuthStore.shared.handleIncomingURL(url)
                        if !handled {
                            AuthRecoveryState.shared.handleIncomingURL(url)
                        }
                    }
                }
        }
    }
}
