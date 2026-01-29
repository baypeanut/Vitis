//
//  ContentView.swift
//  Vitis
//
//  Created by Noah Ahmet Dericioglu on 1/25/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DuelView()
                .tabItem { Label("Duel", systemImage: "wineglass") }
            CellarView()
                .tabItem { Label("Cellar", systemImage: "square.stack") }
            SocialView()
                .tabItem { Label("Social", systemImage: "person.2") }
        }
        .tint(VitisTheme.accent)
    }
}

#Preview {
    ContentView()
}
