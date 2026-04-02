# Leaf 🌿

Leaf, kitap okumayı ve kitaplarla ilgili düşünceleri organize etmeyi sevenler için geliştirilmiş, Apple ekosisteminin "cam/frosted" tasarım diline sahip minimalist ve **bulut tabanlı** bir dijital kitaplık uygulamasıdır.

Mevcut sürüm, uygulamanın yalnızca bir prototip olmaktan çıkıp güvenli, hata toleranslı ve üretime (Production) hazır bulut mimarisine geçişini temsil eder. (SwiftData tamamen kaldırılmıştır.)

---

## 🏗 Mimari & Teknoloji Yığını

*   **Platform:** iOS 17.0+
*   **UI Çatısı:** SwiftUI
*   **Proje Yönetimi:** Xcodegen (`project.yml`)
*   **Backend & Veritabanı:** [Supabase](https://supabase.com/) (PostgreSQL & Storage)
*   **Kimlik Doğrulama:** Supabase Auth (Email/Parola ve Google Sign-In Nonce akışıyla)
*   **Hata Takibi:** [Sentry](https://sentry.io) (Crash reporting & performans)
*   **Arama Servisi (3 Aşamalı):** 
    1. Kendi yerel kataloğumuz (Supabase `book_catalog`)
    2. Google Books API
    3. OpenLibrary API

---

## 🚀 Kurulum (Developer Guide)

Uygulamanın çalışması için .xcodeproj dosyası yerine `project.yml` kullanılır. Ortam ortam (Debug, Release, Staging) farklı konfigürasyonlara sahip olabilirsiniz.

### 1. Gereksinimler
- Xcode 15 veya üzeri
- [Xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- CocoaPods / SPM gerekmez. Paketlenmiş Swift sınıfları (Supabase, Sentry, GID) doğrudan SPM tabanlı Xcodegen yapılandırmasından projeye çekilir.

### 2. Config ve Sırların (Secrets) Kurulumu
Projedeki veritabanı url'si ve anahtarlar GitHub'a yüklenmez (`Config/Secrets.xcconfig`). Başlamak için:
1. `Config/Secrets.xcconfig.example` dosyasını kopyalayıp aynı klasörde adını `Secrets.xcconfig` yapın.
2. İçerisine kendi (veya test ekibinin sağladığı) Supabase URL ve Anon Key bilgilerini girin.
   *(Not: `https://` çift slashları derleyici bozmasın diye `https:/$()/` formunda yazılır.)*

### 3. Projeyi Üretmek
Terminali açın ve `leaf` klasörünün içinde çalıştırın:
```bash
xcodegen generate
```
Bu işlem sana `Leaf.xcodeproj` dosyasını oluşturacaktır.

### 4. Sentry DSN Eklemek
Uygulama içine kendi Crash Monitoring akışını bağlamak için `LeafApp.swift` dosyası içindeki `init()` fonksiyonuna giderek Sentry DSN atanızı gerçekleştirin.

---

## 📦 Build & Release Yönetimi (TestFlight / App Store)

Leaf, sürümleri için `project.yml` içerisindeki `settings` yapısını baz alır:
- **MARKETING_VERSION (`1.0.0`):** App Store'da görülecek son kullanıcı versiyonu.
- **CURRENT_PROJECT_VERSION (`3`):** TestFlight / App Store Connect'e gönderilen ardışık Build Numarası.
*Yeni bir TestFlight sürümü göndereceğinizde sadece `CURRENT_PROJECT_VERSION`'i artırıp tekrar `xcodegen generate` demeniz yeterlidir.*

### TestFlight Gönderimi:
1. Xcode > Yansıtma Modunu **Any iOS Device (arm64)** olarak ayarlayın.
2. `Product > Archive` yolunu izleyin. (Gerçek anahtarlar sadece Derleme alanına yansır, dışa sızmaz.)
3. Derleme başarılı olunca `Distribute App` sekmesinden App Store Connect / TestFlight aktarımını başlatabilirsiniz.

---

## 💡 Smoke Test Odakları (Cihaz Testleri)
Production'a geçmeden cihazda denenmesi gereken kritik akışlar:
1. **Google Login ve Sign Up:** Nonce akışı sorunsuz tamamlanıp Supabase Auth tetikleniyor mu?
2. **Kapak Fotoğrafı Upload:** `book-covers` Supabase bucket'ına resim atılabiliyor ve yetki/büyük-küçük harf (`lowercased()`) takılması olmadan geri okunabiliyor mu?
3. **Uçak Modunda Arama:** İnternet yokken yapılan aramaların *Exponential Backoff* sistemi ile uygulamayı dondurmadan tekrar deneyip "İnternet bağlantınızı kontrol edin" pop-upını düzgün çıkarttığından emin olun.
