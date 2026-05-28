# Project Brief: KazeGarage

> Dokumen ini disinkronkan dengan kode aplikasi yang sedang berjalan. Setiap perubahan signifikan pada arsitektur, fitur, atau design system harus direfleksikan kembali ke dokumen ini.

## 1. Visi Produk
KazeGarage adalah aplikasi manajemen kendaraan personal **offline-first** yang berfokus pada efisiensi pelacakan pengeluaran bahan bakar. Dengan fitur pemindaian struk Pertamina otomatis (OCR via Google ML Kit) dan referensi harga BBM real-time dari berbagai brand, pengguna dapat memantau konsumsi BBM, biaya operasional, dan efisiensi (KM/L) kendaraan mereka dengan cara yang modern dan tanpa hambatan.

## 2. Fitur Utama (Implementasi Aktual)

### A. Beranda / Dashboard (`screens/dashboard/`)
- **Greeting Card** dengan nama pengguna dan ringkasan singkat.
- **Hero Stats Card** (gradient Deep Navy): total pengeluaran BBM dengan filter rentang waktu **Hari Ini / 7 Hari / 30 Hari / Tahun**.
- **Prediksi Pengisian Berikutnya** (dari `FuelPredictionService`): menampilkan tanggal estimasi pengisian BBM berikutnya per kendaraan, lengkap dengan badge status (Masih Lama / Segera / Terlambat), penjelasan basis perhitungan (rata-rata interval), dan indikator akurasi (4 dot) berdasarkan konsistensi pola.
- **Statistik Volume & Efisiensi:** total liter terpakai dan rata-rata KM/L lintas kendaraan (dihitung di `FuelEfficiencyService`).
- **Grafik Mingguan (`fl_chart`):** bar chart konsumsi/pengeluaran 7 hari terakhir.
- **Card Kendaraan Aktif:** menampilkan kendaraan yang sedang ditandai aktif beserta plat nomor & tipe.
- **Daftar Transaksi Terbaru** dengan tombol *Lihat Semua* untuk membuka halaman History.
- **Card Harga BBM Hari Ini** (dari `FuelPriceProvider`): menampilkan harga Pertamina/Vivo/BP/Shell dengan auto-refresh dan timestamp pembaruan.

### B. Manajemen Garasi (`screens/garage/`)
- **Daftar Kendaraan** dengan kartu yang menampilkan nama, plat, tipe kendaraan, kapasitas tangki, status servis & pajak.
- **Tambah Kendaraan** via bottom sheet (`add_vehicle_sheet.dart`): nama, plat, tipe (Mobil Penumpang / Motor Sport / dst), kapasitas tangki (L), tanggal servis berikutnya, tanggal pajak, status aktif.
- **Detail Kendaraan** via bottom sheet (`vehicle_detail_sheet.dart`): statistik per kendaraan (total spending, total liter, jumlah transaksi, rata-rata efisiensi).
- **Swipe-to-Edit / Delete** dengan konfirmasi.
- **Set Active Vehicle** untuk menentukan kendaraan utama yang muncul di Dashboard.

### C. Pemindaian Struk BBM (`screens/scan/scan_receipt_screen.dart`)
- **Input Kamera & Galeri** via `image_picker`.
- **Frame Guide Overlay** untuk membantu pengguna memposisikan struk.
- **OCR Engine:** `google_mlkit_text_recognition` (Latin script).
- **Ekstraksi Data Otomatis:** parser regex untuk struk Pertamina mengambil:
  - SPBU / lokasi
  - Jenis BBM (Pertalite, Pertamax, Pertamax Turbo, Dexlite, Dex, Turbo)
  - Volume (L)
  - Harga per liter
  - Total pembayaran
  - Tanggal transaksi
- **Form Verifikasi & Edit** (`screens/transaction/add_transaction_screen.dart`): hasil scan ditampilkan untuk review, lengkap dengan dropdown pilih kendaraan, input odometer (opsional), catatan, dan attach foto struk.
- **Permission Handler** untuk akses kamera & storage (`permission_handler`).

### D. Riwayat Transaksi (`screens/history/`)
- **Log Kronologis** semua transaksi diurutkan terbaru ke terlama.
- **Filter Per Kendaraan** via dropdown.
- **Detail Transaksi** via bottom sheet (`transaction_detail_sheet.dart`): tampilkan semua field termasuk thumbnail foto struk.
- **Edit & Hapus** transaksi langsung dari detail sheet.

