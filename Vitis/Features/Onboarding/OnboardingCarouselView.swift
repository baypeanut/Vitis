//
//  OnboardingCarouselView.swift
//  Pari
//
//  2-3 screen value prop carousel: Log wines, Discover via friends, Build palate.
//  Final CTA: Add your first tasting -> opens AddWineSheet.
//

import SwiftUI

struct OnboardingCarouselView: View {
    @Binding var hasSeenCarousel: Bool
    var onComplete: () -> Void
    var onAddFirstTasting: () -> Void

    @State private var page = 0
    private let pages: [(title: String, subtitle: String, icon: String)] = [
        ("Log wines", "Track what you taste. Rate, note, and remember.", "wineglass.fill"),
        ("Discover via friends", "See what others are drinking. Cheers and comment.", "person.2.fill"),
        ("Build palate", "Understand your preferences. Grapes, regions, styles.", "chart.bar.fill")
    ]

    var body: some View {
        ZStack {
            PariTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Skip") {
                            hasSeenCarousel = true
                            onComplete()
                        }
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.secondaryText)
                        .padding(.trailing, 24)
                        .padding(.top, 12)
                    }
                }
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
                        pageContent(title: p.title, subtitle: p.subtitle, icon: p.icon)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)
                pageIndicator
                Spacer(minLength: 24)
                PrimaryButton(
                    page == pages.count - 1 ? "Add your first tasting" : "Continue",
                    enabled: true
                ) {
                    if page == pages.count - 1 {
                        hasSeenCarousel = true
                        onAddFirstTasting()
                    } else {
                        page += 1
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func pageContent(title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 32) {
            Spacer(minLength: 60)
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(PariTheme.accent)
            VStack(spacing: 12) {
                Text(title)
                    .font(PariTheme.uiFont(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(PariTheme.uiFont(size: 16))
                    .foregroundStyle(PariTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 24)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Circle()
                    .fill(i == page ? PariTheme.accent : Color(white: 0.85))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.bottom, 24)
    }
}
