// Bottom sheet untuk detail kendaraan - edit dan hapus

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/transaction_provider.dart';
import 'add_vehicle_sheet.dart';

class VehicleDetailSheet extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleDetailSheet({super.key, required this.vehicle});

  Future<Map<String, double>> _getVehicleStats(BuildContext context) async {
    final provider = context.read<TransactionProvider>();
    final totalSpending = await provider.getTotalSpendingByVehicle(vehicle.id);
    final totalLiters = await provider.getTotalLitersByVehicle(vehicle.id);
    return {
      'spending': totalSpending,
      'liters': totalLiters,
    };
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return 'Rp${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return 'Rp${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp${amount.toStringAsFixed(0)}';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kendaraan?'),
        content: Text(
          'Semua data transaksi untuk ${vehicle.name} juga akan dihapus. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<VehicleProvider>();
              final success = await provider.deleteVehicle(vehicle.id);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kendaraan dihapus'),
                    backgroundColor: AppColors.chartRed,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.chartRed),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.directions_car, color: AppColors.accent, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          vehicle.licensePlate,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _InfoRow(icon: Icons.local_gas_station, label: 'Kapasitas Tangki', value: '${vehicle.tankCapacity.toStringAsFixed(0)} Liter'),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Ditambahkan',
              value: '${vehicle.createdAt.day}/${vehicle.createdAt.month}/${vehicle.createdAt.year}',
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, double>>(
              future: _getVehicleStats(context),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final stats = snapshot.data!;
                return Column(
                  children: [
                    const Divider(height: 24),
                    _InfoRow(icon: Icons.payments, label: 'Total Pengeluaran', value: _formatCurrency(stats['spending']!)),
                    const SizedBox(height: 12),
                    _InfoRow(icon: Icons.water_drop, label: 'Total Liter', value: '${stats['liters']!.toStringAsFixed(1)} L'),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => AddVehicleSheet(vehicle: vehicle),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.chartRed,
                      side: const BorderSide(color: AppColors.chartRed),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}