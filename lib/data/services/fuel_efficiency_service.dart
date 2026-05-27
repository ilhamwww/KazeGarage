// Service untuk menghitung efisiensi BBM kendaraan
// Menggunakan metode "full to full" berdasarkan odometer
// KM/L = selisih odometer / liter yang diisi
// Biaya per KM = total pengeluaran / total KM tempuh

import '../models/fuel_transaction.dart';

class FuelEfficiencyResult {
  final double avgKmPerLiter; // Rata-rata KM/L
  final double totalKm; // Total KM tempuh (odometer)
  final double totalLiters; // Total liter yang diisi
  final double totalCost; // Total biaya BBM
  final double costPerKm; // Biaya per KM
  final double? latestOdometer; // Odometer terakhir
  final int refuelCount; // Jumlah pengisian yang punya odometer
  final String? trend; // "+X.2% bulan ini" etc

  const FuelEfficiencyResult({
    this.avgKmPerLiter = 0,
    this.totalKm = 0,
    this.totalLiters = 0,
    this.totalCost = 0,
    this.costPerKm = 0,
    this.latestOdometer,
    this.refuelCount = 0,
    this.trend,
  });
}

class FuelEfficiencyService {
  /// Hitung efisiensi BBM dari daftar transaksi yang sudah diurutkan by date ASC
  /// (transaksi terlama di atas, terbaru di bawah).
  ///
  /// Menggunakan metode "full-to-full" / per-transaksi:
  ///   KM/L_i = (odo_i - odo_{i-1}) / liter_i
  ///   Cost/KM_i = totalCost_i / (odo_i - odo_{i-1})
  static FuelEfficiencyResult calculate(List<FuelTransaction> transactions) {
    if (transactions.length < 2) {
      return _singleTransactionResult(transactions);
    }

    // Sort by odometer ascending (yang paling kecil duluan)
    final sorted = List<FuelTransaction>.from(transactions)
      ..sort((a, b) {
        if (a.odometer == null && b.odometer == null) {
          return a.date.compareTo(b.date);
        }
        if (a.odometer == null) return 1;
        if (b.odometer == null) return -1;
        return a.odometer!.compareTo(b.odometer!);
      });

    double totalKm = 0;
    double totalLiters = 0;
    double totalCost = 0;
    double sumKmPerLiter = 0;
    double sumCostPerKm = 0;
    int efficiencyReadings = 0;
    double? latestOdometer;
    double? latestKmPerLiter;

    // Cari odometer awal (yang pertama)
    for (final t in sorted) {
      if (t.odometer != null) {
        latestOdometer = t.odometer;
        break;
      }
    }

    FuelTransaction? prevOdoTransaction;
    for (final t in sorted) {
      totalLiters += t.liters;
      totalCost += t.totalCost;

      if (t.odometer != null) {
        latestOdometer = t.odometer;

        if (prevOdoTransaction != null && prevOdoTransaction.odometer != null) {
          final distance = t.odometer! - prevOdoTransaction.odometer!;
          if (distance > 0 && t.liters > 0) {
            final kmPerLiter = distance / t.liters;
            final costPerKm = t.totalCost > 0 ? t.totalCost / distance : 0;

            sumKmPerLiter += kmPerLiter;
            sumCostPerKm += costPerKm;
            efficiencyReadings++;
            totalKm += distance;
            latestKmPerLiter = kmPerLiter;
          }
        }
        prevOdoTransaction = t;
      }
    }

    final avgKmPerLiter = efficiencyReadings > 0
        ? sumKmPerLiter / efficiencyReadings
        : 0.0;
    final avgCostPerKm = efficiencyReadings > 0
        ? sumCostPerKm / efficiencyReadings
        : 0.0;

    // Calculate trend
    String? trend;
    if (latestKmPerLiter != null && avgKmPerLiter > 0) {
      final diffPercent =
          ((latestKmPerLiter - avgKmPerLiter) / avgKmPerLiter) * 100;
      if (diffPercent.abs() > 0.5) {
        trend =
            '${diffPercent >= 0 ? '+' : ''}${diffPercent.toStringAsFixed(1)}% bulan ini';
      }
    }

    return FuelEfficiencyResult(
      avgKmPerLiter: avgKmPerLiter,
      totalKm: totalKm,
      totalLiters: totalLiters,
      totalCost: totalCost,
      costPerKm: avgCostPerKm,
      latestOdometer: latestOdometer,
      refuelCount: efficiencyReadings,
      trend: trend,
    );
  }

  static FuelEfficiencyResult _singleTransactionResult(
    List<FuelTransaction> transactions,
  ) {
    if (transactions.isEmpty) return const FuelEfficiencyResult();
    final t = transactions.first;
    return FuelEfficiencyResult(
      totalLiters: t.liters,
      totalCost: t.totalCost,
      latestOdometer: t.odometer,
      refuelCount: t.odometer != null ? 1 : 0,
    );
  }
}
