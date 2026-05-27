// Dashboard Screen - Beranda KazeGarage
// Hero card "Total Fuel Cost", volume statistik, efisiensi BBM mingguan,
// dan aktivitas terakhir

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaze_app_bar.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/models/fuel_transaction.dart';
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
    await vehicleProvider.loadVehicles();
    if (!mounted) return;
    await transactionProvider.loadTransactions();
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
      appBar: const KazeAppBar(),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Volume Statistik'),
              const SizedBox(height: 12),
              _buildVolumeStats(),
              const SizedBox(height: 24),
              _buildEfficiencyChart(),
              const SizedBox(height: 24),
              _buildRecentActivityHeader(),
              const SizedBox(height: 12),
              _buildRecentActivity(),
            ],
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
              diffPercent = ((currentMonth - previousMonth) / previousMonth) * 100;
            } else if (currentMonth > 0) {
              diffPercent = 100;
            }

            return FutureBuilder<double>(
              future: provider.getTotalSpending(),
              builder: (context, totalSnap) {
                final total = totalSnap.data ?? 0.0;
                return Container(
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  diffPercent >= 0 ? Icons.trending_up : Icons.trending_down,
                                  size: 14,
                                  color: diffPercent >= 0 ? AppColors.accentLight : AppColors.success,
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

  Future<List<double>> _getCurrentAndPreviousMonthSpending(TransactionProvider provider) async {
    final monthly = await provider.getMonthlySpending();
    if (monthly.isEmpty) return [0.0, 0.0];
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prevDate = DateTime(now.year, now.month - 1, 1);
    final prevKey = '${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}';

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
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
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
                                  const labels = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
                                  final i = value.toInt();
                                  if (i < 0 || i >= labels.length) return const SizedBox();
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
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                          style: TextStyle(color: AppColors.textHint, fontSize: 12),
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
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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