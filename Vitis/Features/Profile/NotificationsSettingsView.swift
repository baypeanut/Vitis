//
//  NotificationsSettingsView.swift
//  Vitis
//
//  Notifications: status + deep link to system settings.
//

import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var authStatusText = "-"

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                        .font(VitisTheme.uiFont(size: 16))
                    Spacer()
                    Text(authStatusText)
                        .font(VitisTheme.uiFont(size: 14))
                        .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                }
                .padding(.vertical, 4)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Open system settings")
                            .font(VitisTheme.uiFont(size: 16))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 14))
                            .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VitisTheme.background(for: colorScheme).ignoresSafeArea())
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
