# FRC Scout Hub
### by ITOBOT — Team #6038

Bayrampasa, İstanbul, Türkiye

---

## Proje Hakkında

Bu uygulama, **FIRST Robotics Competition (FRC)** takımlarını **The Blue Alliance API** verisiyle tanıtan, ITOBOT (Takım 6038) tarafından geliştirilen bir iOS uygulamasıdır.

---

## Özellikler

- 🏠 **Ana Sayfa** — FIRST ve ITOBOT tanıtımı
- 👥 **Takım Listesi** — TBA API üzerinden tüm FRC takımlarını listeleme ve arama
- 🔍 **Takım Detayı** — Takım bilgileri, konum, kuruluş yılı, ödüller, website
- ℹ️ **Hakkında** — FIRST, The Blue Alliance ve ITOBOT açıklamaları

---

## Kurulum

### 1. API Anahtarı Alma

Bu uygulama **The Blue Alliance API v3** kullanmaktadır.

1. [thebluealliance.com](https://www.thebluealliance.com) adresine gidin
2. Ücretsiz hesap oluşturun
3. Account Dashboard > **Read API Keys** bölümünden yeni bir anahtar oluşturun

### 2. API Anahtarını Uygulamaya Ekleme

`TBAService.swift` dosyasında şu satırı bulun:

```swift
private let apiKey = "YOUR_TBA_API_KEY_HERE"
```

Ve kendi anahtarınızla değiştirin:

```swift
private let apiKey = "abc123yourkey..."
```

### 3. Xcode'da Açma

1. Yeni bir **iOS App** projesi oluşturun (SwiftUI, minimum iOS 16)
2. Tüm `.swift` dosyalarını projeye ekleyin
3. Build & Run ✅

---

## Dosya Yapısı

```
ITOBot_FRC_App/
├── ITOBotApp.swift        — @main giriş noktası
├── ContentView.swift      — TabView ana yapısı
├── SplashHomeView.swift   — FIRST & ITOBOT tanıtım ekranı
├── TeamListView.swift     — Takım listesi + arama
├── TeamDetailView.swift   — Takım detay sayfası
├── AboutView.swift        — Hakkında sayfası
├── TBAService.swift       — TBA API servisi ve veri modelleri
└── Color+Hex.swift        — Hex renk uzantısı
```

---

## Gereksinimler

- iOS 16.0+
- Xcode 15+
- Swift 5.9+
- The Blue Alliance API Anahtarı (ücretsiz)

---

## The Blue Alliance Hakkında

> "Powered by The Blue Alliance" — [thebluealliance.com](https://www.thebluealliance.com)

The Blue Alliance, FRC topluluğu tarafından açık kaynak olarak geliştirilen, takım ve etkinlik verilerini API aracılığıyla sunan bir platformdur.

---

## ITOBOT Hakkında

ITOBOT (Team 6038), ITO Academy bünyesinde 2017 yılında kurulmuş bir FRC takımıdır.  
🌐 [team6038.com](https://team6038.com)