### E. Backup & Restore Data (`screens/settings/backup_restore_sheet.dart`)
Diakses dengan **tap avatar** di app bar. Menyediakan dua lapis perlindungan supaya data tidak hilang saat aplikasi di-uninstall:

1. **Android Auto Backup (otomatis)** — dikonfigurasi via `android/app/src/main/res/xml/backup_rules.xml` + `data_extraction_rules.xml` dan flag `android:allowBackup="true"` di `AndroidManifest.xml`. Database SQLite + folder `receipts/` (foto struk) + SharedPreferences di-backup otomatis ke Google Drive saat HP charging + WiFi + idle. Saat aplikasi di-install ulang (di HP yang sama atau HP baru dengan akun Google sama), data akan otomatis dipulihkan tanpa intervensi user.

2. **Manual Export / Import JSON** (via `BackupService` + `share_plus` + `file_picker`) — untuk redudansi dan kontrol penuh user:
   - **Ekspor Data:** men-serialize semua `vehicles` + `transactions` ke JSON terstruktur (`{ version, app, exportedAt, vehicles, transactions }`), simpan ke folder temp dengan nama `kazegarage-backup-YYYYMMDD-HHMM.json`, lalu trigger system share sheet sehingga user bisa simpan ke Drive, email, WhatsApp, atau penyimpanan lain.
   - **Pulihkan dari File:** pilih file `.json` via `file_picker`, validasi format & versi, lalu konfirmasi via dialog. Dua strategi tersedia:
     - **Ganti Semua** — hapus data lokal lalu pakai data backup (transaksional, atomic)
     - **Gabungkan** — backup overwrite entry dengan id sama, entry lokal yang tidak ada di backup tetap dipertahankan

## 3. Alur Pengguna Utama (User Flow)
1. **Pendaftaran Kendaraan:** Buka tab *Garasi* -> ketuk tombol *Tambah Kendaraan* -> isi form -> simpan.
2. **Pencatatan BBM via Scan:** Tekan FAB *Scan* di tengah bottom nav -> ambil foto struk dari kamera atau galeri -> sistem OCR + parser otomatis mengisi field -> review di halaman *Add Transaction* -> pilih kendaraan -> simpan.
3. **Pencatatan Manual:** Dari halaman *Add Transaction* (juga dapat diakses dari Garage), input data manual tanpa scan.
4. **Monitoring:** Kembali ke *Beranda* -> data dashboard otomatis terupdate (Provider akan re-emit).
5. **Lihat Riwayat Lengkap:** Tap *Lihat Semua* di Dashboard atau navigasi via tombol di Garage.

## 4. Identitas Visual (Design System Aktual)

### Palette (`lib/core/theme/app_colors.dart`)
| Token | Hex | Penggunaan |
|---|---|---|
| `primary` | `#0F1B2D` | Deep Navy — hero card, header gelap |
| `primaryLight` | `#1A2A40` | Variasi terang untuk gradient |
| `primaryDark` | `#080F1A` | Variasi gelap |
| `accent` | `#E63946` | Race Red — CTA, FAB scan, indikator aktif |
| `accentLight` | `#FF6B6B` | Hover / highlight |
| `accentDark` | `#C42A36` | Pressed state |
| `background` | `#F8F9FB` | Background utama (light theme) |
| `surface` | `#FFFFFF` | Card, sheet, app bar |
| `surfaceVariant` | `#F0F2F5` | Background section |
| `textPrimary` | `#1A1A2E` | Teks utama |
| `textSecondary` | `#6B7280` | Teks sekunder |
| `textHint` | `#9CA3AF` | Placeholder, label nav non-aktif |
| `success` | `#10B981` | Status positif |
| `warning` | `#F59E0B` | Peringatan (servis/pajak mendekat) |
| `error` | `#EF4444` | Error / hapus |
| `chartBlue/Green/Orange/Purple/Red` | — | Palette grafik `fl_chart` |

### Tipografi
- **Hanken Grotesk** (variable font) — di-bundle lokal di `assets/fonts/HankenGrotesk-Variable.ttf`.
- Diaplikasikan global lewat `app_theme.dart`.

