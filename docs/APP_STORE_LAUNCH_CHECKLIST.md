# App Store Launch Checklist — Mart 2026

Bu dosya, Vitis’i bugün (Mart 2026) App Store’da yayına almak için karşılaman gereken noktaları özetler. Apple’ın [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) ve App Review Guidelines esas alınmıştır.

---

## 1. Kod ve uygulama (projede mevcut)

| Gereksinim | Durum | Not |
|------------|--------|-----|
| **Age gate (alkol uygulamaları)** | ✅ | `AgeGateView` — ilk açılışta yaş doğrulama (18+). |
| **Drink responsibly** | ✅ | `DrinkResponsiblyView` — yaş kapısından sonra bir kez gösteriliyor; Settings’ten de açılabiliyor. |
| **Hesap silme (Guideline 5.1.1)** | ✅ | `DeleteAccountView` — Settings → Delete Account, yazılı onay + re-auth. |
| **İletişim / destek (Guideline 1.5)** | ✅ | `support@vitis.app`, Settings → Contact Concierge. |
| **Gizlilik politikası & kullanım koşulları** | ✅ | Settings’te Privacy Policy ve Terms of Service ekranları (Mart 2025 tarihli). |
| **UGC / raporlama (Guideline 1.2)** | ✅ | `ReportService`, `ContentModeration`, `BlockService` referansları mevcut. |
| **Privacy manifest (PrivacyInfo.xcprivacy)** | ✅ | UserDefaults gerekçesi + toplanan veri türleri (User ID, Email, Phone, Name) tanımlı. |
| **Usage descriptions (Info.plist)** | ✅ | Kamera, foto kütüphanesi, rehber için açıklamalar var. |
| **URL scheme (auth)** | ✅ | `vitis` scheme ile deep link tanımlı. |

---

## 2. Launch öncesi yapılacaklar (manuel)

### Zorunlu

- [ ] **Auth zorunlu yap:** `AppConstants.authRequired` şu an `false`. Production’da **`true`** yap ki herkes giriş yapmak zorunda kalsın (guest bypass kapalı).
- [ ] **Supabase production:** `SupabaseConfig.swift` ile production Supabase projesi (URL + anon key). Gizli bilgiler commit edilmesin.
- [ ] **PostHog / analytics:** `Secrets.xcconfig` veya ilgili yerde production PostHog key (ve gerekirse host). Info.plist’teki `$(POSTHOG_*)` değerlerinin Release’te doğru dolduğundan emin ol.
- [ ] **Xcode & SDK:** Mart 2026 itibarıyla geçerli gereksinim: [Nisan 2025’ten beri](https://developer.apple.com/news/upcoming-requirements/) Xcode 16+ ve **iOS 18 SDK** ile build. Proje şu an iOS 17.0 deployment target kullanıyor; Xcode 16+ ile build et. (Nisan 2026’dan itibaren Xcode 26 / iOS 26 SDK gerekebilir; o tarihte Apple sayfasını tekrar kontrol et.)
- [ ] **Yaş derecesi (Age Rating):** Alkollü içerik nedeniyle muhtemelen **17+** (ABD) / bölgeye göre uygun derece. [App Store Connect → App Information → Age Rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/) içinde **yeni yaş derecesi sorularını** (31 Ocak 2026’ya kadar yanıtlanması önerilir) doldur.
- [ ] **App Store Connect metadata:** App adı, açıklama, anahtar kelimeler, kategori, **ekran görüntüleri** (6.7", 6.5", 5.5" vb.), **önizleme video** (isteğe bağlı), **promo metin**. Destek URL’i (örn. `https://vitis.app/support` veya mailto) ve Gizlilik Politikası URL’i (`https://vitis.app/privacy`) ekle.
- [ ] **Uygulama ikonu:** `Assets.xcassets/AppIcon.appiconset` içinde tüm gerekli boyutlar dolu mu kontrol et (1024×1024 dahil).

### Önerilen

- [ ] **Release’te debug logları:** `print` ve debug-only loglar çoğunlukla `#if DEBUG` içinde; Release build’de hassas bilgi sızmadığından emin ol.
- [ ] **Export compliance (şifreleme):** Sadece HTTPS kullanıyorsan genelde “No” (özel şifreleme yok). İlk gönderimde App Store Connect’teki soruyu buna göre yanıtla; gerekirse [Info.plist’te](https://developer.apple.com/documentation/bundleresources/information_property_list/itsappusesnonexemptencryption) `ITSAppUsesNonExemptEncryption = NO` eklenebilir.
- [ ] **TestFlight:** İç/dış test ile birkaç cihaz ve iOS sürümünde deneyip crash / auth / feed akışını doğrula.

---

## 3. AB (Avrupa Birliği) dağıtımı

- [ ] **DSA (Digital Services Act):** AB’de dağıtım yapacaksan [Trader Status](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/) gerekebilir; App Store Connect’te ilgili bölümü doldur.

---

## 4. Özet

- **Uygulama tarafı:** Age gate, drink responsibly, hesap silme, destek, gizlilik/şartlar, privacy manifest ve UGC/raporlama ile ilgili kod yerinde; bu kısım App Store kurallarıyla uyumlu görünüyor.
- **Eksik / senin yapman gerekenler:** Production auth (`authRequired = true`), production Supabase + PostHog, doğru Xcode/SDK ile build, yaş derecesi, metadata, ekran görüntüleri ve ikon. AB’de satış yapacaksan DSA trader bilgisi.

Bunları tamamladıktan sonra bugün itibarıyla App Store’da launch için gereken koşulları büyük ölçüde karşılıyorsun; son kontrolleri TestFlight ve ilk gönderimden önce bir kez daha yapman iyi olur.
