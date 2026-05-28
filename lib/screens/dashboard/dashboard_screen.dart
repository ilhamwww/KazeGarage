// Dashboard Screen - Beranda KazeGarage
// Hero card "Total Fuel Cost", volume statistik, efisiensi BBM mingguan,
// dan aktivitas terakhir

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/fuel_price_provider.dart';
import '../../data/models/fuel_transaction.dart';
import '../../data/models/fuel_price.dart';
import '../../data/models/vehicle.dart';
import '../../data/services/fuel_prediction_service.dart';
import '../history/history_screen.dart';
import '../history/transaction_detail_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAllHistory;

  const DashboardScreen({super.key, this.onSeeAllHistory});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final vehicleProvider = context.read<VehicleProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final fuelPriceProvider = context.read<FuelPriceProvider>();
    await vehicleProvider.loadVehicles();
    if (!mounted) return;
    await transactionProvider.loadTransactions();
    if (!mounted) return;
    // Fire-and-forget; UI menampilkan loading state sendiri
    fuelPriceProvider.loadPrices();
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    return formatter.format(amount).trim();
  }

  String _formatCurrencyShort(double amount) {
    if (amount >= 1000000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}k';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}k';
    }
    return 'Rp ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('Prediksi Pengisian Berikutnya'),
                const SizedBox(height: 12),
                _buildPredictionSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Statistik Harga'),
                const SizedBox(height: 12),
                _buildPriceStats(),
                const SizedBox(height: 24),
                _buildSectionTitle('Volume Statistik'),
                const SizedBox(height: 12),
                _buildVolumeStats(),
                const SizedBox(height: 24),
                _buildEfficiencyChart(),
                const SizedBox(height: 24),
                _buildFuelPricesHeader(),
                const SizedBox(height: 12),
                _buildFuelPricesSection(),
                const SizedBox(height: 24),
                _buildRecentActivityHeader(),
                const SizedBox(height: 12),
                _buildRecentActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ====== HERO CARD ======
  Widget _buildHeroCard() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        return FutureBuilder<List<double>>(
          future: _getCurrentAndPreviousMonthSpending(provider),
          builder: (context, snapshot) {
            final data = snapshot.data ?? [0.0, 0.0];
            final currentMonth = data[0];
            final previousMonth = data[1];
            double diffPercent = 0;
            if (previousMonth > 0) {
              diffPercent =
                  ((currentMonth - previousMonth) / previousMonth) * 100;
            } else if (currentMonth > 0) {
              diffPercent = 100;
            }

            return FutureBuilder<double>(
              future: provider.getTotalSpending(),
              builder: (context, totalSnap) {
                final total = totalSnap.data ?? 0.0;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Icon decoration
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white54,
                            size: 28,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL FUEL COST',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatCurrency(total),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  diffPercent >= 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 14,
                                  color: diffPercent >= 0
                                      ? AppColors.accentLight
                                      : AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${diffPercent >= 0 ? '+' : ''}${diffPercent.toStringAsFixed(0)}% dari bulan lalu',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<double>> _getCurrentAndPreviousMonthSpending(
    TransactionProvider provider,
  ) async {
    final monthly = await provider.getMonthlySpending();
    if (monthly.isEmpty) return [0.0, 0.0];
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prevDate = DateTime(now.year, now.month - 1, 1);
    final prevKey =
        '${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}';

    double current = 0;
    double previous = 0;
    for (final m in monthly) {
      final key = m['month'] as String;
      final total = (m['total'] as num).toDouble();
      if (key == currentKey) current = total;
      if (key == prevKey) previous = total;
    }
    return [current, previous];
  }

  // ====== PREDICTION SECTION ======
  Widget _buildPredictionSection() {
    return Consumer2<TransactionProvider, VehicleProvider>(
      builder: (context, txProvider, vehicleProvider, _) {
        final vehicles = vehicleProvider.vehicles;

        if (vehicles.isEmpty) {
          return _PredictionEmptyState(
            icon: Icons.directions_car_outlined,
            message:
                'Tambahkan kendaraan terlebih dahulu untuk melihat prediksi pengisian',
          );
        }

        // Hitung prediksi per kendaraan, hanya yang punya >= 2 transaksi
        final cards = <Widget>[];
        // Prioritaskan kendaraan aktif di urutan pertama
        final orderedVehicles = [
          ...vehicles.where((v) => v.isActive),
          ...vehicles.where((v) => !v.isActive),
        ];

        for (final v in orderedVehicles) {
          final vehicleTx = txProvider.transactions
              .where((t) => t.vehicleId == v.id)
              .toList();
          final result = FuelPredictionService.predict(vehicleTx, vehicle: v);
          cards.add(_PredictionCard(vehicle: v, result: result));
        }

        if (cards.isEmpty) {
          return _PredictionEmptyState(
            icon: Icons.insights_outlined,
            message: 'Catat minimal 2 pengisian untuk mulai melihat prediksi',
          );
        }

        // Single card → full width. Multiple → horizontal scroll.
        if (cards.length == 1) {
          return cards.first;
        }
        return SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(width: 280, child: cards[i]),
          ),
        );
      },
    );
  }

  // ====== PRICE STATS ======
  Widget _buildPriceStats() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();
        double today = 0;
        double last7 = 0;
        double last30 = 0;
        // Untuk rata-rata harga/liter
        double sumPrice = 0;
        int countPrice = 0;
        double? minPrice;
        double? maxPrice;

        for (final t in provider.transactions) {
          final daysAgo = now.difference(t.date).inDays;
          if (_isSameDay(t.date, now)) today += t.totalCost;
          if (daysAgo < 7) last7 += t.totalCost;
          if (daysAgo < 30) {
            last30 += t.totalCost;
            // Statistik harga/liter dalam 30 hari terakhir
            if (t.pricePerLiter > 0) {
              sumPrice += t.pricePerLiter;
              countPrice++;
              if (minPrice == null || t.pricePerLiter < minPrice) {
                minPrice = t.pricePerLiter;
              }
              if (maxPrice == null || t.pricePerLiter > maxPrice) {
                maxPrice = t.pricePerLiter;
              }
            }
          }
        }
        final avgPrice = countPrice > 0 ? sumPrice / countPrice : 0.0;

        return Column(
          children: [
            // Row 1: pengeluaran per periode
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _PriceStatChip(
                    label: 'HARI INI',
                    value: today,
                    isHighlighted: false,
                  ),
                  const SizedBox(width: 10),
                  _PriceStatChip(
                    label: '7 HARI',
                    value: last7,
                    isHighlighted: false,
                  ),
                  const SizedBox(width: 10),
                  _PriceStatChip(
                    label: '30 HARI',
                    value: last30,
                    isHighlighted: true,
                  ),
                ],
              ),
            ),
            // Row 2: ringkasan harga per liter (30 hari)
            if (countPrice > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PricePerLiterMetric(
                        label: 'TERENDAH',
                        value: minPrice ?? 0,
                        color: AppColors.success,
                      ),
                    ),
                    Container(width: 1, height: 32, color: AppColors.divider),
                    Expanded(
                      child: _PricePerLiterMetric(
                        label: 'RATA-RATA',
                        value: avgPrice,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(width: 1, height: 32, color: AppColors.divider),
                    Expanded(
                      child: _PricePerLiterMetric(
                        label: 'TERTINGGI',
                        value: maxPrice ?? 0,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ====== VOLUME STATS ======
  Widget _buildVolumeStats() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();
        double today = 0;
        double last7 = 0;
        double last30 = 0;

        for (final t in provider.transactions) {
          final daysAgo = now.difference(t.date).inDays;
          if (_isSameDay(t.date, now)) today += t.liters;
          if (daysAgo < 7) last7 += t.liters;
          if (daysAgo < 30) last30 += t.liters;
        }

        return SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _StatChip(label: 'HARI INI', value: today, isHighlighted: false),
              const SizedBox(width: 10),
              _StatChip(label: '7 HARI', value: last7, isHighlighted: false),
              const SizedBox(width: 10),
              _StatChip(label: '30 HARI', value: last30, isHighlighted: true),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ====== EFFICIENCY CHART ======
  Widget _buildEfficiencyChart() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final dailyData = _getLast7DaysLiters(provider.transactions);
        final maxValue = dailyData.fold<double>(0, (a, b) => b > a ? b : a);
        final hasData = maxValue > 0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Efisiensi Bahan Bakar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 130,
                child: hasData
                    ? BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxValue * 1.3,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                                '${r.toY.toStringAsFixed(1)}L',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  const labels = [
                                    'SEN',
                                    'SEL',
                                    'RAB',
                                    'KAM',
                                    'JUM',
                                    'SAB',
                                    'MIN',
                                  ];
                                  final i = value.toInt();
                                  if (i < 0 || i >= labels.length) {
                                    return const SizedBox();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      labels[i],
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: List.generate(7, (i) {
                            final v = dailyData[i];
                            // Find max-2 largest as accent (simple heuristic)
                            final isAccent = v >= maxValue * 0.85;
                            final isPrimary = v >= maxValue * 0.65 && !isAccent;
                            Color color;
                            if (isAccent) {
                              color = AppColors.accent;
                            } else if (isPrimary) {
                              color = AppColors.primary;
                            } else {
                              color = AppColors.primary.withValues(alpha: 0.12);
                            }
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: v == 0 ? maxValue * 0.08 : v,
                                  color: v == 0 ? AppColors.divider : color,
                                  width: 20,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Belum ada data minggu ini',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns liters per day for the last 7 days, indexed by Monday=0..Sunday=6
  List<double> _getLast7DaysLiters(List<FuelTransaction> transactions) {
    final result = List<double>.filled(7, 0);
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayDate = DateTime(monday.year, monday.month, monday.day);

    for (final t in transactions) {
      final tDate = DateTime(t.date.year, t.date.month, t.date.day);
      final diff = tDate.difference(mondayDate).inDays;
      if (diff >= 0 && diff < 7) {
        result[diff] += t.liters;
      }
    }
    return result;
  }

  // ====== FUEL PRICES ======
  Widget _buildFuelPricesHeader() {
    return Consumer<FuelPriceProvider>(
      builder: (context, provider, _) {
        return Row(
          children: [
            const Expanded(
              child: Text(
                'Harga BBM Terbaru',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (provider.data != null)
              Text(
                provider.data!.updateDate,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => provider.loadPrices(force: true),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  provider.isLoading ? Icons.hourglass_empty : Icons.refresh,
                  size: 14,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFuelPricesSection() {
    return Consumer<FuelPriceProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.data == null) {
          return Container(
            height: 130,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
          );
        }
        if (provider.data == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.textHint,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  provider.errorMessage ?? 'Gagal memuat harga BBM',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => provider.loadPrices(force: true),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        }
        // Kumpulkan semua brand unik dari gasoline + diesel
        final brandSet = <String>{};
        for (final b in provider.data!.gasoline) {
          brandSet.add(b.brand);
        }
        for (final b in provider.data!.diesel) {
          brandSet.add(b.brand);
        }
        final brands = brandSet.toList();

        return SizedBox(
          height: 320,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: brands.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final brand = brands[i];
              final gas = provider.data!.gasoline
                  .firstWhere(
                    (b) => b.brand == brand,
                    orElse: () => FuelBrandPrices(brand: brand, items: []),
                  )
                  .items;
              final diesel = provider.data!.diesel
                  .firstWhere(
                    (b) => b.brand == brand,
                    orElse: () => FuelBrandPrices(brand: brand, items: []),
                  )
                  .items;
              return _BrandPriceCard(
                brand: brand,
                gasolineItems: gas,
                dieselItems: diesel,
              );
            },
          ),
        );
      },
    );
  }

  // ====== RECENT ACTIVITY ======
  Widget _buildRecentActivityHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Aktivitas Terakhir',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            if (widget.onSeeAllHistory != null) {
              widget.onSeeAllHistory!();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            }
          },
          child: const Text(
            'Lihat Semua',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Consumer2<TransactionProvider, VehicleProvider>(
      builder: (context, provider, vehicleProvider, _) {
        final transactions = provider.transactions.take(3).toList();
        if (transactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 40, color: AppColors.textHint),
                  SizedBox(height: 8),
                  Text(
                    'Belum ada transaksi',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: transactions.map((t) {
            final vehicle = vehicleProvider.getVehicleById(t.vehicleId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TransactionDetailSheet(
                      transaction: t,
                      vehicleName: vehicle?.name ?? '',
                    ),
                  ).then((_) => _loadData());
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.fuelType ?? 'Pengisian BBM',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${vehicle?.name ?? 'SPBU'} - ${DateFormat('dd MMM HH:mm').format(t.date)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrencyShort(t.totalCost),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${t.liters.toStringAsFixed(1)}L',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _BrandPriceCard extends StatelessWidget {
  final String brand;
  final List<FuelPriceItem> gasolineItems;
  final List<FuelPriceItem> dieselItems;

  const _BrandPriceCard({
    required this.brand,
    required this.gasolineItems,
    required this.dieselItems,
  });

  String _formatPrice(double? price) {
    if (price == null || price <= 0) return '-';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  Color _brandColor() {
    switch (brand.toLowerCase()) {
      case 'pertamina':
        return const Color(0xFFE63946);
      case 'shell':
        return const Color(0xFFFFD60A);
      case 'bp':
        return const Color(0xFF00A651);
      case 'vivo':
        return const Color(0xFF0066CC);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _brandColor();

    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_gas_station, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    brand,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Gasoline section
            if (gasolineItems.isNotEmpty) ...[
              _buildSectionLabel('BENSIN', 'RON', color),
              const SizedBox(height: 6),
              ...gasolineItems.map(
                (item) => _buildPriceRow(item, 'RON', color),
              ),
            ],
            if (gasolineItems.isNotEmpty && dieselItems.isNotEmpty)
              const SizedBox(height: 8),
            // Diesel section
            if (dieselItems.isNotEmpty) ...[
              _buildSectionLabel('DIESEL', 'CN', color),
              const SizedBox(height: 6),
              ...dieselItems.map((item) => _buildPriceRow(item, 'CN', color)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildPriceRow(FuelPriceItem item, String unit, Color color) {
    final hasPrice = item.price != null && item.price! > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // RON/CN badge
          Container(
            width: 36,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.ron,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPrice && item.productName.isNotEmpty
                      ? item.productName
                      : '$unit ${item.ron}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasPrice
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatPrice(item.price),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasPrice ? color : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceStatChip extends StatelessWidget {
  final String label;
  final double value;
  final bool isHighlighted;

  const _PriceStatChip({
    required this.label,
    required this.value,
    required this.isHighlighted,
  });

  String _formatRupiah(double v) {
    if (v >= 1000000) {
      return 'Rp ${(v / 1000000).toStringAsFixed(1)}jt';
    }
    if (v >= 1000) {
      return 'Rp ${(v / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? AppColors.accent : AppColors.divider,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? AppColors.accent : AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          Text(
            _formatRupiah(value),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PricePerLiterMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _PricePerLiterMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  String _formatRupiah(double v) {
    if (v >= 1000) {
      // Format ribuan dengan titik
      final s = v.toStringAsFixed(0);
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
        buf.write(s[i]);
      }
      return 'Rp${buf.toString()}';
    }
    return 'Rp${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatRupiah(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        const Text(
          'per liter',
          style: TextStyle(fontSize: 9, color: AppColors.textHint),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final double value;
  final bool isHighlighted;

  const _StatChip({
    required this.label,
    required this.value,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? AppColors.accent : AppColors.divider,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? AppColors.accent : AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)} L',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ====== PREDICTION CARD ======
class _PredictionCard extends StatelessWidget {
  final Vehicle vehicle;
  final FuelPredictionResult result;

  const _PredictionCard({required this.vehicle, required this.result});

  Color _statusColor() {
    switch (result.status) {
      case PredictionStatus.upcoming:
        return AppColors.success;
      case PredictionStatus.soon:
        return AppColors.warning;
      case PredictionStatus.overdue:
        return AppColors.accent;
      case PredictionStatus.insufficientData:
        return AppColors.textHint;
    }
  }

  String _statusLabel() {
    switch (result.status) {
      case PredictionStatus.upcoming:
        return 'Masih Lama';
      case PredictionStatus.soon:
        return 'Segera';
      case PredictionStatus.overdue:
        return 'Terlambat';
      case PredictionStatus.insufficientData:
        return '—';
    }
  }

  String _daysText() {
    final days = result.daysRemaining;
    if (days == null) return '—';
    if (days < 0) return '${days.abs()} hari terlambat';
    if (days == 0) return 'Hari ini';
    if (days == 1) return '~1 hari lagi';
    return '~$days hari lagi';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final isInsufficient = result.status == PredictionStatus.insufficientData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: vehicle name + status badge
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  size: 16,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      vehicle.licensePlate,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isInsufficient)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Predicted date or empty state
          if (isInsufficient)
            _buildInsufficient()
          else
            _buildPrediction(statusColor),
          const SizedBox(height: 10),
          // Reason / disclaimer + confidence
          if (result.reason != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    result.reason!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isInsufficient) ...[
                  const SizedBox(width: 8),
                  _buildConfidenceDots(result.confidence),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPrediction(Color statusColor) {
    final date = result.predictedDate!;
    final formatter = DateFormat('d MMM yyyy', 'id_ID');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatter.format(date),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _daysText(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsufficient() {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: AppColors.textHint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Belum cukup data untuk prediksi',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceDots(double confidence) {
    // Map 0..1 → 1..4 dots
    int filled;
    if (confidence >= 0.75) {
      filled = 4;
    } else if (confidence >= 0.5) {
      filled = 3;
    } else if (confidence >= 0.25) {
      filled = 2;
    } else {
      filled = 1;
    }

    Color dotColor;
    String label;
    if (filled >= 4) {
      dotColor = AppColors.success;
      label = 'Tinggi';
    } else if (filled >= 3) {
      dotColor = AppColors.primary;
      label = 'Sedang';
    } else if (filled >= 2) {
      dotColor = AppColors.warning;
      label = 'Cukup';
    } else {
      dotColor = AppColors.textHint;
      label = 'Rendah';
    }

    return Tooltip(
      message: 'Akurasi prediksi: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (i) {
          final isOn = i < filled;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn ? dotColor : AppColors.divider,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ====== PREDICTION EMPTY STATE ======
class _PredictionEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PredictionEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.textHint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
