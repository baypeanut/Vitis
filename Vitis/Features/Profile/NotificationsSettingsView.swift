//
//  NotificationsSettingsView.swift
//  Pari
//
//  Notifications: system permission status + in-app notification type preferences.
//

import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var authStatusText = "-"

    @AppStorage("notify_likes") private var notifyLikes = true
    @AppStorage("notify_comments") private var notifyComments = true
    @AppStorage("notify_follows") private var notifyFollows = true

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                        .font(PariTheme.uiFont(size: 16))
                    Spacer()
                    Text(authStatusText)
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                }
                .padding(.vertical, 4)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Open system settings")
                            .font(PariTheme.uiFont(size: 16))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 14))
                            .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text("System")
                    .font(PariTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            }

            Section {
                Toggle(isOn: $notifyLikes) {
                    Text("Likes")
                        .font(PariTheme.uiFont(size: 16))
                }
                .tint(PariTheme.accent(for: colorScheme))
                Toggle(isOn: $notifyComments) {
                    Text("Comments")
                        .font(PariTheme.uiFont(size: 16))
                }
                .tint(PariTheme.accent(for: colorScheme))
                Toggle(isOn: $notifyFollows) {
                    Text("New followers")
                        .font(PariTheme.uiFont(size: 16))
                }
                .tint(PariTheme.accent(for: colorScheme))
            } header: {
                Text("Preferences")
                    .font(PariTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            } footer: {
                Text("Choose which activity appears in your notifications tab.")
                    .font(PariTheme.uiFont(size: 12))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PariTheme.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let status = await NotificationStatusHelper.fetchStatusText()
            authStatusText = status
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                authStatusText = await NotificationStatusHelper.fetchStatusText()
            }
        }
    }
}

enum NotificationStatusHelper {
    static func fetchStatusText() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "On"
        case .denied:
            return "Off"
        case .notDetermined:
            return "Not set"
        @unknown default:
            return "On"
        }
    }
}
