// Service untuk memprediksi tanggal pengisian BBM berikutnya
//
// Pendekatan utama: statistical interval-based
//   - Hitung interval (hari) antar transaksi berturut-turut
//   - avgInterval = weighted mean (transaksi terbaru bobot lebih tinggi)
//   - predictedDate = tanggal pengisian terakhir + avgInterval
//
// Pendekatan sekunder (opsional, jika ada odometer + kapasitas tangki):
//   - avgLitersPerDay = total liter dalam window terkini / jumlah hari window
//   - daysToEmpty = tankCapacity / avgLitersPerDay
//   - cross-check terhadap interval-based untuk meningkatkan confidence
//
// Confidence dihitung dari coefficient of variation (CV = stdDev / mean):
//   confidence = clamp(1 - CV, 0, 1)
// CV rendah → pola konsisten → confidence tinggi.

import 'dart:math' as math;
import '../models/fuel_transaction.dart';
import '../models/vehicle.dart';

enum PredictionStatus {
  /// Masih jauh (>3 hari)
  upcoming,

  /// Segera (≤3 hari)
  soon,

  /// Sudah melewati prediksi
  overdue,

  /// Data belum cukup (<2 transaksi)
  insufficientData,
}

class FuelPredictionResult {
  /// Tanggal prediksi pengisian berikutnya
  final DateTime? predictedDate;

  /// Hari tersisa hingga prediksi (negatif = sudah lewat)
  final int? daysRemaining;

  /// Hari sejak pengisian terakhir
  final int? daysSinceLastRefuel;

  /// Rata-rata interval (hari) antar pengisian — weighted
  final double? avgIntervalDays;

  /// Confidence 0..1 berdasarkan konsistensi pola
  final double confidence;

  /// Status prediksi (untuk pewarnaan UI)
  final PredictionStatus status;

  /// Penjelasan singkat / disclaimer untuk ditampilkan di UI
  final String? reason;

  /// Estimasi liter rata-rata per hari (opsional)
  final double? avgLitersPerDay;

  const FuelPredictionResult({
    this.predictedDate,
    this.daysRemaining,
    this.daysSinceLastRefuel,
    this.avgIntervalDays,
    this.confidence = 0,
    this.status = PredictionStatus.insufficientData,
    this.reason,
    this.avgLitersPerDay,
  });
}

class FuelPredictionService {
  /// Hitung prediksi pengisian berikutnya untuk satu kendaraan.
  ///
  /// [transactions] daftar transaksi (urutan apapun, akan di-sort internal).
  /// [vehicle] referensi kendaraan (opsional, untuk pendekatan kapasitas tangki).
  static FuelPredictionResult predict(
    List<FuelTransaction> transactions, {
    Vehicle? vehicle,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    if (transactions.length < 2) {
      return const FuelPredictionResult(
        status: PredictionStatus.insufficientData,
        reason: 'Catat minimal 2 pengisian untuk melihat prediksi',
      );
    }

    // Sort by date ASC (terlama dulu)
    final sorted = List<FuelTransaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Hitung interval (dalam hari, bisa pecahan) antar transaksi berturut-turut
    final intervals = <double>[];
    for (int i = 1; i < sorted.length; i++) {
      final diffHours = sorted[i].date.difference(sorted[i - 1].date).inHours;
      final days = diffHours / 24.0;
      // Skip interval ≤0 (data anomali, misal 2 transaksi tanggal sama)
      if (days > 0) intervals.add(days);
    }

    if (intervals.isEmpty) {
      return const FuelPredictionResult(
        status: PredictionStatus.insufficientData,
        reason: 'Interval transaksi tidak valid',
      );
    }

    // Weighted average — transaksi terbaru bobot lebih tinggi
    // bobot[i] = i+1, sehingga interval terbaru punya bobot terbesar
    double weightedSum = 0;
    double weightTotal = 0;
    for (int i = 0; i < intervals.length; i++) {
      final w = (i + 1).toDouble();
      weightedSum += intervals[i] * w;
      weightTotal += w;
    }
    final avgInterval = weightedSum / weightTotal;

    // StdDev untuk confidence (pakai mean unweighted untuk standar deviasi)
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    double variance = 0;
    for (final v in intervals) {
      variance += math.pow(v - mean, 2).toDouble();
    }
    variance = intervals.length > 1
        ? variance / (intervals.length - 1)
        : variance;
    final stdDev = math.sqrt(variance);

    // Coefficient of Variation
    final cv = mean > 0 ? stdDev / mean : 1.0;
    double confidence = (1 - cv).clamp(0.0, 1.0);

    // Bonus: kalau data <3 interval, turunkan confidence (sample kecil)
    if (intervals.length < 3) {
      confidence *= 0.7;
    }

    // Hitung prediksi
    final lastDate = sorted.last.date;
    final predictedDate = lastDate.add(
      Duration(minutes: (avgInterval * 24 * 60).round()),
    );

    final daysRemaining = predictedDate
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final daysSinceLast = today
        .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
        .inDays;

    // Tentukan status
    PredictionStatus status;
    if (daysRemaining < 0) {
      status = PredictionStatus.overdue;
    } else if (daysRemaining <= 3) {
      status = PredictionStatus.soon;
    } else {
      status = PredictionStatus.upcoming;
    }

    // Reason / penjelasan
    String reason;
    if (intervals.length < 3) {
      reason =
          'Berdasarkan ${intervals.length} interval — pola belum sepenuhnya stabil';
    } else if (cv < 0.25) {
      reason =
          'Pola pengisian sangat konsisten (~${avgInterval.toStringAsFixed(1)} hari)';
    } else if (cv < 0.5) {
      reason =
          'Rata-rata ~${avgInterval.toStringAsFixed(1)} hari antar pengisian';
    } else {
      reason =
          'Pola bervariasi — prediksi bersifat estimasi (~${avgInterval.toStringAsFixed(1)} hari)';
    }

    // Hitung avgLitersPerDay (opsional, untuk konteks tambahan)
    double? avgLitersPerDay;
    final totalSpanDays = sorted.last.date.difference(sorted.first.date).inDays;
    if (totalSpanDays > 0) {
      final totalLiters = sorted.fold<double>(0, (s, t) => s + t.liters);
      // Liter pengisian pertama tidak masuk dalam konsumsi window ini
      final consumedLiters = totalLiters - sorted.first.liters;
      if (consumedLiters > 0) {
        avgLitersPerDay = consumedLiters / totalSpanDays;
      }
    }

    // Bonus: kalau kapasitas tangki diketahui, lakukan sanity check
    // (estimasi kasar, tidak menggantikan interval-based)
    if (vehicle != null &&
        vehicle.tankCapacity > 0 &&
        avgLitersPerDay != null &&
        avgLitersPerDay > 0) {
      // Tidak mengubah predictedDate — ini hanya untuk memperkaya reason bila
      // interval sangat tidak konsisten.
      if (cv > 0.5) {
        final tankBasedDays = vehicle.tankCapacity / avgLitersPerDay;
        // Kalau tank-based prediction lebih konsisten dengan transaksi user,
        // berikan sedikit bonus confidence
        final diff = (tankBasedDays - avgInterval).abs() / avgInterval;
        if (diff < 0.3) {
          confidence = (confidence + 0.15).clamp(0.0, 1.0);
        }
      }
    }

    return FuelPredictionResult(
      predictedDate: predictedDate,
      daysRemaining: daysRemaining,
      daysSinceLastRefuel: daysSinceLast,
      avgIntervalDays: avgInterval,
      confidence: confidence,
      status: status,
      reason: reason,
      avgLitersPerDay: avgLitersPerDay,
    );
  }
}
