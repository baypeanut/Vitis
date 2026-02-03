//
//  VitisApp.swift
//  Vitis
//
//  Created by Noah Ahmet Dericioglu on 1/25/26.
//

import SwiftUI

@main
struct VitisApp: App {
    init() {
        _ = SupabaseManager.shared
        AnalyticsService.setup()
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
