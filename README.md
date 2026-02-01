# 🌍 TUGA - Akıllı Seyahat Asistanı

TUGA, yapay zeka destekli kişiselleştirilmiş seyahat planları oluşturan, bütçe takibi yapabilen ve seyahat tutkunlarına modern araçlar sunan kapsamlı bir mobil uygulamadır.

Modern **Flutter** mimarisi ile geliştirilmiş olup, **Google Gemini AI** entegrasyonu sayesinde saniyeler içinde detaylı gezi rotaları oluşturur.

---

## 🚀 Öne Çıkan Özellikler

* **🧠 Yapay Zeka Planlayıcı:** Gemini AI ile hedef, bütçe ve ilgi alanlarına göre saniyeler içinde kişiye özel gezi rotası.
* **🗺️ Detaylı Harita Entegrasyonu:** Google Maps API ile turistik yerleri keşfetme ve rota çizme.
* **💰 Bütçe Yönetimi:** Seyahat harcamalarını kategorilere göre takip etme ve grafiksel analiz.
* **🎒 Akıllı Asistan:** Hava durumu, döviz çevirici ve acil durum numaraları gibi araçlar.
* **🌗 Karanlık Mod:** Göz yormayan, sistem uyumlu modern tasarım.
* **🔒 Güvenli Altyapı:** Firebase Auth ile güvenli giriş ve Firestore ile bulut tabanlı veri saklama.

---

## 📱 Ekran Görüntüleri

### 1. Giriş ve Ana Sayfa
| Giriş Ekranı | Ana Sayfa (Harita) | Ana Sayfa (Widget) |
|:---:|:---:|:---:|
| ![Auth Screen](https://github.com/user-attachments/assets/e3884fa0-9083-406d-81ca-64551fa48fb8) | ![Home Screen](https://github.com/user-attachments/assets/7b9e37b8-5d87-4fa4-8193-bae0e2a6bcf3) | ![Home Widget](https://github.com/user-attachments/assets/a330583a-5fb1-4773-8f5a-1d74bb2c130d) |

### 2. Planlama (AI ve Manuel)
| Planlarım (Boş) | Manuel Plan Ekleme | AI Seyahat Asistanı |
|:---:|:---:|:---:|
| ![Planner Empty](https://github.com/user-attachments/assets/aad7716a-b28f-4302-bf08-133b507d4b4b) | ![Planner Manual](https://github.com/user-attachments/assets/a2f188d0-9927-4ee0-9552-dd45e11135c5) | ![AI Planner](https://github.com/user-attachments/assets/57605017-41e1-4635-89ad-f5db3da01291)
) |

### 3. Detaylar ve Araçlar
| Gezi Detayı & Rota | Seyahat Araçları |
|:---:|:---:|
| ![Trip Detail](https://github.com/user-attachments/assets/19649317-f7d8-46ac-be11-36f1ce0200a1)
) | ![Tools](https://github.com/user-attachments/assets/605e068d-08b0-46ed-b474-150a69e79494)
) |

### 4. Profil ve Favoriler
| Profil & Ayarlar | Favorilerim |
|:---:|:---:|
| ![Profile](https://github.com/user-attachments/assets/851cdd31-73c5-48da-8e95-6e76faeb1867)
) | ![Favorites](https://github.com/user-attachments/assets/4a19fc61-87cc-47c1-b58c-9e4e8ba9e458)
) |

---

## 🛠️ Kullanılan Teknolojiler (Tech Stack)

* **Framework:** Flutter & Dart
* **Backend & Auth:** Firebase (Auth, Firestore, Storage)
* **Yapay Zeka:** Google Gemini API
* **Harita:** Google Maps Flutter & Google Places API
* **Diğer:** Provider, Shared Preferences, Http, Webview

---

## ⬇️ Kurulum

Bu projeyi yerel ortamınızda çalıştırmak için:

1.  Projeyi klonlayın:
    ```bash
    git clone [https://github.com/mustafaatunc/TUGA-Travel-Planner.git](https://github.com/mustafaatunc/TUGA-Travel-Planner.git)
    ```
2.  Bağımlılıkları yükleyin:
    ```bash
    flutter pub get
    ```
3.  API Anahtarlarını Ayarlayın:
    * Kök dizinde `.env` dosyası oluşturun ve gerekli API anahtarlarını (Google Maps, Gemini, vb.) ekleyin.
4.  Çalıştırın:
    ```bash
    flutter run
    ```

---

## 📞 İletişim

Geliştirici: **Mustafa Tunç**
[E-posta](mustafatunc423@gmail.com)
