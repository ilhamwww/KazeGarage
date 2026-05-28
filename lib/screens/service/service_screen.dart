// Halaman utama Pencatatan Servis kendaraan.
//
// Menampilkan list catatan servis (ganti oli, filter, busi, dll)
// dengan filter per kendaraan, info reminder berikutnya, dan
// FAB untuk menambah catatan baru.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaze_notifier.dart';
import '../../data/models/service_record.dart';
import '../../data/models/vehicle.dart';
import '../../providers/service_provider.dart';
import '../../providers/vehicle_provider.dart';
import 'add_service_sheet.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  String? _filterVehicleId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().loadRecords();
    });
  }

  void _openAddSheet({ServiceRecord? record}) {
    final vehicles = context.read<VehicleProvider>().vehicles;
    if (vehicles.isEmpty && record == null) {
      KazeNotifier.info(
        context,
        'Tambahkan kendaraan di Garasi terlebih dahulu',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AddServiceSheet(record: record, initialVehicleId: _filterVehicleId),
    );
  }

  Future<void> _confirmDelete(ServiceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Catatan Servis?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Catatan ini akan dihapus permanen.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await context.read<ServiceProvider>().deleteRecord(record.id);
      if (mounted) {
        if (ok) {
          KazeNotifier.success(context, 'Catatan dihapus');
        } else {
          KazeNotifier.error(context, 'Gagal menghapus catatan');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = context.watch<VehicleProvider>().vehicles;
    final provider = context.watch<ServiceProvider>();
    final allRecords = provider.records;
    final records = _filterVehicleId == null
        ? allRecords
        : allRecords.where((r) => r.vehicleId == _filterVehicleId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pencatatan Servis',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pantau riwayat & jadwal servis kendaraan',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tombol tambah
                  Material(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openAddSheet(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 18),
                            SizedBox(width: 4),
                            Text(
                              'Catat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter chip per kendaraan
            if (vehicles.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _filterChip(
                      label: 'Semua',
                      isActive: _filterVehicleId == null,
                      onTap: () => setState(() => _filterVehicleId = null),
                    ),
                    ...vehicles.map(
                      (v) => _filterChip(
                        label: v.name,
                        isActive: _filterVehicleId == v.id,
                        onTap: () => setState(() => _filterVehicleId = v.id),
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: provider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : records.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: () =>
                          context.read<ServiceProvider>().loadRecords(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                        itemCount: records.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final r = records[i];
                          final vehicle = vehicles.firstWhere(
                            (v) => v.id == r.vehicleId,
                            orElse: () => Vehicle(
                              id: '',
                              name: 'Kendaraan dihapus',
                              licensePlate: '-',
                              tankCapacity: 0,
                            ),
                          );
                          return _ServiceCard(
                            record: r,
                            vehicle: vehicle,
                            onEdit: () => _openAddSheet(record: r),
                            onDelete: () => _confirmDelete(r),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.build_outlined,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum Ada Catatan Servis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Catat semua aktivitas servis seperti ganti oli, filter, busi untuk pantau jadwal & biaya kendaraan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openAddSheet(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Catatan Pertama'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceRecord record;
  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.record,
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatCurrency(double v) {
    final f = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return f.format(v);
  }

  /// Status reminder berikutnya: text + warna.
  ({String label, Color color, IconData icon})? _reminderStatus() {
    if (record.nextDueDate == null && record.nextDueOdometer == null) {
      return null;
    }
    final now = DateTime.now();
    String? dateLabel;
    Color color = AppColors.success;
    IconData icon = Icons.check_circle_outline;

    if (record.nextDueDate != null) {
      final diff = record.nextDueDate!.difference(now).inDays;
      if (diff < 0) {
        dateLabel = 'Telat ${diff.abs()} hari';
        color = AppColors.error;
        icon = Icons.warning_amber_rounded;
      } else if (diff <= 7) {
        dateLabel = 'Sisa $diff hari';
        color = AppColors.warning;
        icon = Icons.access_time_rounded;
      } else if (diff <= 30) {
        dateLabel = 'Sisa $diff hari';
        color = AppColors.warning;
        icon = Icons.access_time_rounded;
      } else {
        dateLabel = DateFormat(
          'd MMM yyyy',
          'id_ID',
        ).format(record.nextDueDate!);
      }
    }

    String? kmLabel;
    if (record.nextDueOdometer != null) {
      kmLabel = '@${record.nextDueOdometer!.toStringAsFixed(0)} km';
    }

    final parts = [
      if (dateLabel != null) dateLabel,
      if (kmLabel != null) kmLabel,
    ];
    return (label: parts.join(' • '), color: color, icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    final reminder = _reminderStatus();
    final dateLabel = DateFormat('d MMM yyyy', 'id_ID').format(record.date);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.build_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.serviceType,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${vehicle.name} • ${vehicle.licensePlate}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Detail pills
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _pill(icon: Icons.event_outlined, label: dateLabel),
                    _pill(
                      icon: Icons.speed_rounded,
                      label: '${record.odometer.toStringAsFixed(0)} km',
                    ),
                    if (record.cost != null)
                      _pill(
                        icon: Icons.payments_outlined,
                        label: _formatCurrency(record.cost!),
                      ),
                    if (record.location != null && record.location!.isNotEmpty)
                      _pill(
                        icon: Icons.location_on_outlined,
                        label: record.location!,
                      ),
                  ],
                ),
                if (reminder != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: reminder.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(reminder.icon, size: 14, color: reminder.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Berikutnya: ${reminder.label}',
                            style: TextStyle(
                              fontSize: 11,
                              color: reminder.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (record.notes != null && record.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    record.notes!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
