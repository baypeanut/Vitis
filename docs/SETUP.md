# Vitis – Yerel kurulum ve iki kişi çalışma

Projeyi klonlama, Supabase bağlantısı, Xcode ile çalışma ve git push/pull ile ortak geliştirme.

---

## 1. Projeyi klonla

```bash
git clone https://github.com/<GITHUB_USER_OR_ORG>/Vitis.git
cd Vitis
```

`<GITHUB_USER_OR_ORG>/Vitis` kısmını gerçek repo URL’i ile değiştir.

**Kişisel / hassas bilgiler:** Supabase URL ve anon key repoda yok. `SupabaseConfig.swift` gitignore’da; herkes `SupabaseConfig.example.swift`’i kopyalayıp kendi key’ini yazar. `build/`, `DerivedData/` da ignore’da. `AppConstants` içindeki dev test değerleri sadece DEBUG’ta kullanılır.

---

## 2. Xcode ile aç ve paketleri yükle

- `Vitis.xcworkspace` yoksa `Vitis.xcodeproj` aç.
- Xcode açılınca Swift Package Manager paketleri (Supabase vb.) otomatik resolve olur. Bekle.
- Scheme: **Vitis**, destination: **iPhone Simulator** seçip **Run** (Cmd+R) ile derleyebilmen lazım.

---

## 3. Supabase bağlantısı (her geliştirici kendi makinesinde)

Supabase URL ve anon key **repo’da yok**; herkes kendi config’ini oluşturur.

### 3a. Paylaşılan proje kullanıyorsanız (tercih edilen)

- Projeyi ilk kuran kişi kendi Supabase projesini kullanır.
- Diğer geliştiriciye **Project URL** ve **anon (public) key**’i güvenli kanaldan (Slack, 1Password vb.) iletir.
- Supabase Dashboard → **Project Settings → API**:
  - **Project URL**
  - **Project API keys → anon public**

### 3b. Her geliştirici kendi Supabase projesini kullanacaksa

- [Supabase](https://supabase.com) → **New Project**.
- Proje oluşunca yine **Project Settings → API**’den **Project URL** ve **anon public** key al.

### Config dosyasını oluştur

```bash
cd Vitis/Core
cp SupabaseConfig.example.swift SupabaseConfig.swift
```

`SupabaseConfig.swift` dosyasını aç; placeholders’ı kendi değerlerinle değiştir:

- `https://YOUR_PROJECT_REF.supabase.co` → kendi **Project URL**’in
- `YOUR_ANON_KEY` → kendi **anon public** key’in

`SupabaseConfig.swift` **gitignore**’da; **asla commit etme**.

---

## 4. Veritabanı (Supabase) kurulumu

### Paylaşılan proje

- Projeyi kuran kişi **ilk kez** `supabase/setup_schema.sql`’i çalıştırmış olmalı.
- Yeni migration’lar varsa, sırayla Supabase **SQL Editor**’de çalıştır veya `supabase db push` kullan.

### Kendi projen

- Supabase **SQL Editor** → **New query**.
- `supabase/setup_schema.sql` içeriğini yapıştırıp **Run**.
- Gerekirse migration’ları da sırayla uygula.

### Storage (avatarlar)

- **Storage**’da `avatars` bucket’ı `setup_schema.sql` ile tanımlı. Script’i çalıştırdıysan bucket + RLS oluşmuş olmalı.
- Yoksa Dashboard’dan **Storage → New bucket → avatars** oluşturup ilgili RLS policy’leri ekle.

### Dev / test kullanıcısı (opsiyonel)

- **Auth → Users**’da `dev@vitis.test` / `DevTest1!` ile kullanıcı oluşturulabilir (Auth kapalı modda “Sign in as test user” için).
- `AppConstants.debugMockUserId` ve schema’daki dev mock UUID’leri **paylaşılan projede** aynı kalabilir; **kendi projende** tek başına geliştiriyorsan mevcut haliyle de çalışır.

---

## 5. Uygulamayı çalıştır

- Xcode’da **Vitis** scheme, **iPhone Simulator**.
- **Run** (Cmd+R).
- `SupabaseConfig` doğruysa uygulama açılır; Auth kapalı modda doğrudan ana ekrana düşebilir.

---

## 6. Git workflow (sen + arkadaşın)

### Repo’yu sen kuruyorsan

1. GitHub’da **Vitis** reposu oluştur (boş veya mevcut local projeyi push’la).
2. Local’de:
   ```bash
   git remote add origin https://github.com/<GITHUB_USER_OR_ORG>/Vitis.git
   git add .
   git commit -m "Initial project setup"
   git push -u origin main
   ```
3. `.gitignore` sayesinde `build/`, `SupabaseConfig.swift` vb. push edilmez. **SupabaseConfig.swift asla commit edilmemeli.**

### Arkadaşın ilk kez katılıyor

1. Repo’yu klonlar (`git clone ...`).
2. **SETUP.md**’deki 2–4 adımlarını uygular (Xcode, Supabase config, gerekirse DB).
3. Projeyi çalıştırıp kendi makinesinde test eder.

### Günlük çalışma (paslaşma)

- **Sen değişiklik yaptığında:**
  ```bash
  git add .
  git commit -m "Kısa açıklama"
  git push
  ```
- **Arkadaşın güncel kodu alıp çalışacak:**
  ```bash
  git pull
  ```
  Sonra Xcode’da açıp çalıştırır.

- **Arkadaş değişiklik yaptığında:** O push eder, sen `git pull` çekersin.

- **Aynı anda aynı dosyaya dokunmayın;** mümkünse küçük, sık commit + pull ile ilerleyin. Çakışma olursa git merge/rebase ile çözülür.

### Commit edilmemesi gerekenler

- `Vitis/Core/SupabaseConfig.swift` (içinde URL/key var)
- `build/`, `DerivedData/`
- `.env` veya benzeri secret dosyalar  

Bunlar `.gitignore`’da tanımlı.

---

## 7. Özet kontrol listesi (yeni geliştirici)

- [ ] Repo klonlandı
- [ ] Xcode ile açıldı, paketler yüklendi, proje derlendi
- [ ] `SupabaseConfig.example.swift` → `SupabaseConfig.swift` kopyalandı, kendi URL + anon key yazıldı
- [ ] `setup_schema.sql` (ve varsa migration’lar) kendi Supabase projesinde veya paylaşılan projede çalıştırıldı
- [ ] Uygulama simülatörde açılıyor, Supabase’e bağlanıyor
- [ ] `git pull` / `git push` ile seninle paslaşabileceğini biliyor

---

## 8. Sorun giderme

- **“Invalid Supabase URL or anon key”:** `SupabaseConfig.swift` doğru mu, dosya hedefte var mı kontrol et.
- **RLS / “new row violates…”:** `setup_schema.sql` ve migration’lar sırayla uygulanmış mı, Storage `avatars` ve policy’leri var mı bak.
- **Paket resolve hatası:** Xcode → **File → Packages → Reset Package Caches**, sonra **Resolve Package Versions**.
- **Simülatör listesi boş:** Xcode → **Window → Devices and Simulators** ile uygun bir simulator indir.

Bu adımlarla hem sen hem arkadaşın kendi ortamında çalışıp, değişiklikleri git üzerinden paylaşabilirsiniz.
