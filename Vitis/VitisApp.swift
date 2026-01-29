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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    AuthRecoveryState.shared.handleIncomingURL(url)
                }
        }
    }
}
