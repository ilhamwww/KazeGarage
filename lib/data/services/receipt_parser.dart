// Parser untuk teks OCR struk SPBU.
//
// Mendukung beberapa format umum di Indonesia:
// 1. Same-line label-value (Indonesia):
//      "Volume     : 5,50 L"
//      "Harga/Liter: Rp 13.000"
//      "Total      : Rp 71.500"
//
// 2. Same-line label-value (English Pertamina baru):
//      "Pump No.            02"
//      "Grade            Pertamax"
//      "Volume               2,43"
//      "Unit Price          12300"
//      "Amount              30000"
//
// 3. Column-block (OCR melinearisasi semua label dulu, lalu semua value):
//      "Pump No.\nGrade\nVolume\nUnit Price\nAmount\n02\nPertamax\n2,43\n12300\n30000"
//
// Untuk Strategi 3, alignment label↔value hanya dilakukan pada pasangan
// numeric-label dan numeric-value, sehingga value bertipe text (mis. "Pertamax"
// untuk Grade) tidak menggeser urutan.

import 'dart:math' as math;

class ReceiptData {
  final double? liters;
  final double? pricePerLiter;
  final double? total;
  final String? fuelType;
  final String? spbuName;
  final String? spbuCode;
  final DateTime? date;

  const ReceiptData({
    this.liters,
    this.pricePerLiter,
    this.total,
    this.fuelType,
    this.spbuName,
    this.spbuCode,
    this.date,
  });

  ReceiptData copyWith({
    double? liters,
    double? pricePerLiter,
    double? total,
    String? fuelType,
    String? spbuName,
    String? spbuCode,
    DateTime? date,
  }) {
    return ReceiptData(
      liters: liters ?? this.liters,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      total: total ?? this.total,
      fuelType: fuelType ?? this.fuelType,
      spbuName: spbuName ?? this.spbuName,
      spbuCode: spbuCode ?? this.spbuCode,
      date: date ?? this.date,
    );
  }
}

class ReceiptParser {
  static const List<String> _knownFuelTypes = [
    'PERTAMAX TURBO',
    'PERTAMAX',
    'PERTALITE',
    'DEXLITE',
    'BIO SOLAR',
    'SOLAR',
    'DEX',
    'PREMIUM',
    'V-POWER',
    'SUPER',
  ];

  /// Parse OCR text dari struk SPBU dan kembalikan data terstruktur.
  ///
  /// `now` digunakan untuk validasi tanggal struk (tidak boleh di masa depan).
  /// Jika null, [DateTime.now] dipakai. Parameter ini memudahkan testing.
  static ReceiptData parse(String ocrText, {DateTime? now}) {
    final referenceNow = now ?? DateTime.now();
    final upperText = ocrText.toUpperCase();
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final spbuName = _detectSpbuName(lines);
    final spbuCode = _detectSpbuCode(ocrText);
    var fuelType = _detectFuelType(upperText);
    fuelType ??= _detectFuelTypeFromGrade(lines);

    var liters = _detectLiters(ocrText);
    liters ??= _detectFromColumn(lines, const ['VOLUME'], (v) {
      return v > 0 && v < 500;
    });

    var pricePerLiter = _detectPricePerLiter(ocrText);
    pricePerLiter ??= _detectFromColumn(lines, const [
      'UNIT PRICE',
      'UNIT',
      'PRICE',
    ], (v) => v >= 1000 && v <= 50000);

    var total = _detectTotal(ocrText);
    total ??= _detectFromColumn(lines, const [
      'AMOUNT',
      'TOTAL',
      'JUMLAH',
    ], (v) => v > 1000);

    final date = _detectDateTime(ocrText, referenceNow);

    // Cross-validation: derive missing field, atau koreksi kalau tidak konsisten.
    final reconciled = _reconcile(liters, pricePerLiter, total);

    return ReceiptData(
      liters: reconciled.$1,
      pricePerLiter: reconciled.$2,
      total: reconciled.$3,
      fuelType: fuelType,
      spbuName: spbuName,
      spbuCode: spbuCode,
      date: date,
    );
  }

