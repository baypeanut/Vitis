# Vitis — Proje Özeti (Baştan Sona)

Bu doküman, **Vitis** iOS uygulamasının amacını, mimarisini ve şu ana kadar eklenen tüm fonksiyonları, projeyi hiç bilmeyen biri için adım adım anlatır.

---

## 1. Projenin Amacı

**Vitis**, şarap severler için tasarlanmış **topluluk odaklı bir şarap sıralama uygulamasıdır**. Temel fikir:

- Kullanıcılar **iki şarap arasında tercih yapar** (ör. “Hangisini tercih edersin?”).
- Bu tercihler **Elo benzeri bir puanlama sistemi** ile kişisel bir **sıralama listesi** oluşturur.
- Sonuçlar **sosyal bir feed**’de paylaşılır; diğer kullanıcılar **Cheers** (beğeni) ve **yorum** yapabilir, birbirlerini **takip** edebilir.

Yani hem **kişisel şarap listesi** (Beli / restoran sıralama uygulamalarına benzer), hem de **şarap odaklı bir sosyal feed** sunar. Tasarım dili **“Quiet Luxury”**: sade, burgundy (#4A0E0E) vurgulu, beyaz ağırlıklı, zero-clutter bir arayüz.

---

## 2. Teknoloji ve Mimari

- **Platform:** iOS 17+, SwiftUI  
- **Backend:** Supabase (PostgreSQL, Auth, Storage, Realtime)  
- **Mimari:** MVVM; servisler tekrar kullanılabilir, ekranlar View + ViewModel ile ayrılmış  
- **Harici API:** Open Food Facts (OFF) — şarap aramak ve veritabanına eklemek için

Uygulama **dört ana sekme**den oluşur: **Duel**, **Cellar**, **Social**, **Profile**. Auth açıksa giriş yapılmadan önce **AuthView** gösterilir; kapalıysa (geliştirme modu) doğrudan bu sekmelere gidilir.

---

## 3. Uygulama Giriş Noktası ve Kök Yapı

### 3.1 `VitisApp.swift`

- `@main` ile uygulama girişi.
- Uygulama açılırken `SupabaseManager.shared` oluşturulur (Supabase bağlantısı ilk kez burada hazırlanır).
- Ana içerik **`RootView`**.

### 3.2 `RootView.swift`

- **Auth durumu:** `AppConstants.authRequired == true` ise giriş kontrolü yapılır; oturum yoksa **AuthView**, varsa **TabView** gösterilir.
- **Geliştirme modu:** `authRequired == false` ise giriş ekranı atlanır, doğrudan **TabView** açılır.
- **TabView** dört sekme sunar:
  - **Duel** — Şarap karşılaştırma
  - **Cellar** — “My Ranking” kişisel listesi
  - **Social** — “Curated by” feed (Global / Following)
  - **Profile** — Kendi profil + çıkış
- `.task` içinde:
  - Auth açıksa oturum kontrolü,
  - Kapalıysa `AuthService.ensureGuestSessionIfNeeded()` + `ProfileStore.shared.load()` çalışır.
- `vitisSessionReady` bildirimi gelince `ProfileStore` tekrar yüklenir.
- Çıkışta `didSignOut` → auth ekranına dönülür.

### 3.3 `ContentView.swift`

- Sadece Duel / Cellar / Social sekmelerini içeren basit bir TabView (Profile yok). Proje şu an **RootView** üzerinden çalışıyor; ContentView muhtemelen eski / alternatif kullanım için duruyor.

---

## 4. Çekirdek Yapılandırma ve Tema

### 4.1 `AppConstants.swift`

- **`bundleID`:** `com.ahmet.vitis`
- **`authRequired`:** `false` → giriş zorunlu değil; `true` yapılırsa giriş zorunlu.
- **`Cache`:** Feed önbellek anahtarları (`vitis_feed_global`, `vitis_feed_following`).
- **DEBUG:** `debugMockUserId` — geliştirme için sabit bir kullanıcı UUID’si. Auth kapalıyken bu kullanıcı “mevcut kullanıcı” gibi kullanılır.
- **Bildirimler:**
  - `vitisSessionReady`: Oturum / mock kullanıcı hazır; Duel, Cellar, Profile yenilenir.
  - `vitisProfileUpdated`: Profil (ad, avatar) güncellendi; Feed ve yorumlarda anında yansısı için.

### 4.2 `SupabaseConfig.swift`

- Supabase **Project URL** ve **anon key** burada.
- `isValid`: URL ve key’in dolu olduğunu kontrol eder (ağ testi yapmaz).

### 4.3 `VitisTheme.swift` (“Quiet Luxury”)

- **Renkler:** `accent` (#4A0E0E burgundy), `background` (beyaz), `secondaryText`, `border`.
- **Tipografi:**
  - Şarap isimleri: serif (`wineNameFont`).
  - Üretici: küçük caps veya serif (`producerFont`, `producerSerifFont`).
  - Detay (vintage, bölge): `detailFont`.
  - Başlıklar: `titleFont`.
  - Genel UI: SF Pro `uiFont`.
- Köşeler ≤12pt, gölge kullanımı sınırlı.

---

## 5. Veri Modelleri

### 5.1 `Wine`

- `id`, `name`, `producer`, `vintage`, `variety`, `region`, `labelImageURL`, `category`.
- `category`: Red, White, Sparkling, Rose veya `nil`.
- Duel, Cellar, Feed ve OFF entegrasyonunda ortak model.

### 5.2 `Profile`

- `id`, `username`, `fullName`, `avatarURL`, `bio`, `createdAt`.
- **`displayName`:** `fullName` doluysa onu, değilse `username` döner. Feed, yorumlar ve profil ekranında hep bu kullanılır.
- **`memberSinceYear`:** `createdAt` yılı (örn. “Vitis Member Since 2026”).

### 5.3 `RankingItem`

- Kullanıcının sıralı şarap listesi (Cellar “My Ranking”).
- `wineId`, `position`, `eloScore`, `wine: Wine`.

### 5.4 `FeedItem`

- Feed’deki tek bir aktivite.
- `id`, `userId`, `username`, `avatarURL`, `activityType`, şarap alanları (`wineName`, `wineProducer`, …), `targetWine*` (duel için karşı şarap), `contentText`, `createdAt`.
- **Sosyal:** `cheersCount`, `commentCount`, `hasCheered`.
- `ActivityType`: `rank_update`, `new_entry`, `duel_win`.

### 5.5 `ProfileStats`

- Profil sayfasındaki “Taste Analytics”.
- **`stylePreference`:** Bölgelere göre “Old World” / “New World”.
- **`averageVintageAge`:** Ortalama şişe yaşı (yıl).
- **`topRegion`:** En çok tekrar eden bölge.
- `RankingItem` listesinden hesaplanır.

### 5.6 `CommentWithProfile`

- Yorum + yazar bilgisi: `id`, `userId`, `username`, `avatarURL`, `body`, `createdAt`.
- Comment sheet’te listelenir.

### 5.7 OFF ve Duel Modelleri

- **`OFFProduct` / `OFFSearchResponse`:** Open Food Facts API cevabı. `product_name` → name, `brands` → producer, `image_url` → label, `countries_tags` → region. `mappedCategory`: OFF kategorilerinden Red/White/Sparkling/Rose.
- **`DuelPairPayload`:** `duel_next_pair` RPC cevabı: `wineA`, `wineB`, `wineAIsNew` (ilk kez kullanıcı tarafından kıyaslanan şarap mı).

---

## 6. Servisler

### 6.1 `SupabaseManager`

- Tekil **Supabase client**. Tüm servisler bunu kullanır.
- `emitLocalSessionAsInitialSession: true` ile yerel oturum erken yayınlanır.

### 6.2 `AuthService`

- **`currentUserId()`:** Girişli kullanıcı UUID. DEBUG + auth kapalıyken `debugMockUserId` döner.
- **`ensureGuestSessionIfNeeded()`:**  
  - Auth kapalıyken: sign out, mock kullanıcı için profil upsert (“Dev”), `vitisSessionReady` post edilir.  
  - Auth açıksa: anonim giriş + “Guest” profil oluşturma denemesi.
- **`signUp` / `signIn`:** E‑posta + şifre; profil oluşturma veya oturum açma.
- **`signOut`:** Çıkış.
- **`getProfile(userId)`:** `profiles` tablosundan profil okur.
- **`updateProfile(userId, fullName, avatarURL, bio)`:** Kısmi güncelleme; sadece verilen alanlar değişir.
- Bağlantı ve auth hataları için **`friendlyMessage(for:)`** ile kullanıcı dostu mesajlar.

### 6.3 `ProfileStore`

- **`@Observable`** global singleton; **mevcut kullanıcı profilini** tutar.
- **`load()`:** `AuthService.currentUserId` + `getProfile` ile profili çeker. DEBUG + mock user’da API hata verirse “Dev” fallback.
- **`updateLocal(_:)`:** Profil düzenleme / avatar güncelleme sonrası store güncellenir; Feed ve Comment ekranları `vitisProfileUpdated` ile kendi kullanıcı adı/avatarını buna göre override eder.

### 6.4 `DuelService`

- **`fetchNextPair(userId)`:** `duel_next_pair` RPC’sini çağırır. Sonuç: `(Wine, Wine, Bool)?` — wine A, wine B, A’nın “yeni giriş” olup olmadığı.
- **`submitComparison(userId, wineA, wineB, winnerId)`:**  
  1. `comparisons` tablosuna insert.  
  2. **Elo:** Kazanan / kaybeden için mevcut Elo’ya göre yeni skor hesaplanır, `rankings` upsert edilir.  
  3. `position` değerleri Elo’ya göre yeniden sıralanır.  
  4. `activity_feed`’e `duel_win` aktivitesi eklenir.

### 6.5 `CellarService`

- **`fetchMyRanking(userId)`:** `rankings` + `wines` join ile kullanıcının sıralı listesini `[RankingItem]` olarak döner.

### 6.6 `WineSearchService`

- **Open Food Facts** API’sine istek: `search_terms`, `tagtype_0` = categories, `tag_0` = wines, `search_simple`, `action=process`, `page_size`.
- User-Agent ve timeout ayarlı.
- Dönen `OFFProduct` listesi; `productName` / `brands` boş olanlar filtrelenir.

### 6.7 `WineService`

- **`upsertFromOFF(product)`:** `upsert_wine_from_off` RPC’si. OFF’ten gelen şarap `wines` tablosuna eklenir veya `off_code` ile güncellenir; `category` da gider.
- Sonuç `Wine` olarak döner.

### 6.8 `FeedService`

- **Cache:** `FeedCache` ile JSON dosyalarına yazma/okuma. Global ve Following için ayrı anahtarlar.
- **`fetchGlobal`:** `feed_with_details` view’dan son aktivitelere göre feed.
- **`fetchFollowing`:** `feed_following` RPC — sadece takip edilen kullanıcıların aktiviteleri.
- **Realtime:** `activity_feed` insert’lerine abone olur; yeni kayıt gelince callback tetiklenir, ViewModel refresh yapar.

### 6.9 `SocialService`

- **Cheers (Beğeni):**
  - **`toggleLike(activityID)`:** `likes` tablosunda varsa sil, yoksa ekle.
  - **`fetchLikeCounts(activityIDs)`**, **`fetchLikedActivityIDs(userId)`:** Sayılar ve kullanıcının beğendikleri.
- **Yorumlar:**
  - **`addComment(activityID, body)`:** `comments` tablosuna insert.
  - **`fetchComments(activityID)`:** Yorumlar + `profiles` join ile `username` / `avatar_url` (veya `full_name`).
  - **`fetchCommentCounts(activityIDs)`:** Aktivite bazlı yorum sayıları.
- **Takip:**
  - **`followUser` / `unfollowUser`:** `follows` upsert / delete.
  - **`isFollowing(targetID)`:** Takip durumu.

### 6.10 `AvatarStorageService`

- **`uploadAvatar(userId, jpegData)`:** Supabase Storage **avatars** bucket’ına `{userId}/avatar.jpg` olarak yükler. Public URL döner.

### 6.11 `FeedCache`

- `FeedItem` listesini JSON’a çevirip `Caches` dizinine yazar; uygulama açılışında anında feed göstermek için kullanılır.

---

## 7. Özellikler (Ekranlar ve Akışlar)

### 7.1 Duel (“Which do you prefer?”)

- **Amaç:** İki şarap gösterilir; kullanıcı birini seçer, Submit ile karşılaştırma kaydedilir ve yeni çift yüklenir.
- **DuelView:**
  - Başlık, sağ üstte **+** ile **Add Wine** sheet’i.
  - `DuelViewModel.loadNextPair()` ile çift gelir; `WineCardView` × 2, ortada “vs”.
  - Wine A “yeni giriş” ise **“First Ranking”** etiketi (burgundy).
  - Seçim yapılınca **Submit** aktif olur; `submitComparison` sonrası `loadNextPair` tekrarlanır.
- **DuelViewModel:**
  - `wineA`, `wineB`, `wineAIsNew`, `selectedWinnerID`, `isLoading`, `errorMessage`, `needsAuth`.
  - Auth kapalı + user yoksa “Enable auth or sign in…” mesajı.
  - Yeterli şarap yoksa “Not enough wines. Add some…”.
- **WineCardView:** Etiket alanı (görsel veya placeholder), üretici, isim, vintage; seçilince burgundy çerçeve.

### 7.2 Add Wine (Duel’den açılır)

- **Amaç:** OFF’te arama yap, şarap seç, Supabase’e ekle; ardından Duel’de kullan.
- **AddWineSheet:**
  - Arama çubuğu, sonuç listesi, loading / hata alanları.
  - Seçimde **Add** → `WineService.upsertFromOFF`; sonra `onWineAdded` ile Duel yenilenir.
- **AddWineViewModel:**
  - **Debounce** (300 ms), **≥2 karakter** olunca OFF API çağrısı.
  - **Client-side:** Önbellek, “starts with” öncelikli sıralama, `image_url` + `brands` olanlar filtrelenir.
  - `WineSearchService.search` → `filterAndRank` → `results`. Seçilince `upsert(product)`.

### 7.3 Cellar (“My Ranking”)

- **Amaç:** Duel sonucu oluşan kişisel sıralı listeyi göstermek.
- **CellarView:** Başlık “My Ranking”, pull-to-refresh, `CellarViewModel.load()`.
- **CellarViewModel:** `CellarService.fetchMyRanking` → `[RankingItem]`. Boşsa “Rank wines in Duel to build your list.” Auth gerekliyse “Sign in to see your ranking.”

### 7.4 Social / Feed (“Curated by”)

- **Amaç:** Topluluk aktivite feed’i; Global veya Following, Cheers, yorum, kullanıcı profiline gitme.
- **SocialView:** Sadece **FeedView** sarmalayıcı.
- **FeedView:**
  - “Curated by” başlık, **Global / Following** sekmeleri.
  - `.task`: cache’den yükle, Realtime’a abone ol, `refresh()`.
  - `refreshable` → `viewModel.refresh()`. **CancellationError / URLError.cancelled / “cancelled”** ile biten hatalar kullanıcıya gösterilmez (pull-to-refresh iptalinde “cancelled” hatası çıkmaz).
  - Feed listesi: **FeedItemView** × N; Cheers, Comment, kullanıcı adına tıklayınca **UserProfileView** sheet.
  - Yorum ikonuna tıklayınca **CommentSheetView** açılır (`.medium` / `.large` detent).
  - `vitisProfileUpdated` → `patchCurrentUserOverrides`: Feed’deki **kendi** gönderilerinde isim/avatar `ProfileStore`’dan güncellenir.

### 7.5 FeedItemView

- Her satır: avatar (veya baş harf), dikey çizgi, **statement** (örn. “**Ahmet** ranked Sassicaia higher than Barolo.” — isim serif + burgundy).
- Şarap küçük önizlemeleri (etiket + isim/vintage); duel ise ok + ikinci şarap.
- **Cheers** (dolu/boş bardak, sayı) ve **Comment** (balon + sayı). Cheers basılınca `viewModel.cheer(item)`; renk ve sayı sadece API cevabından sonra güncellenir.

### 7.6 FeedViewModel

- **Tab:** Global / Following. `switchTab` → cache’den yükle + `refresh()`.
- **`refresh()`:** `fetchGlobal` veya `fetchFollowing`; `fetchLikeCounts`, `fetchCommentCounts`, `fetchLikedActivityIDs` ile zenginleştirme; `patchCurrentUserOverrides`; cache’e yazma.
- **`cheer(item)`:** `SocialService.toggleLike`; başarıda yerel `hasCheered` / `cheersCount` güncellenir.
- **`statement` / `statementParts`:** Aktivite tipine göre cümle (rank_update, new_entry, duel_win) ve isim parçası (vurgulu gösterim için).

### 7.7 CommentSheetView

- **Amaç:** Bir feed aktivitesinin yorumlarını listelemek, yeni yorum yazmak.
- `activityID`, `currentUserId`, `isPresented`, `onPosted`.
- Yorumlar `SocialService.fetchComments`; her yorumda `username` / `avatar` `profiles` join’den. **Kendi yorumunda** `ProfileStore.currentProfile` ile isim/avatar override.
- Alt kısımda **TextField** + **Post**. Post sonrası `addComment`, `load()`, `onPosted` ile feed yenilenir.
- Boşsa “No comments yet.”

### 7.8 UserProfileView (Feed’den kullanıcıya tıklanınca)

- Başka kullanıcının profili: avatar, `displayName`, bio. **Follow / Unfollow** butonu (`SocialService.isFollowing`, `followUser`, `unfollowUser`). Kendi profilinde Follow gösterilmez.

### 7.9 Profile (Kendi profil)

- **Amaç:** Profil bilgisi, Taste Analytics, Top 10, profil düzenleme (isim + avatar), çıkış.
- **ProfileView:**
  - **NavigationStack:** Başlık “Profile”, sağ üst **Edit** (düzenleme modunda **Cancel** sol, **Save** sağ).
  - **Edit modu:** İsim yerinde `TextField`; avatar tıklanınca **PhotosPicker** → “Choose from gallery” → **AvatarCropSheet** (zoom/pan crop) → “Use Photo” ile `editAvatarImage` set edilir. **Save** ile hem isim hem avatar (değiştiyse) Supabase’e yazılır.
  - **Save:** Sadece değişiklik varsa aktif. Avatar değiştiyse `AvatarStorageService.uploadAvatar` → `updateProfile(avatarURL:)`; isim de `updateProfile(fullName:)`. Sonra `ProfileStore.updateLocal`, `vitisProfileUpdated` post, `load()` ile yeniden çekilir.
  - **Vitis Member Since:** Yıl `NumberFormatter` ile virgülsüz (örn. 2026).
  - **Taste Analytics:** `ProfileStats` (Style, Avg Vintage Age, Top Region).
  - **The Top 10:** İlk 10 `RankingItem`; yoksa “Rank wines in Duel to build your list.”
  - **Label Gallery** kaldırıldı.
  - **Sign out** en altta.

### 7.10 AvatarCropSheet & ZoomableImageCropView

- **AvatarCropSheet:** Seçilen fotoğrafı daire içinde gösterir; **Cancel** / **Use Photo**.
- **ZoomableImageCropView:** UIScrollView + pinch-to-zoom + pan. Görsel aspect-fill, 1.5× overflow ile her yönde kaydırılabilir. “Use Photo” ile görünür alan kırpılıp JPEG’e çevrilir, avatar olarak kullanılır. Sheet’te `interactiveDismissDisabled` ile aşağı çekerek kapatma kapatıldı; zoom/pan ile çakışma önlendi.

### 7.11 AuthView (Giriş / Kayıt)

- **Amaç:** E‑posta + şifre ile giriş veya kayıt; bağlantı kontrolü.
- **Mode:** Sign In / Sign Up; form alanları, validation (e‑posta formatı, şifre uzunluğu, vs.).
- **Connection:** `AuthService.checkConnection`; başarısızsa “Retry connection” ile tekrar dene.
- **Submit:** `signIn` / `signUp`; başarıda `onAuthenticated` ile TabView’a geçilir.

---

## 8. Veritabanı (Supabase) Özeti

- **`wines`:** Şaraplar; `off_code`, `category`, `created_at` dahil. OFF üzerinden upsert.
- **`profiles`:** Kullanıcı profili; `full_name`, `avatar_url`. RLS + dev mock politikaları.
- **`comparisons`:** Duel karşılaştırmaları (user, wine_a, wine_b, winner).
- **`rankings`:** Kullanıcı–şarap Elo ve sıra (user_id, wine_id, elo_score, position).
- **`activity_feed`:** Aktivite kayıtları (rank_update, new_entry, duel_win); `feed_with_details` view ile profile ve wine join.
- **`follows`:** Takip ilişkileri.
- **`likes`:** Cheers (activity_id, user_id).
- **`comments`:** Yorumlar (activity_id, user_id, body).
- **RPC’ler:**
  - **`duel_next_pair(user_id)`:** Öncelik 1) Hiç kıyaslanmamış, en yeni şarap (A) + aynı kategoriden B; 2) Fallback: rastgele A, aynı kategoriden benzer Elo’lu B. `wine_a_is_new` döner.
  - **`feed_following(follower_id, limit, offset)`:** Takip edilenlerin feed’i.
  - **`upsert_wine_from_off(...)`:** OFF’ten şarap ekleme/güncelleme.
