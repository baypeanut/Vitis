import SwiftUI
import MessageUI

struct UserDiscoveryView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var isSearching = false
    @State private var searchResults: [DiscoveryUser] = []

    @State private var contactsMatches: [DiscoveryUser] = []
    @State private var twinSuggestions: [DiscoveryUser] = []
    @State private var inviteContacts: [InviteContact] = []
    @State private var isLoadingSuggestions = true
    @State private var inviteTarget: InviteContact?

    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if showSuggestions {
                    suggestionsSection
                } else if showSearchResults {
                    searchResultsSection
                }
            }
            .padding(.top, 16)
        }
        .background(VitisTheme.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find connoisseurs…")
        .onChange(of: searchText) { _, newValue in
            debouncedSearch(text: newValue)
        }
        .task {
            await SocialDiscoveryService.syncOwnPhoneHashIfPossible()
            await loadSuggestions()
        }
        .sheet(item: $inviteTarget) { target in
            MessageInviteView(phoneE164: target.phoneE164)
        }
    }

    private var showSuggestions: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showSearchResults: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Sections

    @ViewBuilder
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Suggested for you")
                    .font(VitisTheme.uiFont(size: 14, weight: .semibold))
                    .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                Spacer()
                if isLoadingSuggestions {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(VitisTheme.accent(for: colorScheme))
                }
            }
            .padding(.horizontal, 16)

            if !contactsMatches.isEmpty {
                sectionHeader("From your contacts")
                ForEach(contactsMatches) { user in
                    discoveryRow(user)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }

            if !twinSuggestions.isEmpty {
                sectionHeader("Because you have similar palates")
                ForEach(twinSuggestions) { user in
                    discoveryRow(user)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.bottom, 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: contactsMatches.count + twinSuggestions.count)
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(VitisTheme.accent(for: colorScheme))
                    Text("Searching…")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, 16)
            }

            if !searchResults.isEmpty {
                ForEach(searchResults) { user in
                    discoveryRow(user)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            } else if !isSearching {
                searchEmptyState
                    .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: searchResults.count)
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("No connoisseurs found")
                .font(VitisTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
            Text("Try a different name or keep building your cellar\nand we’ll suggest people who match your taste.")
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var searchEmptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("No connoisseurs found with this name.")
                .font(VitisTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
            Text("Try a different spelling or discover people from your suggestions.")
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(VitisTheme.uiFont(size: 13, weight: .semibold))
            .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            .padding(.top, 8)
            .padding(.horizontal, 16)
    }

    // MARK: - Row

    private func discoveryRow(_ user: DiscoveryUser) -> some View {
        NavigationLink {
            UserProfileViewContent(userId: user.id)
        } label: {
            HStack(spacing: 12) {
                avatarView(urlString: user.avatarURL, name: user.displayName)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                    Text("@\(user.username)")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                }
                Spacer()
                if let sim = user.similarity {
                    TasteTwinBadge(similarity: sim)
                } else if user.source == .contacts {
                    Text("From contacts")
                        .font(VitisTheme.uiFont(size: 11))
                        .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            UISelectionFeedbackGenerator().selectionChanged()
        })
    }

    private func avatarView(urlString: String?, name: String) -> some View {
        let size: CGFloat = 40
        return CachedAsyncImage(
            url: urlString.flatMap(URL.init(string:)),
            content: { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            },
            placeholder: {
                Circle()
                    .fill(VitisTheme.placeholderBackground(for: colorScheme))
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(VitisTheme.uiFont(size: 16, weight: .medium))
                            .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    )
            }
        )
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(VitisTheme.borderSubtle(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Data loading

    private func loadSuggestions() async {
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }
        async let contactsTask = SocialDiscoveryService.fetchContactsSuggestions(defaultCountry: CountriesStore.shared.defaultCountry)
        async let twinsTask = SocialDiscoveryService.fetchTasteTwinSuggestions()

        let (contacts, invites) = await contactsTask
        let twins = await twinsTask

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.25)) {
                contactsMatches = contacts
                inviteContacts = invites
                twinSuggestions = twins
            }
        }
    }

    private func debouncedSearch(text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation(.easeInOut(duration: 0.2)) {
                searchResults = []
                isSearching = false
            }
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = await SocialDiscoveryService.searchProfiles(query: trimmed)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.searchResults = results
                    self.isSearching = false
                }
            }
        }
    }
}

// MARK: - Message Invite

private struct MessageInviteView: UIViewControllerRepresentable {
    let phoneE164: String

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        if MFMessageComposeViewController.canSendText() {
            vc.recipients = [phoneE164]
            vc.body = "I started documenting my cellar on Vitis. You should join the club. [App Store Link]"
            vc.messageComposeDelegate = context.coordinator
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }
    }
}


