//
//  TermsOfServiceView.swift
//  Vitis
//
//  In-app Terms of Service. Last updated March 2025.
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                legalHeader(
                    title: "Terms of Service",
                    effectiveDate: "Effective: March 1, 2025"
                )

                section("1. About Vitis") {
                    body("Vitis is a social wine journal. We help you log tastings, discover wines through friends, and build your personal taste profile. Vitis is not a wine retailer, marketplace, or alcohol delivery service. We do not sell, ship, or facilitate the purchase of alcohol.")
                }

                section("2. Eligibility") {
                    body("You must be at least 21 years old (or the legal drinking age in your country, whichever is higher) to create an account. By registering, you confirm that you meet this requirement. We may terminate accounts that do not comply.")
                    body("Vitis is available globally where Apple distributes apps. Local laws regarding alcohol and social platforms vary. You are responsible for compliance with laws in your jurisdiction.")
                }

                section("3. Your Account") {
                    body("You are responsible for maintaining the confidentiality of your account credentials. Notify us immediately if you suspect unauthorized access.")
                    body("You may not create accounts on behalf of others, use automated tools to create accounts, or impersonate any person or entity.")
                }

                section("4. User-Generated Content") {
                    body("\"Content\" means anything you post: tasting notes, ratings, comments, photos, wine names, and your public profile.")
                    body("You retain ownership of your Content. By posting, you grant Vitis a worldwide, royalty-free, non-exclusive license to store, display, and distribute your Content within the app and for promotional purposes (e.g., App Store screenshots).")
                    body("You agree not to post Content that: (a) is false, defamatory, or misleading; (b) violates third-party intellectual property or privacy rights; (c) is sexually explicit, violent, or hateful; (d) promotes illegal activity or alcohol to minors; (e) contains spam or commercial solicitation.")
                    body("We reserve the right to remove Content that violates these Terms or that we deem harmful to our community, without prior notice.")
                }

                section("5. Acceptable Use") {
                    body("You agree not to: (a) scrape, crawl, or extract data from Vitis; (b) reverse-engineer or decompile the app; (c) use Vitis to harass, threaten, or harm other users; (d) attempt to gain unauthorized access to our systems; (e) interfere with the performance of the service.")
                }

                section("6. Taste Twin & Algorithmic Features") {
                    body("Taste Twin and similar features use your rating history to compute taste similarity with other users. These are statistical suggestions, not endorsements or guarantees of compatibility. Algorithm results may change as more data is collected.")
                }

                section("7. Intellectual Property") {
                    body("The Vitis name, logo, design, and proprietary algorithms are owned by Vitis and protected by applicable intellectual property law. You may not use our trademarks without written permission.")
                    body("Wine names, producer names, labels, and vintage information are the property of their respective owners. We display this information for informational and personal logging purposes only.")
                }

                section("8. Disclaimers") {
                    body("Vitis is provided \"as is\" and \"as available.\" We do not warrant that the service will be uninterrupted, error-free, or free from viruses.")
                    body("Wine ratings and tasting notes are personal opinions of individual users. Vitis does not endorse any wine, producer, or tasting note.")
                    body("Alcohol consumption carries health risks. Nothing in Vitis constitutes medical or dietary advice. Drink responsibly.")
                }

                section("9. Limitation of Liability") {
                    body("To the maximum extent permitted by applicable law, Vitis and its affiliates shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the service.")
                    body("In jurisdictions that do not allow the exclusion of certain warranties or limitation of liability, our liability is limited to the maximum extent permitted by law.")
                }

                section("10. Termination") {
                    body("You may delete your account at any time in Settings → Delete Account. We will delete your personal data as described in our Privacy Policy.")
                    body("We may suspend or terminate your account if you violate these Terms, engage in fraudulent activity, or if we discontinue the service.")
                }

                section("11. Changes to These Terms") {
                    body("We may update these Terms from time to time. We will notify you of material changes via in-app notice or email. Continued use of Vitis after the effective date constitutes acceptance of the updated Terms.")
                }

                section("12. Governing Law & Disputes") {
                    body("These Terms are governed by the laws of the Republic of Turkey, without regard to conflict-of-law principles. If you are located in the European Union, you retain the benefit of any mandatory consumer protection provisions applicable in your country.")
                    body("We encourage you to contact us to resolve disputes informally before pursuing formal proceedings. For EU users, the European Commission's Online Dispute Resolution platform is available at ec.europa.eu/consumers/odr.")
                }

                section("13. Contact") {
                    body("Questions about these Terms? Reach us at support@vitis.app or through Settings → Contact Concierge.")
                }

                Divider()
                    .padding(.top, 8)

                Text("These Terms were last updated March 1, 2025.")
                    .font(VitisTheme.uiFont(size: 12))
                    .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .background(VitisTheme.backgroundPrimary(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func legalHeader(title: String, effectiveDate: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title2, design: .serif, weight: .regular))
                .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
            Text(effectiveDate)
                .font(VitisTheme.uiFont(size: 13))
                .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(VitisTheme.uiFont(size: 15, weight: .semibold))
                .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
            content()
        }
    }

    private func body(_ text: String) -> some View {
        Text(text)
            .font(VitisTheme.uiFont(size: 15))
            .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }
}

#Preview {
    NavigationStack {
        TermsOfServiceView()
    }
}