  // ---------------------------------------------------------------------------
  // SPBU name
  // ---------------------------------------------------------------------------
  static String _detectSpbuName(List<String> lines) {
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.contains('PERTAMINA')) return 'SPBU PERTAMINA';
      if (upper.contains('SHELL')) return 'SHELL';
      if (upper.contains('VIVO')) return 'VIVO';
      if (upper.contains('BP ')) return 'BP';
    }
    // Fallback: keyword "SPBU" tanpa brand spesifik (umum untuk struk Pertamina
    // yang diawali "SPBU 44.557.18")
    for (final line in lines) {
      if (line.toUpperCase().contains('SPBU')) return 'SPBU PERTAMINA';
    }
    return 'SPBU';
  }

  // ---------------------------------------------------------------------------
  // SPBU code: 2 atau 3 segmen (mis. 34.12301 atau 44.557.18)
  // ---------------------------------------------------------------------------
  static String? _detectSpbuCode(String ocrText) {
    final m = RegExp(r'\b(\d{2}\.\d{2,5}(?:\.\d{1,3})?)\b').firstMatch(ocrText);
    return m?.group(1);
  }

  // ---------------------------------------------------------------------------
  // Fuel type
  // ---------------------------------------------------------------------------
  static String? _detectFuelType(String upperText) {
    for (final ft in _knownFuelTypes) {
      if (upperText.contains(ft)) return _capitalize(ft);
    }
    return null;
  }

  static String? _detectFuelTypeFromGrade(List<String> lines) {
    final v = _findColumnValue(lines, const ['GRADE'], expectsNumber: false);
    if (v == null) return null;
    final upper = v.toUpperCase();
    for (final ft in _knownFuelTypes) {
      if (upper.contains(ft)) return _capitalize(ft);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Liters
  // ---------------------------------------------------------------------------
  static double? _detectLiters(String ocrText) {
    final patterns = [
      RegExp(
        r'[Vv]olume\s*[:=]\s*\(?\s*[Ll]\s*\)?\s*(\d+[.,]\d+)',
        caseSensitive: false,
      ),
      RegExp(r'[Vv]olume\s*[:=]\s*(\d+[.,]\d+)', caseSensitive: false),
      RegExp(r'[Vv]olume\s+(\d+[.,]\d+)', caseSensitive: false),
      RegExp(r'\(?[Ll]\)?\s*(\d+[.,]\d+)', caseSensitive: false),
      RegExp(
        r'(?:^|\s)(?:L|Liter|LT)\s*[:=]\s*(\d+[.,]\d+)',
        caseSensitive: false,
      ),
      RegExp(r'(\d+[.,]\d{1,2})\s*(?:L|LTR|Liter|LT)\b', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(ocrText);
      if (m != null) {
        final v = parseIndonesianNumber(m.group(1)!);
        if (v != null && v > 0 && v < 500) return v;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Price per liter
  // ---------------------------------------------------------------------------
  static double? _detectPricePerLiter(String ocrText) {
    final patterns = [
      RegExp(
        r'[Hh]arga\s*/\s*[Ll]iter\s*[:=]?\s*[Rr][Pp]\.?\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'[Hh]arga\s*/\s*[Ll]iter\s*[:=]\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'[Hh]arga\s*[:=]\s*[Rr][Pp]\.?\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(r'[Rr][Pp]\.?\s*(\d[.,\d]+)\s*/\s*[Ll]', caseSensitive: false),
      RegExp(r'(\d[.,\d]+)\s*/\s*(?:L|Liter|LTR)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(ocrText);
      if (m != null) {
        final v = parseIndonesianNumber(m.group(1)!);
        if (v != null && v >= 1000 && v <= 50000) return v;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Total
  // ---------------------------------------------------------------------------
  static double? _detectTotal(String ocrText) {
    final patterns = [
      RegExp(
        r'[Tt]otal\s*[Hh]arga\s*[:=]?\s*[Rr][Pp]\.?\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'[Tt]otal\s*[:=]\s*[Rr][Pp]\.?\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:TOTAL|JUMLAH|TAGIHAN)\s*[:=]?\s*(?:RP\.?\s*)?(\d[.,\d]+)',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(ocrText);
      if (m != null) {
        final v = parseIndonesianNumber(m.group(1)!);
        if (v != null && v > 1000) return v;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Date + Time
  // ---------------------------------------------------------------------------
  static DateTime? _detectDateTime(String ocrText, DateTime now) {
    final dateMatch = RegExp(
      r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b',
    ).firstMatch(ocrText);
    if (dateMatch == null) return null;

    final d = int.tryParse(dateMatch.group(1)!) ?? 0;
    final mo = int.tryParse(dateMatch.group(2)!) ?? 0;
    var y = int.tryParse(dateMatch.group(3)!) ?? 0;
    if (y < 100) y += 2000;
    if (d < 1 || d > 31 || mo < 1 || mo > 12 || y < 2000) return null;

    int hour = 0, minute = 0;
    final timeMatch = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(ocrText);
    if (timeMatch != null) {
      final h = int.tryParse(timeMatch.group(1)!) ?? 0;
      final mi = int.tryParse(timeMatch.group(2)!) ?? 0;
      if (h >= 0 && h <= 23 && mi >= 0 && mi <= 59) {
        hour = h;
        minute = mi;
      }
    }

    final result = DateTime(y, mo, d, hour, minute);
    if (result.isAfter(now.add(const Duration(days: 1)))) return null;
    return result;
  }

  // ---------------------------------------------------------------------------
  // Cross-validation
  // ---------------------------------------------------------------------------
  static (double?, double?, double?) _reconcile(
    double? liters,
    double? pricePerLiter,
    double? total,
  ) {
    if (liters != null && pricePerLiter != null && total == null) {
      return (liters, pricePerLiter, liters * pricePerLiter);
    }
    if (liters != null && total != null && pricePerLiter == null) {
      final p = total / liters;
      if (p >= 1000 && p <= 50000) {
        return (liters, p, total);
      }
      return (liters, null, total);
    }
    if (pricePerLiter != null && total != null && liters == null) {
      final l = total / pricePerLiter;
      if (l > 0 && l < 500) {
        return (l, pricePerLiter, total);
      }
      return (null, pricePerLiter, total);
    }
    if (liters != null && pricePerLiter != null && total != null) {
      final expected = liters * pricePerLiter;
      final diff = (expected - total).abs() / total;
      if (diff > 0.05) {
        // Tidak konsisten. Percayai total + price (umumnya tercetak jelas)
        // dan recompute liters.
        final l = total / pricePerLiter;
        if (l > 0 && l < 500) {
          return (l, pricePerLiter, total);
        }
      }
    }
    return (liters, pricePerLiter, total);
  }

  // ---------------------------------------------------------------------------
  // Column helper
  // ---------------------------------------------------------------------------
  static double? _detectFromColumn(
    List<String> lines,
    List<String> labelKeywords,
    bool Function(double) sanityCheck,
  ) {
    final v = _findColumnValue(lines, labelKeywords, expectsNumber: true);
    if (v == null) return null;
    final firstNumber = _extractFirstNumber(v);
    if (firstNumber == null) return null;
    final parsed = parseIndonesianNumber(firstNumber);
    if (parsed != null && sanityCheck(parsed)) return parsed;
    return null;
  }

  /// Cari value untuk salah satu label keyword dengan dua strategi:
  /// 1. Same-line: "Volume    2,43"
  /// 2. Column-mode: blok label diikuti blok value (hanya untuk numeric labels).
  ///
  /// Jika [expectsNumber] true, alignment column-mode hanya menggunakan
  /// numeric-label & numeric-value sehingga tidak terganggu oleh label/value
  /// bertipe text seperti Grade -> Pertamax.
  static String? _findColumnValue(
    List<String> lines,
    List<String> labelKeywords, {
    required bool expectsNumber,
  }) {
    final upperKeywords = labelKeywords.map((e) => e.toUpperCase()).toList();
    final numberRe = RegExp(r'\d');

    // Strategi 1: same-line
    for (final line in lines) {
      final upper = line.toUpperCase();
      for (final kw in upperKeywords) {
        final idx = upper.indexOf(kw);
        if (idx < 0) continue;
        // Cek batas kata kiri
        final leftOk =
            idx == 0 || !RegExp(r'[A-Z0-9]').hasMatch(upper[idx - 1]);
        if (!leftOk) continue;
        final rest = line.substring(idx + kw.length);
        final hasContent = expectsNumber
            ? numberRe.hasMatch(rest)
            : rest.trim().isNotEmpty;
        if (hasContent) return rest.trim();
      }
    }

    // Strategi 2: column-mode hanya untuk numeric expectations.
    if (!expectsNumber) return null;

    const numericLabelKeywords = [
      'PUMP NO',
      'VOLUME',
      'UNIT PRICE',
      'PRICE',
      'AMOUNT',
      'TOTAL',
      'JUMLAH',
      'HARGA',
      'LITER',
      'RECEIPT NO',
    ];

    bool targetIsNumeric = false;
    for (final kw in upperKeywords) {
      for (final nk in numericLabelKeywords) {
        if (kw.contains(nk) || nk.contains(kw)) {
          targetIsNumeric = true;
          break;
        }
      }
      if (targetIsNumeric) break;
    }
    if (!targetIsNumeric) return null;

    int? targetLabelIdx;
    final labelIdxList = <int>[];
    final valueIdxList = <int>[];

    for (int i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final upper = raw.toUpperCase();

      bool isNumericLabel = false;
      for (final kl in numericLabelKeywords) {
        if (upper.contains(kl)) {
          isNumericLabel = true;
          break;
        }
      }
      bool isTargetLabel = false;
      for (final kw in upperKeywords) {
        if (upper.contains(kw)) {
          isTargetLabel = true;
          break;
        }
      }

      final hasDigit = numberRe.hasMatch(raw);

      if (isNumericLabel && !hasDigit) {
        labelIdxList.add(i);
        if (isTargetLabel) targetLabelIdx = labelIdxList.length - 1;
        continue;
      }

      // Value-only line: setelah strip "Rp"/"Rp.", isinya hanya digit/koma/
      // titik/spasi dan minimal ada 1 digit. Tolak line dengan separator
      // non-numeric ("/", ":") yang biasanya tanggal/jam.
      if (!isNumericLabel) {
        final cleaned = raw.replaceAll(
          RegExp(r'[Rr][Pp]\.?', caseSensitive: false),
          '',
        );
        if (RegExp(r'^[\d.,\s]+$').hasMatch(cleaned) &&
            numberRe.hasMatch(cleaned)) {
          valueIdxList.add(i);
        }
      }
    }

    if (targetLabelIdx != null &&
        targetLabelIdx < valueIdxList.length &&
        labelIdxList.isNotEmpty) {
      final vIdx = valueIdxList[targetLabelIdx];
      final firstLabelIdx = labelIdxList.first;
      // Value harus muncul setelah blok label dimulai (toleransi minor).
      if (vIdx > firstLabelIdx - math.min(labelIdxList.length, 3)) {
        return lines[vIdx].trim();
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Number helpers
  // ---------------------------------------------------------------------------

  /// Parse angka dengan format Indonesia atau English.
  ///
  /// Aturan:
  /// - Jika punya `,` dan `.`, separator terakhir adalah desimal.
  ///   "1.234,56" -> 1234.56  (Indonesia)
  ///   "1,234.56" -> 1234.56  (English)
  /// - Jika hanya `,` dan bagian setelahnya 1-2 digit -> desimal Indonesia.
  ///   Lainnya -> thousands separator.
  /// - Jika hanya `.` dan bagian setelahnya 1-2 digit -> desimal English.
  ///   Lainnya -> thousands separator Indonesia.
  static double? parseIndonesianNumber(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && hasDot) {
      final lastComma = s.lastIndexOf(',');
      final lastDot = s.lastIndexOf('.');
      if (lastComma > lastDot) {
        return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
      } else {
        return double.tryParse(s.replaceAll(',', ''));
      }
    } else if (hasComma) {
      final parts = s.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        return double.tryParse(s.replaceAll(',', '.'));
      } else {
        return double.tryParse(s.replaceAll(',', ''));
      }
    } else if (hasDot) {
      final parts = s.split('.');
      if (parts.length == 2 && parts[1].length <= 2) {
        return double.tryParse(s);
      } else {
        return double.tryParse(s.replaceAll('.', ''));
      }
    }
    return double.tryParse(s);
  }

  static String? _extractFirstNumber(String s) {
    final m = RegExp(r'\d[\d.,]*').firstMatch(s);
    return m?.group(0);
  }

  static String _capitalize(String s) {
    return s
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0] + w.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
