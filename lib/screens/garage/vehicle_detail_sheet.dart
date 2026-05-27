// Vehicle Detail Sheet
// Full-screen sheet yang menampilkan detail kendaraan + statistik efisiensi BBM

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaze_notifier.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/fuel_transaction.dart';
import '../../data/services/fuel_efficiency_service.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/transaction_provider.dart';
import 'add_vehicle_sheet.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late Vehicle vehicle;

  @override
  void initState() {
    super.initState();
    vehicle = widget.vehicle;
  }

  void _editVehicle() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddVehicleSheet(vehicle: vehicle),
    );
  }

  void _deleteVehicle() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Kendaraan?'),
        content: Text(
          'Semua data transaksi untuk ${vehicle.name} juga akan dihapus.',
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
              final txProvider = context.read<TransactionProvider>();
              // Hapus semua transaksi kendaraan ini
              for (final t in txProvider.transactions) {
                if (t.vehicleId == vehicle.id) {
                  await txProvider.deleteTransaction(t.id);
                }
              }
              await provider.deleteVehicle(vehicle.id);
              if (mounted) {
                Navigator.pop(context);
                KazeNotifier.success(context, 'Kendaraan dihapus');
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    color: AppColors.textPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Detail Kendaraan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          // Content
          Expanded(
            child: Consumer2<TransactionProvider, VehicleProvider>(
              builder: (context, txProvider, vehicleProvider, _) {
                final transactions =
                    txProvider.transactions
                        .where((t) => t.vehicleId == vehicle.id)
                        .toList()
                      ..sort((a, b) => a.date.compareTo(b.date));

                final efficiency = FuelEfficiencyService.calculate(
                  transactions,
                );
                final latestTransaction = transactions.isNotEmpty
                    ? transactions.last
                    : null;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  child: Column(
                    children: [
                      // Vehicle Image
                      _buildVehicleImage(),
                      const SizedBox(height: 16),

                      // Vehicle name + plate
                      _buildVehicleInfo(),
                      const SizedBox(height: 20),

                      // Efisiensi BBM hero card
                      _buildEfficiencyCard(efficiency),
                      const SizedBox(height: 16),

                      // Stats grid
                      _buildStatsGrid(efficiency, latestTransaction),
                      const SizedBox(height: 24),

                      // Pemeliharaan section
                      _buildMaintenanceSection(),
                      const SizedBox(height: 24),

                      // Edit button
                      _buildEditButton(),
                      const SizedBox(height: 12),

                      // Delete button
                      _buildDeleteButton(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon() {
    final type = (vehicle.vehicleType ?? '').toLowerCase();
    if (type.contains('motor')) return Icons.two_wheeler;
    return Icons.directions_car;
  }

  Widget _buildVehicleImage() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty
          ? _buildNetworkImage(vehicle.imageUrl!)
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildNetworkImage(String url) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => _buildPlaceholderImage(),
      );
    }
    final file = File(url);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover, width: double.infinity);
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceMuted,
            AppColors.surfaceMuted.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(_typeIcon(), size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            vehicle.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfo() {
    return Column(
      children: [
        Text(
          vehicle.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                vehicle.licensePlate,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (vehicle.vehicleType != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(_typeIcon(), size: 14, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildEfficiencyCard(FuelEfficiencyResult efficiency) {
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
                Icons.speed_rounded,
                color: Colors.white54,
                size: 28,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EFISIENSI BBM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                efficiency.refuelCount > 0
                    ? efficiency.avgKmPerLiter.toStringAsFixed(1)
                    : '--',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const Text(
                'km/L',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              if (efficiency.trend != null)
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
                        efficiency.trend!.startsWith('+')
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 14,
                        color: efficiency.trend!.startsWith('+')
                            ? AppColors.success
                            : AppColors.accentLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        efficiency.trend!,
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
  }

  Widget _buildStatsGrid(
    FuelEfficiencyResult efficiency,
    FuelTransaction? latest,
  ) {
    return Column(
      children: [
        // Row 1: Total Jarak + Total Biaya
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                icon: Icons.route,
                label: 'TOTAL JARAK',
                value: efficiency.totalKm > 0
                    ? '${efficiency.totalKm.toStringAsFixed(0).replaceAll('.', ',')} km'
                    : '--',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBlock(
                icon: Icons.payments,
                label: 'TOTAL BIAYA',
                value: efficiency.totalCost > 0
                    ? '${efficiency.totalCost >= 1000000
                          ? '${(efficiency.totalCost / 1000000).toStringAsFixed(1)}jt'
                          : efficiency.totalCost >= 1000
                          ? '${(efficiency.totalCost / 1000).toStringAsFixed(0)}rb'
                          : efficiency.totalCost.toStringAsFixed(0)} IDR'
                    : '--',
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2: Rata-rata km/L + Terakhir Isi
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                icon: Icons.speed,
                label: 'RATA-RATA km/L',
                value: efficiency.refuelCount > 0
                    ? efficiency.avgKmPerLiter.toStringAsFixed(1)
                    : '--',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBlock(
                icon: Icons.local_gas_station,
                label: 'TERAKHIR ISI',
                value: latest != null
                    ? DateFormat('dd MMM yyyy').format(latest.date)
                    : '--',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaintenanceSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pemeliharaan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildMaintenanceItem(
            Icons.build_circle_outlined,
            'Jadwal Servis',
            'Atur pengingat servis',
          ),
          const SizedBox(height: 10),
          _buildMaintenanceItem(
            Icons.description_outlined,
            'Pajak Tahunan',
            'Atur pengingat pajak',
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: _editVehicle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Text(
          'Edit Kendaraan',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _deleteVehicle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            SizedBox(width: 6),
            Text(
              'Hapus',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
