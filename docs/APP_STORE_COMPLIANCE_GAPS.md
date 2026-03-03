# App Store Compliance: Vitis vs Current Requirements

Cross-check of **current App Store Review Guidelines** (as of March 2026) with the Vitis codebase. Items below are **gaps or risks**—things that do not yet satisfy the requirement or need verification outside the app.

**Implemented in code (March 2026):** Contact Support, Profanity Filter, Responsible Drinking link, Age Gate Hardening (is_age_verified in profiles), Privacy Manifest (.xcprivacy). Remaining items are website/App Store Connect checks or optional.

---

## 0. High-Risk Items (Instant Rejection)

Bu madde 2026 başı Apple denetimlerinde **Red (Rejection)** riski taşır. (Sign in with Apple yalnızca üçüncü taraf sosyal giriş kullanıldığında zorunludur; Vitis şu an yalnızca telefon OTP kullandığı için listeden çıkarıldı.)

### Privacy Manifests & Required Reason APIs (Guideline 5.1.1)

| Requirement | Vitis status | Gap? |
|-------------|--------------|------|
| **Privacy Manifest** (`.xcprivacy`) zorunluluğu (2024 sonu; 2025–2026’da denetim sıkı). Kullanılan her SDK (Supabase dahil) için hangi verinin neden toplandığı bildirilmeli. | Projede **hiç `.xcprivacy` dosyası yok**. | **Evet** — Ana uygulama ve kullanılan tüm SDK’lar (Supabase, PostHog, vb.) için **Privacy Manifest** eklenmeli. Eksik olmamalı. |

---

## 1. Safety

### 1.2 User-Generated Content (UGC)

Apps with UGC must include:

| Requirement | Vitis status | Gap? |
|-------------|--------------|------|
| **Published contact information** so users can easily reach you | No in-app support/contact link or email; only Privacy Policy / Terms links. Contact may exist on vitis.app or in App Store Connect. | **Yes** — Add an easy way to contact you **in the app** (e.g. “Support” or “Contact us” in Settings linking to a support page or mailto), or confirm Support URL is set in App Store Connect and that the linked page is clearly reachable. |
| **Ability to block abusive users** | Implemented: `BlockService`, block/unblock in `UserProfileView`, blocks reflected in feed. | No |
| **Mechanism to report offensive content** and timely responses | Implemented: `ReportService`, `ReportSheetView` for posts, comments, and profiles. | No (operational “timely responses” is process, not code) |
| **Method for filtering objectionable material** from being posted | No client- or server-side filtering of objectionable content (e.g. profanity filter, moderation layer) before content is posted. | **Yes** — Consider adding a **filtering mechanism** (e.g. profanity/blocklist filter or moderation API) so objectionable material can be prevented or limited before posting, per guideline 1.2. |

### 1.5 Developer Information / Support

| Requirement | Vitis status | Gap? |
|-------------|--------------|------|
| App and **Support URL** must include an **easy way to contact you** | No “Support” or “Contact” entry in app (e.g. in Profile → Settings). Support URL is configured in App Store Connect (not visible in code). | **Yes** — Add a **Support / Contact** entry in Settings (and/or in Legal section) that opens a support URL or mailto. Ensure the **Support URL** field in App Store Connect is set and points to a page with clear contact info. |

### 1.4+ Alcohol / Physical Harm (in-app behavior)

| Requirement | Vitis status | Gap? |
|-------------|--------------|------|
| Age verification before use (alcohol-related app) | Implemented: `AgeGateView` (DOB, 18+), shown before main app; result stored in UserDefaults. | Partial — See note below. |
| Drink responsibly / alcohol disclaimer | Implemented: `DrinkResponsiblyView` after age gate; also “Drink Responsibly” in Settings → Legal. | No |
| “Help is available” for alcohol support | `DrinkResponsiblyView` text says “help is available” but **no link** (e.g. SAMHSA, local hotline). | **Yes** — Add a **tappable link** to a responsible-drinking / crisis resource (e.g. SAMHSA or regional equivalent) in `DrinkResponsiblyView` (and optionally in Settings “Drink Responsibly”). |

