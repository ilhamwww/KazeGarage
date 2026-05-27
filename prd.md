# Project Brief: KazeGarage

## 1. Visi Produk
KazeGarage adalah aplikasi manajemen kendaraan personal yang berfokus pada efisiensi pelacakan pengeluaran bahan bakar. Dengan fitur pemindaian struk otomatis, pengguna dapat memantau konsumsi BBM dan biaya operasional kendaraan mereka dengan cara yang modern dan tanpa hambatan.

## 2. Fitur Utama

### A. Dashboard Statistik (Beranda)
*   **Ringkasan Biaya:** Menampilkan total pengeluaran BBM dalam format mata uang yang jelas.
*   **Statistik Volume:** Visualisasi konsumsi bahan bakar dalam rentang waktu Hari Ini, 7 Hari, 30 Hari, dan Tahunan.
*   **Efisiensi & Aktivitas:** Grafik batang mingguan untuk memantau tren pengisian dan daftar transaksi terbaru untuk akses cepat.

### B. Manajemen Garasi
*   **Daftar Kendaraan:** Mengelola informasi kendaraan termasuk Nama, Plat Nomor, dan Jenis Kendaraan.
*   **Status Kendaraan:** Menandai kendaraan yang sedang aktif digunakan.
*   **Informasi Servis & Pajak:** Pengingat jadwal penting untuk setiap unit kendaraan.

### C. Pemindaian Struk BBM (OCR)
*   **Input Kamera:** Antarmuka kamera dengan panduan bingkai untuk pemindaian otomatis.
*   **Input Galeri:** Kemampuan untuk mengunggah foto struk dari penyimpanan lokal.
*   **Ekstraksi Data:** Secara otomatis mengambil data dari struk Pertamina (SPBU, Jenis BBM, Volume L, Harga/Liter, Tanggal, dan Total Pembayaran).

### D. Riwayat Transaksi
*   **Log Kronologis:** Daftar lengkap transaksi yang dikelompokkan berdasarkan bulan.
*   **Filter & Pencarian:** Memudahkan pengguna mencari transaksi berdasarkan jenis BBM atau kata kunci tertentu.

## 3. Alur Pengguna Utama (User Flow)
1.  **Pendaftaran Kendaraan:** Pengguna menambahkan kendaraan mereka di menu "Garasi".
2.  **Pencatatan BBM:** Pengguna menekan tombol "Scan" di navigasi tengah -> Mengambil foto struk -> Sistem memverifikasi data hasil scan.
3.  **Verifikasi & Simpan:** Pengguna memeriksa detail hasil scan (Kendaraan yang dipilih, Total Biaya, dll) dan menekan "Simpan Transaksi".
4.  **Monitoring:** Pengguna kembali ke "Beranda" untuk melihat data pengeluaran yang sudah diperbarui secara otomatis.

## 4. Identitas Visual (Design System)
*   **Nama:** KazeGarage Visual Identity
*   **Warna Utama:** Petrol Blue (#12263a) - Memberikan kesan profesional dan otomotif.
*   **Warna Aksen:** Race Red - Digunakan untuk elemen penting (CTA) dan indikator krusial.
*   **Tipografi:** Hanken Grotesk - Modern, bersih, dan sangat terbaca pada perangkat mobile.
*   **Gaya:** Modern, dengan penggunaan kartu (cards) yang memiliki roundness (8px) untuk kesan yang ramah namun tetap solid.

## 5. Metadata Proyek
*   **Platform:** Mobile (Android Only)
*   **Target Pengguna:** Pemilik kendaraan yang ingin memantau efisiensi bahan bakar secara digital.

## 6. Agent Guide
* Gunakan AI untuk generating code / design
* Gunakan bahasa Indonesia untuk code comment dan document

## 7. Agent Instruction
Sebagai flutter developer, tugasmu membuat aplikasi flutter berdasarkan design spec di atas

### System Instruction
* Selalu ikuti instruksi di atas
* Selalu cek PRD.md untuk instruksi lebih lanjut

## Offline First Application
* Aplikasi harus bisa digunakan tanpa koneksi internet
* Data harus disimpan di lokal database
