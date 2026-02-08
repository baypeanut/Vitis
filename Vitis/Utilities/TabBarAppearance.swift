//
//  TabBarAppearance.swift
//  Vitis
//
//  Applies semantic theme to UITabBar: opaque background, correct tints.
//

import SwiftUI
import UIKit

/// Configures UITabBar appearance using Theme semantic colors.
/// Call from RootView when main tabs are visible.
struct TabBarAppearanceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .onAppear { configure() }
            .onChange(of: colorScheme) { _, _ in configure() }
    }

    private func configure() {
        let appearance = UITabBarAppearance()
        if colorScheme == .dark {
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor(VitisTheme.tabBarBackground(for: colorScheme))
            appearance.shadowColor = .clear
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(VitisTheme.tabBarBackground(for: colorScheme))
            appearance.shadowColor = UIColor(VitisTheme.divider(for: colorScheme))
        }

        let accent = UIColor(VitisTheme.accentWine(for: colorScheme))
        let unselected = UIColor(VitisTheme.tabBarInactiveColor(for: colorScheme))

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = accent
        UITabBar.appearance().unselectedItemTintColor = unselected
    }
}

extension View {
    func tabBarTheme() -> some View {
        modifier(TabBarAppearanceModifier())
    }
}
