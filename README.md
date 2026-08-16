# System Pulse Widget

Hafif, modern ve Windows 10/11 görev çubuğu üzerinde çalışan anlık donanım ve sistem izleme aracı.

![System Pulse](https://img.shields.io/badge/Windows-10%20%2F%2011-blue?style=flat-square)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## ⚡ Özellikler & Göstergeler

- **CPU:** Anlık işlemci kullanımı (`%`), saat frekansı (`GHz`) ve paket sıcaklığı (Honor BIOS desteği)
- **RAM:** Anlık bellek doluluğu (`%`) ve kullanılan / toplam RAM (`GB`)
- **GPU:** Grafik birimi yükü (`%`) ve kullanılan VRAM / Paylaşılan Bellek (`GB`)
- **DİSK:** Disk etkinlik yüzdesi (`%`), anlık **Okuma Hızı (R)** ve **Yazma Hızı (W)**
- **AĞ:** Anlık **İndirme Hızı (↓ Download)** ve **Yükleme Hızı (↑ Upload)**
- **GÜÇ / BATARYA:** Anlık **Şarj Olma / Deşarj Hızı (W - Watt)**, pil yüzdesi ve şarj durumu
- **Görev Çubuğu Entegrasyonu:** Görev çubuğunun hemen üzerine oturur, sürüklenip bırakılabilir, konumu otomatik hatırlar.
- **Sağ Tık Menüsü:** Görev çubuğuna sabitleme (sağ, orta, sol), her zaman üstte kalma ve Windows ile otomatik başlama seçenekleri.

---

## 🚀 Kurulum

Kurulum scriptini çalıştırmak için PowerShell üzerinden:

```powershell
.\Install.ps1
```

Bu komut:
1. Gerekli dosyaları `%LOCALAPPDATA%\SystemPulseWidget` altına yükler.
2. Masaüstüne ve Başlat Menüsüne **System Pulse** kısayolu ekler.
3. Windows başlangıcına ekler.
4. Uygulamayı anında arka planda başlatır.

---

## 🛠️ Manuel Çalıştırma

`Start-SystemPulse.cmd` dosyasına çift tıklayarak veya PowerShell ile:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File .\SystemPulseTaskbar.ps1
```

---

## 🗑️ Kaldırma (Uninstall)

```powershell
.\Uninstall.ps1
```

---

## 📄 Lisans

MIT
