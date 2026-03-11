# Pari — App Store’a Yükleme Prosedürü

Logo ve isim (Pari) hazır. App Store’a çıkış için adım adım yapılacaklar.

---

## A. Xcode / Proje (şu an yapıldı)

- [x] **Cihazda görünen ad:** `Info.plist` içinde `CFBundleDisplayName = Pari` eklendi; ana ekranda ikonun altında "Pari" yazacak.
- [ ] **İkon:** `Pari/Assets.xcassets/AppIcon.appiconset` içinde tüm boyutlar (1024×1024 dahil) Pari logosu ile dolu olmalı. Xcode’da AppIcon’u açıp kontrol et.

---

## B. Apple Developer & App Store Connect

### 1. Apple Developer Program

- [developer.apple.com](https://developer.apple.com) → Account → **Membership** (yıllık ücretli program aktif olmalı).
- Gerekirse: **Certificates, Identifiers & Profiles** → **Identifiers** → Bundle ID’yi kontrol et (örn. `com.ahmet.pari` veya `com.ahmet.pari`). İlk kez yükleme yapacaksan bu Bundle ID ile App Store Connect’te uygulama oluşturacaksın.

### 2. App Store Connect’te uygulama oluşturma

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**.
2. **Platform:** iOS.
3. **Name:** **Pari** (App Store’da görünecek isim).
4. **Primary Language:** Türkçe veya İngilizce (tercihine göre).
5. **Bundle ID:** Xcode’daki Bundle Identifier ile aynı olanı seç (örn. `com.ahmet.pari`).
6. **SKU:** Benzersiz bir kod (örn. `pari-ios-2026`).
7. **User Access:** Full Access (kendin yöneteceksen).

---

## C. Xcode’da build ayarları (gönderimden önce)

- [ ] **Version & Build:** Xcode → proje → target **Pari** → **General** → **Version** (örn. 1.0.0), **Build** (örn. 1). İlk gönderimde Build’in 1 olması yeterli; her yeni yüklemede Build numarasını artır.
- [ ] **Signing:** **Signing & Capabilities** → Team = Apple Developer hesabın, **Automatically manage signing** işaretli.
- [ ] **Release build:** Scheme’i **Any iOS Device** (veya **Generic iOS Device**) seçip **Product → Archive** ile arşiv al.

---

## D. Archive ve yükleme

1. **Product → Archive** (Release konfigürasyonunda).
2. Archive tamamlanınca **Organizer** penceresi açılır.
3. Seçili archive’a sağ tık → **Distribute App**.
4. **App Store Connect** → **Upload** → sonraki adımlarda varsayılanları kabul et (e.g. upload symbols).
5. Yükleme bitince App Store Connect’te build’in “Processing” sonra “Ready to Submit” olmasını bekle (birkaç dakika–yarım saat).

---

## E. App Store Connect’te metadata ve gönderim

1. **My Apps** → **Pari** → **App Store** sekmesi (iOS).
2. **Prepare for Submission** bölümünde:
   - **Screenshots:** Zorunlu. En az 6.7", 6.5", 5.5" için ekran görüntüleri (Simulator veya cihazdan). Her boyut için gerekli slot sayısı ekranda yazar.
   - **Promotional Text** (isteğe bağlı): Üstte çıkan kısa metin.
   - **Description:** Uygulama açıklaması (Pari’nin ne yaptığı).
   - **Keywords:** Aramada çıkması için anahtar kelimeler (virgülle, boşluksuz).
   - **Support URL:** Destek sayfası veya `mailto:support@pari.app`.
   - **Marketing URL** (isteğe bağlı): Web sitesi.
   - **Privacy Policy URL:** Gizlilik politikası linki (zorunlu).
3. **Build:** “+” ile yüklediğin build’i seç.
4. **General Information:**
   - **Category:** Food & Drink (veya uygun kategori).
   - **Age Rating:** Alkollü içerik nedeniyle muhtemelen **17+**. Soruları doğru yanıtla.
   - **Copyright:** Örn. `2026 [Adın / Şirket]`.
5. **Pricing:** Ücretsiz ise **Free** seç.
6. **App Review Information:** Gerekirse demo hesap (e-posta/şifre), notlar.
7. **Version Release:** Otomatik ya da manuel yayınlama.
8. **Submit for Review** butonuna tıkla.

---

## F. Projede production ayarları (docs/APP_STORE_LAUNCH_CHECKLIST.md ile uyumlu)

- [ ] **Auth zorunlu:** `AppConstants.authRequired = true` (production’da guest kapalı).
- [ ] **Supabase:** Production projesi URL + anon key (`SupabaseConfig` / Secrets).
- [ ] **PostHog:** Production key (Release build’te doluyor olsun).
- [ ] **Export compliance:** Sadece HTTPS ise “No” (özel şifreleme yok); gerekirse Info.plist’te `ITSAppUsesNonExemptEncryption = NO`.
- [ ] **TestFlight:** İstersen önce iç/dış test ile deneyip sonra “Submit for Review”.

---

## G. Özet sıra

1. İkonları Pari logosu ile doldur, `CFBundleDisplayName = Pari` (yapıldı).
2. Apple Developer hesabı + Bundle ID hazır.
3. App Store Connect’te **Pari** uygulamasını oluştur.
4. Xcode’da version/build, signing ayarla → **Archive** → **Distribute App** → Upload.
5. App Store Connect’te ekran görüntüleri, açıklama, gizlilik politikası, yaş derecesi, build seçimi.
6. **Submit for Review**.
7. İnceleme 24–48 saat sürebilir; onay sonrası yayına alırsın (veya otomatik yayınlama seçtiysen açılır).

İlk gönderimde “Missing Compliance” veya “Export Compliance” uyarısı çıkarsa, App Store Connect’te ilgili soruyu “No” (özel şifreleme yok) olarak işaretlemen yeterli olur.