### Komponen Khas
- **Roundness:** 12–16 px untuk card, 10 px untuk button & input.
- **Shadow:** soft shadow dengan `primary` alpha 6% pada card dan bottom nav.
- **`KazeAppBar`** (`lib/core/widgets/kaze_app_bar.dart`): app bar konsisten di semua halaman utama — avatar kiri, logo brand di tengah, ikon notifikasi di kanan.
- **`KazeNotifier`** (`lib/core/widgets/kaze_notifier.dart`): toast/snackbar wrapper untuk konsistensi feedback (success / error / info).
- **Bottom Navigation 3-Slot** dengan FAB Scan di tengah (concave docked), warna aktif Race Red.

### Aset
- `assets/icon/kaze_garage_logo.png` — wordmark untuk app bar.
- `assets/icon/kaze_garage_icon.png` — sumber launcher icon.
- Launcher icon Android digenerate via `flutter_launcher_icons` dengan adaptive background `#0A1F3D`.

## 5. Arsitektur Aplikasi

### Struktur Folder
```
lib/
├── main.dart                      # Entry point + MultiProvider setup
├── core/
│   ├── theme/
│   │   ├── app_colors.dart       # Token warna
│   │   └── app_theme.dart        # ThemeData (Material 3)
│   └── widgets/
│       ├── kaze_app_bar.dart     # App bar reusable
│       └── kaze_notifier.dart    # Toast/snackbar helper
├── data/
│   ├── database/
│   │   └── database_helper.dart  # SQLite singleton (sqflite)
│   ├── models/
│   │   ├── vehicle.dart
│   │   ├── fuel_transaction.dart
│   │   └── fuel_price.dart       # Brand → list produk (Pertamina/Vivo/BP/Shell)
│   └── services/
│       ├── fuel_price_service.dart       # Scrape harga BBM (http + html parser)
│       ├── fuel_efficiency_service.dart  # Hitung KM/L per kendaraan
│       ├── fuel_prediction_service.dart  # Prediksi tanggal pengisian berikutnya
│       └── backup_service.dart           # Export/import JSON + share/file picker
├── providers/
│   ├── vehicle_provider.dart
│   ├── transaction_provider.dart
│   └── fuel_price_provider.dart
└── screens/
    ├── main_screen.dart           # Shell + bottom nav 3-item + FAB
    ├── dashboard/
    │   └── dashboard_screen.dart
    ├── garage/
    │   ├── garage_screen.dart
    │   ├── add_vehicle_sheet.dart
    │   └── vehicle_detail_sheet.dart
    ├── scan/
    │   └── scan_receipt_screen.dart
    ├── transaction/
    │   └── add_transaction_screen.dart
    ├── history/
    │   ├── history_screen.dart
    │   └── transaction_detail_sheet.dart
    └── settings/
        └── backup_restore_sheet.dart    # Bottom sheet Backup & Restore
```

### State Management
- **Provider** (`provider: ^6.1.5`) — `ChangeNotifierProvider` untuk:
  - `VehicleProvider` (CRUD kendaraan + select active vehicle)
  - `TransactionProvider` (CRUD transaksi + agregasi statistik)
  - `FuelPriceProvider` (fetch & cache harga BBM, auto-refresh saat stale)

### Persistence
- **SQLite** via `sqflite` (path `kaze_garage.db`, schema version **3**).
- **Tabel `vehicles`:** `id, name, license_plate, tank_capacity, image_url, vehicle_type, service_date, tax_date, is_active, created_at`.
- **Tabel `fuel_transactions`:** `id, vehicle_id (FK CASCADE), date, total_cost, liters, price_per_liter, odometer, receipt_image_path, notes, fuel_type, created_at`.
- Migration handler di `_onUpgrade` untuk kolom yang ditambahkan setelah versi 1.

### Networking
- `http` + `html` package untuk scraping harga BBM dari sumber publik (isibens.in).
- Tidak ada backend — harga BBM dicache di provider, gracefully degrade saat offline.

## 6. Tech Stack

