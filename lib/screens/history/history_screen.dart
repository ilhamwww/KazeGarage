// Transaction History Screen - Log kronologis dengan filter
// Menampilkan semua transaksi dengan filter per kendaraan

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
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
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final vehicleProvider = context.read<VehicleProvider>();
    await vehicleProvider.loadVehicles();
    if (!mounted) return;
    final selectedVehicle = vehicleProvider.selectedFilterVehicle;
    await context.read<TransactionProvider>().loadTransactions(
      vehicleId: selectedVehicle?.id,
    );
  }

  void _onFilterChanged(String? vehicleId) {
    final vehicleProvider = context.read<VehicleProvider>();
    vehicleProvider.setFilterVehicle(vehicleId);
    context.read<TransactionProvider>().loadTransactions(vehicleId: vehicleId);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: [
          Consumer<VehicleProvider>(
            builder: (context, vehicleProvider, _) {
              return PopupMenuButton<String?>(
                icon: const Icon(Icons.filter_list),
                onSelected: _onFilterChanged,
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String?>>[
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text('Semua Kendaraan'),
                    ),
                  ];
                  for (final v in vehicleProvider.vehicles) {
                    items.add(PopupMenuItem<String?>(
                      value: v.id,
                      child: Text(v.name),
                    ));
                  }
                  return items;
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chip & summary
          Consumer<TransactionProvider>(
            builder: (context, provider, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.surface,
                child: Row(
                  children: [
                    Consumer<VehicleProvider>(
                      builder: (context, vp, _) {
                        final label = vp.selectedFilterVehicle?.name ?? 'Semua Kendaraan';
                        return Chip(
                          label: Text(label, style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                          side: BorderSide.none,
                        );
                      },
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${provider.transactionCount} transaksi',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          _formatCurrency(provider.displayedTotalSpending),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // Transaction list
          Expanded(
            child: Consumer2<TransactionProvider, VehicleProvider>(
              builder: (context, provider, vehicleProvider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.transactions.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.transactions.length,
                    itemBuilder: (context, index) {
                      final t = provider.transactions[index];
                      final vehicle = vehicleProvider.getVehicleById(t.vehicleId);
                      return _TransactionCard(
                        transaction: t,
                        vehicleName: vehicle?.name ?? 'Kendaraan tidak diketahui',
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
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, size: 48, color: AppColors.accent),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Transaksi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mulai catat pengeluaran BBM\nuntuk melihat riwayat di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_gas_station, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicleName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.liters.toStringAsFixed(1)}L × ${_formatCurrency(transaction.pricePerLiter)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (transaction.notes != null && transaction.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        transaction.notes!,
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(transaction.totalCost),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(transaction.date),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}