- **Storage:** **avatars** bucket’ı; `{userId}/avatar.jpg`, public okuma, kendi path’ine yazma. Dev mock için `auth.uid() IS NULL` ile özel politikalar.

---

## 9. Dev / Mock Kullanıcı

- **`authRequired == false`** iken:
  - Giriş yapılmaz; `currentUserId` her zaman **`debugMockUserId`**.
  - Supabase tarafında **sign out** yapılır (`auth.uid() = NULL`).
  - **Dev mock RLS** politikaları: `user_id = debugMockUserId` (ve `auth.uid() IS NULL`) ile comparisons, rankings, activity_feed, likes, comments, profiles insert/update vb. izin verir.
- Mock kullanıcı için **profil** (`createProfile` ile “Dev”) uygulama açılışında upsert edilir; böylece profil güncelleme ve avatar akışı çalışır.

---

## 10. Özet Akış (Kullanıcı Perspektifi)

1. Uygulama açılır → (Auth açıksa giriş/kayıt) → Duel / Cellar / Social / Profile sekmeleri.
2. **Duel:** İki şarap görür, birini seçer, Submit → yeni çift gelir. “+” ile OFF’ten şarap ekleyebilir.
3. **Cellar:** Duel’den üretilen “My Ranking” listesini görür.
4. **Social:** Global veya Following feed’i; Cheers, yorum, kullanıcıya tıklayıp profil/takip.
5. **Profile:** Kendi profil, Taste Analytics, Top 10. Edit → isim/avatar değiştir → Save. Çıkış.

Tüm bu akışlar **Quiet Luxury** tema, **Supabase** backend ve **OFF** entegrasyonu ile uyumlu çalışacak şekilde kodlanmıştır.