**Age gate note:** Verification is **one-time** and stored in UserDefaults, so it can be reset by reinstalling. Guidelines don’t explicitly require re-verification every launch; if Review or legal advice asks for stronger assurance, consider re-prompting on reinstall or using a more persistent/account-based check.

---

## 2. Performance & Metadata

### 2.2 / 2.3 Completeness and Accurate Metadata

| Requirement | Vitis status | Gap? |
|-------------|--------------|------|
| **Privacy policy link** in App Store Connect metadata | Cannot be verified in code; must be set in App Store Connect. | **Verify** in App Store Connect that the **Privacy Policy URL** field is set (e.g. `https://vitis.app/privacy`). |
| **Privacy policy link** within the app, easily accessible | Implemented: Profile → Settings → Legal → “Privacy Policy” opens `AppConstants.URLs.privacyPolicy`. | No |
| All metadata and URLs final (no placeholders) | App uses live URLs for privacy and terms. | No (assuming vitis.app pages are live) |

---

## 3. Legal & Privacy (Guideline 5.1)

### 5.1.1 Privacy Policy

| Requirement | Vitis status | Gap? |
|-------------|--------------|------|
| Privacy policy **in App Store Connect** and **in app** | In app: yes. App Store Connect: must be set manually. | **Verify** App Store Connect. |
| Policy must **explicitly** state: (1) data collected and how, (2) uses of data, (3) third parties and same level of protection, (4) **data retention/deletion** and how user can **revoke consent / request deletion** | Policy content lives at vitis.app/privacy; not verifiable in repo. | **Verify** the hosted privacy policy includes all four elements above; ensure **account deletion** (and data deletion) is clearly described and that the in-app “Delete Account” flow matches the policy. |

### 5.1.1 & Account Deletion

| Requirement | Vitis status | Gap? |
|-------------|--------------|------|
| User can **request deletion** of their data / revoke consent | Implemented: Profile → Settings → “Delete Account” → `DeleteAccountView` with confirmation and OTP; `AuthService.deleteAccount()` and backend cascade. | No |
| Clear path to delete account | Implemented: obvious “Delete Account” in Settings with confirmation and explanation. | No |

---

## 4. Data Security & Permissions

### Info.plist usage descriptions

| Requirement | Vitis status | Gap? |
|-------------|--------------|------|
| **Photo Library** usage description | Present: `NSPhotoLibraryUsageDescription` (profile picture). | No |
| **Camera** usage description | App uses **PhotosPicker** (library only); no `NSCameraUsageDescription`. If you add direct camera capture later, add `NSCameraUsageDescription`. | No gap **unless** you introduce camera capture. |

---

## 5. Age Rating (App Store Connect)

| Requirement | Vitis status | Gap? |
|-------------|--------------|------|
| **Age rating** for alcohol (e.g. 17+ or 18+ depending on storefront) | Age rating is set in App Store Connect, not in code. In-app age gate (18+) is present. | **Verify** in App Store Connect that the app’s **age rating** matches alcohol-related content (e.g. 17+ or 18+ per current questionnaire). By Jan 31, 2026, new rating system (4+, 9+, 13+, 16+, 18+) applies; ensure questionnaire is completed. |

---

## 6. Summary: What Doesn’t Satisfy (or Must Be Verified) Yet

1. **UGC – Contact information**  
   No in-app support/contact. Add a Support or Contact entry in Settings (and ensure Support URL in App Store Connect).

2. **UGC – Filtering objectionable material**  
   No pre-post filtering (e.g. profanity/moderation). Add a filtering mechanism so objectionable content can be limited before posting.

3. **Support URL / Developer contact**  
   Add in-app way to contact you (Support/Contact) and confirm Support URL is set and correct in App Store Connect.

4. **Drink Responsibly – “Help is available”**  
   Add a tappable link to a responsible-drinking or crisis resource in `DrinkResponsiblyView` (and optionally in Settings “Drink Responsibly”).

