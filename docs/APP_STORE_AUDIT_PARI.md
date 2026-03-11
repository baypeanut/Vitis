# Pari — App Store öncesi kontrol (audit)

Prosedür listesine göre uygulama tarandı. Özet:

---

## 1. Auth ve dev özellikleri

| Kontrol | Durum | Açıklama |
|--------|--------|----------|
| **authRequired** | ✅ | `AppConstants.authRequired = true` — production’da herkes giriş yapmak zorunda. |
| **"Sign in as test user"** | ✅ | Sadece `#if DEBUG` **ve** `!AppConstants.authRequired` içinde; Release’te derlenmez. |
| **Dev login (username/email)** | ✅ | Sadece `!authRequired` iken Onboarding’de "Already have an account? Log in" görünüyor; `authRequired == true` iken bu buton yok. DevLoginView sadece bu akışta kullanılıyor. |
| **devTestEmail / devTestPassword** | ✅ | `#if DEBUG` içinde; Release build’de yok. |
| **Guest / anonymous session** | ✅ | `ensureGuestSessionIfNeeded` içindeki bypass sadece `#if DEBUG` + `!authRequired`; production’da gerçek auth kullanılıyor. |

**Sonuç:** Otomatik sign in ve test user sadece DEBUG ve auth kapalıyken; App Store build’inde sorun çıkmaz.

---

## 2. Debug loglar

| Kontrol | Durum | Açıklama |
|--------|--------|----------|
| **Print / Logger** | ✅ | Çoğu `#if DEBUG` içinde. AuthService’teki `ensureGuestSessionIfNeeded` fail print’i de `#if DEBUG` ile sarıldı. |
| **Hassas bilgi** | ✅ | Release’te çalışan kalan loglar sadece genel hata mesajları (Logger.auth fallback vb.); PII sızmıyor. |

---

## 3. Checklist’teki diğer maddeler

- **Age gate, drink responsibly, hesap silme, destek, gizlilik/şartlar, privacy manifest, UGC/raporlama:** Mevcut ve uyumlu.
- **URL scheme:** `pari` tanımlı.
- **Export compliance:** Sadece HTTPS kullanıyorsan “No” (özel şifreleme yok); ilk gönderimde App Store Connect’te işaretle.

---

## 4. Senin yapman gerekenler (manuel)

- [ ] **Supabase:** Production URL + anon key (SupabaseConfig / Secrets).
- [ ] **PostHog:** Production key, Release’te doluyor olsun.
- [ ] **İkon:** AppIcon.appiconset tüm boyutlar (1024×1024 dahil).
- [ ] **Version/Build:** Xcode’da 1.0.0 / 1.
- [ ] **Archive → Distribute App → Upload.**
- [ ] **App Store Connect:** Ekran görüntüleri, açıklama, gizlilik politikası URL’i, yaş 17+, build seçimi → Submit for Review.

---

**Özet:** Otomatik sign in ve dev kısayolları production’da kapalı; App Store’a gönderim için engel yok. Yukarıdaki manuel adımları tamamlayıp TestFlight ile bir kez deneyip gönderebilirsin.