| Kategori | Package | Versi |
|---|---|---|
| Framework | Flutter / Dart | SDK `^3.11.5` |
| Database lokal | `sqflite` | `^2.4.2` |
| Path util | `path` | `^1.9.1` |
| State management | `provider` | `^6.1.5` |
| OCR | `google_mlkit_text_recognition` | `^0.14.0` |
| Camera & Galeri | `image_picker` | `^1.1.2` |
| Charting | `fl_chart` | `^0.70.2` |
| Format tanggal & mata uang | `intl` | `^0.20.2` |
| ID generator | `uuid` | `^4.5.1` |
| Permission | `permission_handler` | `^11.4.0` |
| HTTP | `http` | `^1.2.2` |
| HTML parser | `html` | `^0.15.4` |
| File system path | `path_provider` | `^2.1.5` |
| System share sheet | `share_plus` | `^10.1.4` |
| File picker (import backup) | `file_picker` | `^8.1.7` |
| Launcher icon (dev) | `flutter_launcher_icons` | `^0.14.4` |
| Lints (dev) | `flutter_lints` | `^6.0.0` |

## 7. Konfigurasi Build (Android)

- **`applicationId` / `namespace`:** `com.kazegarage.kaze_garage`
- **`android:label`:** `KazeGarage`
- **MinSdk:** 21 (Android 5.0 Lollipop)
- **Java/Kotlin Target:** Java 17
- **Release Build:**
  - `isMinifyEnabled = true`
  - `isShrinkResources = true`
  - ProGuard rules di `android/app/proguard-rules.pro` (menjaga kelas opsional ML Kit Chinese/Devanagari/Japanese/Korean text recognizer dari R8 missing-class error).
- **Output APK:** `build/app/outputs/flutter-apk/app-release.apk` (~49 MB setelah shrink).

## 8. Metadata Proyek
- **Platform Target:** Mobile (Android Only) — iOS belum dikonfigurasi.
- **Mode:** Offline-first. Internet hanya dibutuhkan untuk fitur opsional *Harga BBM Hari Ini*.
- **Target Pengguna:** Pemilik kendaraan personal (mobil/motor) yang ingin memantau efisiensi BBM dan biaya operasional secara digital.
- **Bahasa UI:** Bahasa Indonesia.
- **Mata Uang:** IDR (`Rp`) via `NumberFormat` dari `intl`.

## 9. Agent Guide
- Gunakan AI untuk generating code / design.
- Gunakan **bahasa Indonesia** untuk komentar kode dan dokumen.
- Konsistensi naming: `snake_case` untuk file Dart, `PascalCase` untuk class, `camelCase` untuk variabel & method.
- Setiap fitur baru harus mengikuti pola Provider + DatabaseHelper + Screen yang sudah ada.

## 10. Agent Instruction
Sebagai Flutter developer, tugasmu adalah **memelihara dan mengembangkan aplikasi** sesuai design spec & arsitektur di atas.

### System Instruction
- Selalu ikuti instruksi di atas.
- Selalu cek `prd.md` sebelum menambah/mengubah fitur — dan **update dokumen ini** ketika ada perubahan signifikan pada arsitektur, design system, atau cakupan fitur.
- Jangan mengubah `applicationId`, `namespace`, atau struktur tabel database tanpa migration plan.

## 11. Offline First Application
- Aplikasi **harus** dapat digunakan tanpa koneksi internet.
- Semua data inti (kendaraan + transaksi + foto struk) disimpan di SQLite lokal.
- Fitur online (scrape harga BBM) bersifat *progressive enhancement* — UI tetap berfungsi tanpa data harga, dengan fallback gracefully.

## 12. Data Persistence & Survivability
Data harus **bertahan melewati uninstall** aplikasi. Strategi:

- **Android Auto Backup** (lapis utama, zero-friction): otomatis ke Google Drive akun pengguna. Konfigurasi:
  - `AndroidManifest.xml` → `android:allowBackup="true"`, `android:fullBackupContent="@xml/backup_rules"`, `android:dataExtractionRules="@xml/data_extraction_rules"`
  - Whitelist: `kaze_garage.db` (+ journal/wal/shm), folder `receipts/`, SharedPreferences
  - Restore terjadi otomatis saat aplikasi di-install ulang (HP yang sama atau HP baru dengan akun Google sama)

- **Manual JSON Export/Import** (lapis kedua, eksplisit): user bisa kapan saja men-export `.json` dan menyimpannya ke cloud manapun. Format file menyertakan `version` untuk forward-compat, dan `app: "KazeGarage"` untuk validasi. Restore bersifat transaksional (atomic) — kalau gagal di tengah, database tidak korup.

Kombinasi keduanya memberikan **defense in depth**: kalau Auto Backup gagal/dimatikan user, manual export tetap menjadi safety net.
