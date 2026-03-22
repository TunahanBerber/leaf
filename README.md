# 🍃 Leaf

Kişisel dijital kitaplık uygulaması. Kitaplarını ekle, okuma ilerlemeni takip et, notlarını al.

> Apple hissiyatı: sakin, premium, bağırmayan.  
> Minimal ama soğuk değil.

## Özellikler

- 📚 **Kitap Ekleme** — Kapak görseli (fotoğraf seçici) + kitap bilgileri
- 📖 **Kitaplık Grid** — İki sütunlu, cam efektli kartlarla kitap listesi
- 📝 **Not Alma** — Her kitaba bağlı notlar, opsiyonel sayfa numarası ile
- 📊 **Okuma İlerlemesi** — Sayfa takibi ve yüzde göstergesi
- 💾 **Kalıcı Depolama** — SwiftData ile otomatik kaydetme
- 🌗 **Light & Dark Mode** — Otomatik adaptasyon

---

## Tasarım Sistemi

Web projesindeki CSS token'larından birebir taşındı:

| Token | Değer | Açıklama |
|-------|-------|----------|
| `LeafColors.primaryLight` | `#2f7d5c` | Sakin Leaf yeşili (light) |
| `LeafColors.primaryDark` | `#49c08d` | Daha açık yeşil (dark) |
| `LeafSpacing.md` | `16pt` | Temel boşluk (8pt grid) |
| `LeafRadius.large` | `18pt` | Apple hissiyatı köşeler |
| `LeafMotion.pressScale` | `0.96` | Basma efekti |

### Liquid Glass Yaklaşımı

- Yarı şeffaf yüzeyler (`ultraThinMaterial` + özel opacity)
- Çok katmanlı gölgeler (derinlik hissi için)
- İnce border çizgileri (0.5pt, neredeyse görünmez)
- Abartısız — iOS/macOS Settings paneli hissiyatı

---

## Proje Yapısı

```
leaf/
├── project.yml                    # XcodeGen proje tanımı
├── Leaf.xcodeproj/                # Oluşturulan Xcode projesi
│
└── Leaf/
    ├── App/
    │   ├── LeafApp.swift          # Giriş noktası + SwiftData container
    │   └── ContentView.swift      # Ana ekran (boş/dolu yönlendirme)
    │
    ├── Core/Models/
    │   ├── Book.swift             # Kitap modeli (SwiftData)
    │   └── BookNote.swift         # Not modeli (kitaba bağlı)
    │
    ├── UI/
    │   ├── Theme/
    │   │   ├── LeafColors.swift   # Renk tokenları (light/dark adaptive)
    │   │   └── LeafTokens.swift   # Spacing, radius, motion sabitleri
    │   │
    │   ├── Components/
    │   │   ├── GlassCard.swift              # Cam efektli kart bileşeni
    │   │   ├── LeafGradientBackground.swift # Gradient arka plan
    │   │   └── LeafComponents.swift         # TextField, PressStyle
    │   │
    │   └── Screens/
    │       ├── EmptyStateView.swift    # Boş kitaplık ekranı
    │       ├── LibraryGridView.swift   # Kitap grid görünümü
    │       ├── AddBookView.swift       # Kitap ekleme formu
    │       ├── BookDetailView.swift    # Kitap detay + notlar
    │       └── AddNoteView.swift       # Not ekleme formu
    │
    └── Resources/
        ├── Info.plist
        └── Assets.xcassets/
            ├── AppIcon.appiconset/
            └── AccentColor.colorset/  # Leaf yeşili (adaptive)
```

---

## Teknoloji

| | |
|---|---|
| **Platform** | iOS 26+ |
| **Dil** | Swift 6 |
| **UI** | SwiftUI |
| **Veri** | SwiftData |
| **Proje Yönetimi** | XcodeGen |

---

## Kurulum

### Gereksinimler

- Xcode 26+
- macOS 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Çalıştırma

```bash
# projeyi klonla
git clone <repo-url>
cd leaf

# xcode projesini oluştur
xcodegen generate

# xcode'da aç
open Leaf.xcodeproj
```

Xcode'da **iPhone 17** simülatörünü seç ve ▶️ ile çalıştır.

### Terminal'den çalıştırma

```bash
# build et
xcodebuild -project Leaf.xcodeproj -scheme Leaf \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# simülatöre yükle ve çalıştır
xcrun simctl boot "iPhone 17"
xcrun simctl install booted <DerivedData-path>/Leaf.app
xcrun simctl launch booted com.tunahan.leaf
```

---

## Mimari

```
┌─────────────┐
│   Screens   │  ← UI katmanı (SwiftUI View'ları)
├─────────────┤
│  Components │  ← Yeniden kullanılabilir bileşenler
├─────────────┤
│    Theme    │  ← Tasarım tokenları (renk, spacing, motion)
├─────────────┤
│    Models   │  ← Domain modelleri (SwiftData @Model)
└─────────────┘
```

- **Screens** → Ekranlar, iş mantığı ve veri erişimi burada
- **Components** → `GlassCard`, `LeafTextField`, `PressStyle` gibi tekrar kullanılanlar
- **Theme** → Tüm tasarım kararları tek yerden yönetiliyor
- **Models** → `Book` ve `BookNote`, SwiftData ile kalıcı

---

## Lisans

MIT
