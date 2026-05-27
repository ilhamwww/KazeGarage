// Bottom sheet untuk detail transaksi - edit dan hapus

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/fuel_transaction.dart';
import '../../providers/transaction_provider.dart';

class TransactionDetailSheet extends StatelessWidget {
  final FuelTransaction transaction;
  final String vehicleName;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    required this.vehicleName,
  });

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<TransactionProvider>();
              final success = await provider.deleteTransaction(transaction.id);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaksi dihapus'),
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
            // Header
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_gas_station, color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(transaction.date),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(transaction.totalCost),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // Detail rows
            _DetailRow(label: 'Jumlah Liter', value: '${transaction.liters.toStringAsFixed(2)} L'),
            const SizedBox(height: 12),
            _DetailRow(label: 'Harga per Liter', value: _formatCurrency(transaction.pricePerLiter)),
            if (transaction.fuelType != null && transaction.fuelType!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailRow(label: 'Jenis BBM', value: transaction.fuelType!),
            ],
            if (transaction.odometer != null) ...[
              const SizedBox(height: 12),
              _DetailRow(label: 'Odometer', value: '${transaction.odometer!.toStringAsFixed(0)} km'),
            ],
            if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailRow(label: 'Catatan', value: transaction.notes!),
            ],
            const SizedBox(height: 12),
            _DetailRow(label: 'ID Transaksi', value: transaction.id.substring(0, 8)),
            const SizedBox(height: 24),
            // Delete button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus Transaksi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.chartRed,
                  side: const BorderSide(color: AppColors.chartRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}