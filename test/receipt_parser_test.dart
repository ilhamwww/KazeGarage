// Unit test untuk ReceiptParser.
//
// Skenario yang diuji:
// 1. Format struk Pertamina dua-kolom (label English, value di kolom kanan).
// 2. Format yang muncul dari foto user (struk dari SPBU 44.557.18 Bantul).
// 3. Format Indonesia tradisional dengan label "Volume", "Harga/Liter", "Total".
// 4. Format kacau dimana OCR melinearisasi label dulu lalu value.
// 5. parseIndonesianNumber untuk berbagai variasi separator.

import 'package:flutter_test/flutter_test.dart';
import 'package:kaze_garage/data/services/receipt_parser.dart';

void main() {
  group('ReceiptParser.parseIndonesianNumber', () {
    test('decimal Indonesia "2,43" -> 2.43', () {
      expect(ReceiptParser.parseIndonesianNumber('2,43'), 2.43);
    });

    test('decimal English "2.43" -> 2.43', () {
      expect(ReceiptParser.parseIndonesianNumber('2.43'), 2.43);
    });

    test('thousands Indonesia "12.300" -> 12300', () {
      expect(ReceiptParser.parseIndonesianNumber('12.300'), 12300);
    });

    test('thousands + decimal Indonesia "1.234,56" -> 1234.56', () {
      expect(ReceiptParser.parseIndonesianNumber('1.234,56'), 1234.56);
    });

    test('thousands + decimal English "1,234.56" -> 1234.56', () {
      expect(ReceiptParser.parseIndonesianNumber('1,234.56'), 1234.56);
    });

    test('plain integer "30000" -> 30000', () {
      expect(ReceiptParser.parseIndonesianNumber('30000'), 30000);
    });

    test('empty string -> null', () {
      expect(ReceiptParser.parseIndonesianNumber(''), isNull);
    });
  });

  group('ReceiptParser.parse - Pertamina format dari foto user', () {
    // Format yang muncul di foto user — label di kolom kiri,
    // value di kolom kanan, OCR mengembalikannya same-line dengan banyak spasi.
    const ocr = '''
SPBU 44.557.18
Jl.Tentara Pelajar Bantul
28/05/2026                         12:52
Receipt No.:035149
Pump No.                                02
Grade                              Pertamax
Volume                                 2,43
Unit Price                            12300
Amount                                30000
Vehicle No.                       Not Entered
Selamat Jalan & TERIMA KASIH
''';

    test('mendeteksi SPBU code format 3-segmen', () {
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
      expect(r.spbuCode, '44.557.18');
    });

    test(
      'mendeteksi SPBU name sebagai Pertamina (fallback dari "SPBU ...")',
      () {
        final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
        expect(r.spbuName, 'SPBU PERTAMINA');
      },
    );

    test('mendeteksi fuel type Pertamax via label Grade', () {
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
      expect(r.fuelType, 'Pertamax');
    });

    test('mendeteksi Volume = 2.43 L', () {
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
      expect(r.liters, closeTo(2.43, 0.001));
    });

    test('mendeteksi Unit Price = 12300', () {
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
      expect(r.pricePerLiter, closeTo(12300, 0.5));
    });

    test('mendeteksi Amount = 30000', () {
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
      expect(r.total, closeTo(30000, 0.5));
    });

    test('mendeteksi tanggal struk 28/05/2026 12:52', () {
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
      expect(r.date, isNotNull);
      expect(r.date!.year, 2026);
      expect(r.date!.month, 5);
      expect(r.date!.day, 28);
      expect(r.date!.hour, 12);
      expect(r.date!.minute, 52);
    });
  });

  group(
    'ReceiptParser.parse - format column-block (label dulu, value dulu)',
    () {
      // Skenario terburuk: ML Kit melinearisasi semua label dulu kemudian
      // semua value, sehingga tidak ada label & value di baris yang sama.
      const ocr = '''
SPBU 34.12301
PERTAMINA
28/05/2026
12:52
Pump No.
Grade
Volume
Unit Price
Amount
02
Pertamax
5,50
13000
71500
TERIMA KASIH
''';

      test('Volume terdeteksi 5.50 (tidak tertukar dengan value lain)', () {
        final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
        expect(r.liters, closeTo(5.50, 0.001));
      });

      test('Unit Price terdeteksi 13000', () {
        final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
        expect(r.pricePerLiter, closeTo(13000, 0.5));
      });

      test('Amount terdeteksi 71500', () {
        final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
        expect(r.total, closeTo(71500, 0.5));
      });

      test('fuel type terdeteksi Pertamax (dari teks global)', () {
        final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
        expect(r.fuelType, 'Pertamax');
      });

      test('SPBU code 2-segmen tetap terdeteksi', () {
        final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
        expect(r.spbuCode, '34.12301');
      });
    },
  );

  group('ReceiptParser.parse - format Indonesia tradisional', () {
    const ocr = '''
SPBU PERTAMINA 34.12301
Jl. Sudirman No. 1
Tanggal: 15/01/2026 10:30
Pertalite
Volume         : 5,50 L
Harga/Liter    : Rp 10.000
Total          : Rp 55.000
Terima kasih
''';

    test('parse semua field utama', () {
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 1, 16));
      expect(r.spbuName, 'SPBU PERTAMINA');
      expect(r.spbuCode, '34.12301');
      expect(r.fuelType, 'Pertalite');
      expect(r.liters, closeTo(5.50, 0.001));
      expect(r.pricePerLiter, closeTo(10000, 0.5));
      expect(r.total, closeTo(55000, 0.5));
      expect(r.date, isNotNull);
      expect(r.date!.year, 2026);
      expect(r.date!.month, 1);
      expect(r.date!.day, 15);
    });
  });

  group('ReceiptParser.parse - cross-validation', () {
    test('total dihitung otomatis kalau hanya ada liters & pricePerLiter', () {
      const ocr = '''
SPBU
Pertamax
Volume: 4,00 L
Harga/Liter: Rp 13.000
''';
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 1, 1));
      expect(r.liters, closeTo(4.0, 0.001));
      expect(r.pricePerLiter, closeTo(13000, 0.5));
      expect(r.total, closeTo(52000, 0.5));
    });

    test('liters dihitung dari total/price kalau tidak terbaca', () {
      // Simulasi: Volume tidak ada di teks
      const ocr = '''
SPBU PERTAMINA
Pertamax
Harga/Liter: Rp 13.000
Total: Rp 65.000
''';
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 1, 1));
      expect(r.pricePerLiter, closeTo(13000, 0.5));
      expect(r.total, closeTo(65000, 0.5));
      expect(r.liters, closeTo(5.0, 0.001));
    });
  });

  group('ReceiptParser.parse - edge cases', () {
    test('tanggal di masa depan ditolak', () {
      const ocr = 'SPBU\n28/05/2099\n12:00\nPertamax\nTotal: Rp 30.000';
      final r = ReceiptParser.parse(ocr, now: DateTime(2026, 5, 29));
      expect(r.date, isNull);
    });

    test('teks kosong -> semua field null kecuali default spbuName', () {
      final r = ReceiptParser.parse('', now: DateTime(2026, 1, 1));
      expect(r.liters, isNull);
      expect(r.pricePerLiter, isNull);
      expect(r.total, isNull);
      expect(r.spbuName, 'SPBU');
    });
  });
}
