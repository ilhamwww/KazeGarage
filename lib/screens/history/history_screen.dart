// History Screen - Riwayat Transaksi
// Search bar, filter fuel type chips, dan grouping per bulan

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaze_app_bar.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/models/fuel_transaction.dart';
import 'transaction_detail_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFuelFilter = 'All';

  static const List<String> _fuelFilters = ['All', 'Pertalite', 'Pertamax', 'Pertamax Turbo', 'Solar', 'Dexlite'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    await context.read<VehicleProvider>().loadVehicles();
    if (!mounted) return;
    await context.read<TransactionProvider>().loadTransactions();
  }

  List<FuelTransaction> _applyFilters(List<FuelTransaction> transactions, VehicleProvider vp) {
    return transactions.where((t) {
      // Fuel filter
      if (_selectedFuelFilter != 'All') {
        if (t.fuelType == null) return false;
        if (!t.fuelType!.toLowerCase().contains(_selectedFuelFilter.toLowerCase())) {
          return false;
        }
      }
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final vehicle = vp.getVehicleById(t.vehicleId);
        final vehicleName = vehicle?.name.toLowerCase() ?? '';
        final fuelType = t.fuelType?.toLowerCase() ?? '';
        final notes = t.notes?.toLowerCase() ?? '';
        if (!vehicleName.contains(q) && !fuelType.contains(q) && !notes.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Group transactions by month, returning a list of (monthLabel, transactions)
  List<MapEntry<String, List<FuelTransaction>>> _groupByMonth(List<FuelTransaction> transactions) {
    final map = <String, List<FuelTransaction>>{};
    for (final t in transactions) {
      final key = DateFormat('MMMM yyyy', 'id_ID').format(t.date).toUpperCase();
      map.putIfAbsent(key, () => []).add(t);
    }
    return map.entries.toList();
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
      body: Consumer2<TransactionProvider, VehicleProvider>(
        builder: (context, provider, vehicleProvider, _) {
          final filtered = _applyFilters(provider.transactions, vehicleProvider);
          return Column(
            children: [
              // Search & filters
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                color: AppColors.surface,
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Filter chips
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _fuelFilters.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final f = _fuelFilters[i];
                          final selected = _selectedFuelFilter == f;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedFuelFilter = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Transaction list grouped by month
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            color: AppColors.accent,
                            onRefresh: _loadData,
                            child: _buildGroupedList(filtered, vehicleProvider),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupedList(List<FuelTransaction> transactions, VehicleProvider vp) {
    final groups = _groupByMonth(transactions);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: groups.length,
      itemBuilder: (context, gi) {
        final group = groups[gi];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            Padding(
              padding: EdgeInsets.only(top: gi == 0 ? 0 : 20, bottom: 12),
              child: Text(
                group.key,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            // Transactions in this month
            ...group.value.map((t) {
              final vehicle = vp.getVehicleById(t.vehicleId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionCard(
                  transaction: t,
                  vehicleName: vehicle?.name ?? 'Kendaraan',
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
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, size: 40, color: AppColors.textHint),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum Ada Transaksi',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mulai catat pengeluaran BBM\nuntuk melihat riwayat di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final FuelTransaction transaction;
  final String vehicleName;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.transaction,
    required this.vehicleName,
    required this.onTap,
  });

  String _formatCurrencyShort(double amount) {
    if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}.000';
    }
    return 'Rp ${amount.toStringAsFixed(0)}';
  }

  IconData _typeIcon() {
    return Icons.directions_car;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(), color: AppColors.textSecondary, size: 18),
            ),
            const SizedBox(width: 12),
            // Vehicle + fuel
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicleName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('dd MMM').format(transaction.date)} · ${transaction.fuelType ?? "BBM"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Amount + liters
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrencyShort(transaction.totalCost),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${transaction.liters.toStringAsFixed(1)} L',
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
    );
  }
}