5. **Privacy policy – App Store Connect**  
   Verify the Privacy Policy URL is set in App Store Connect and matches the in-app link.

6. **Privacy policy – Content**  
   Verify the policy at vitis.app/privacy explicitly covers: data collected and how, uses, third parties and protection, retention/deletion, and how to revoke consent/request deletion; and that it matches the in-app Delete Account flow.

7. **Age rating**  
   Verify in App Store Connect that age rating reflects alcohol content and that the new age-rating questionnaire (by Jan 31, 2026) is completed.

8. **Age gate (optional hardening)**  
   Age is stored only in UserDefaults (one-time, resettable by reinstall). If you need to satisfy stricter review or legal expectations, consider re-verification on reinstall or a more persistent/account-based check.

9. **Privacy Manifests (Guideline 5.1.1)**  
   No `.xcprivacy` files in the project. Required since May 2024; enforcement is stricter in 2025–2026. Add Privacy Manifests for the app and for every SDK (e.g. Supabase) that collects data or uses Required Reason APIs.

---

## Final Task List (İlk seferde App Store onayı için)

Aşağıdaki maddeler projenin App Store’a **ilk seferde** girmesini sağlayacak **zorunlu** dokunuşlardır.

### 1. Sosyal ve Güvenlik (UGC) — [Zorunlu]

| # | Görev | Açıklama |
|---|--------|----------|
| 1.1 | **Contact Support** | Settings ekranına basit bir buton ekle. Bu buton `mailto:support@vitis.app` açmalı veya şık bir “Contact Us” sayfasına (URL) gitmeli. |
| 1.2 | **Profanity Filter** | **TastingNote** ve **Comment** girilirken, post edilmeden önce basit bir “keyword check” (küfür/uygunsuz kelime filtresi) ekle. Guideline 1.2’yi karşıladığını kanıtlar. |

### 2. Alkol Regülasyonu — [Zorunlu]

| # | Görev | Açıklama |
|---|--------|----------|
| 2.1 | **Responsible Drinking Link** | `DrinkResponsiblyView` içine, kullanıcıyı yerel bir destek hattına veya global bir kaynağa (örn. responsibility.org) yönlendiren, tasarımı bozmayan **minimalist bir link** ekle. |
| 2.2 | **Age Gate Hardening** | Yaş doğrulamasını sadece UserDefaults yerine **Profile** tablosunda `is_age_verified: boolean` olarak tut. Apple’ın “Data Integrity” beklentisini karşılar. |

### 3. Hukuki ve Metadata — [Zorunlu]

| # | Görev | Açıklama |
|---|--------|----------|
| 3.1 | **Privacy Policy Check** | **vitis.app/privacy** sayfasında şu başlıkların olduğundan emin ol: **“Data Retention”** (verinin ne kadar süre saklandığı) ve **“How to request data deletion”** (veri silme talebinin nasıl iletileceği). |
| 3.2 | **App Store Connect** | Yaş anketi (Age Rating Questionnaire) içindeki **“Frequent/Intense Alcohol Reference”** kutucuğunun işaretli olduğunu kontrol et. |

### 4. High-Risk (Yukarıdaki §0 ile uyumlu)

| # | Görev | Açıklama |
|---|--------|----------|
| 4.1 | **Privacy Manifests** | Ana uygulama ve kullanılan her SDK (Supabase vb.) için **.xcprivacy** (Privacy Manifest) dosyası ekle; Required Reason API’leri bildir. |

---

## References

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (Safety 1.1–1.7, Performance 2.x, Legal 5.1, etc.)
- [Age ratings (App Store Connect)](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- Vitis: `RootView.swift`, `AgeGateView.swift`, `DrinkResponsiblyView.swift`, `ProfileSettingsView.swift`, `AppConstants.swift`, `ReportService.swift`, `BlockService.swift`, `DeleteAccountView.swift`, `Info.plist`
