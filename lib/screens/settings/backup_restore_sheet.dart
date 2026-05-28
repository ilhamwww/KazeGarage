// Bottom sheet untuk Backup & Restore data KazeGarage
// Menyediakan 2 layer perlindungan data:
// 1. Auto Backup Android (otomatis ke Google Drive, dijelaskan via info card)
// 2. Manual Export/Import file .kazegarage di internal storage HP

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaze_notifier.dart';
import '../../data/services/backup_service.dart';
import '../../providers/service_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/vehicle_provider.dart';

class BackupRestoreSheet extends StatefulWidget {
  const BackupRestoreSheet({super.key});

  @override
  State<BackupRestoreSheet> createState() => _BackupRestoreSheetState();
}

class _BackupRestoreSheetState extends State<BackupRestoreSheet> {
  final BackupService _service = BackupService();
  bool _isWorking = false;
  List<File> _savedBackups = [];
  String? _backupDirPath;
  bool _hasStoragePermission = false;

  @override
  void initState() {
    super.initState();
    _loadSavedBackups();
  }

  Future<void> _loadSavedBackups() async {
    final perm = await _service.hasStoragePermission();
    final dir = await _service.getBackupDirectory();
    final files = await _service.listBackupFiles();
    if (!mounted) return;
    setState(() {
      _hasStoragePermission = perm;
      _backupDirPath = dir.path;
      _savedBackups = files;
    });
  }

  Future<void> _handleRequestPermission() async {
    final granted = await _service.requestStoragePermission();
    if (!mounted) return;
    if (granted) {
      KazeNotifier.success(context, 'Izin storage diberikan');
    } else {
      KazeNotifier.info(
        context,
        'Izin belum diberikan. Aktifkan "All files access" di Settings.',
      );
    }
    await _loadSavedBackups();
  }

  Future<void> _handleExport() async {
    setState(() => _isWorking = true);
    final result = await _service.exportToFile();
    if (!mounted) return;
    setState(() => _isWorking = false);

    if (!result.success) {
      KazeNotifier.error(context, result.message ?? 'Gagal mengekspor data');
      return;
    }

    KazeNotifier.success(
      context,
      'Backup tersimpan: ${result.vehicleCount} kendaraan, ${result.transactionCount} transaksi',
    );
    await _loadSavedBackups();
  }

  Future<void> _handleShare(File file) async {
    await _service.shareBackupFile(file.path);
  }

  Future<void> _handleImportFromPicker() async {
    try {
      setState(() => _isWorking = true);
      final parsed = await _service.pickAndParseBackup();
      if (!mounted) return;
      setState(() => _isWorking = false);

      if (parsed == null) return; // user cancelled

      await _confirmAndApplyRestore(
        vehicleCount: parsed.vehicles.length,
        transactionCount: parsed.transactions.length,
        exportedAt: parsed.exportedAt,
        applyFn: () => _service.applyRestore(
          vehicles: parsed.vehicles,
          transactions: parsed.transactions,
          serviceRecords: parsed.serviceRecords,
          strategy: RestoreStrategy.replace,
        ),
        applyFnMerge: () => _service.applyRestore(
          vehicles: parsed.vehicles,
          transactions: parsed.transactions,
          serviceRecords: parsed.serviceRecords,
          strategy: RestoreStrategy.merge,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      KazeNotifier.error(context, 'Error: $e');
    }
  }

  Future<void> _handleRestoreFromSaved(File file) async {
    try {
      setState(() => _isWorking = true);
      final parsed = await _service.parseBackupFile(file);
      if (!mounted) return;
      setState(() => _isWorking = false);

      await _confirmAndApplyRestore(
        vehicleCount: parsed.vehicles.length,
        transactionCount: parsed.transactions.length,
        exportedAt: parsed.exportedAt,
        applyFn: () => _service.applyRestore(
          vehicles: parsed.vehicles,
          transactions: parsed.transactions,
          serviceRecords: parsed.serviceRecords,
          strategy: RestoreStrategy.replace,
        ),
        applyFnMerge: () => _service.applyRestore(
          vehicles: parsed.vehicles,
          transactions: parsed.transactions,
          serviceRecords: parsed.serviceRecords,
          strategy: RestoreStrategy.merge,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      KazeNotifier.error(context, 'Error: $e');
    }
  }

  Future<void> _confirmAndApplyRestore({
    required int vehicleCount,
    required int transactionCount,
    required String exportedAt,
    required Future<BackupResult> Function() applyFn,
    required Future<BackupResult> Function() applyFnMerge,
  }) async {
    final strategy = await _showRestoreDialog(
      vehicleCount: vehicleCount,
      transactionCount: transactionCount,
      exportedAt: exportedAt,
    );
    if (strategy == null || !mounted) return;

    setState(() => _isWorking = true);
    final result = strategy == RestoreStrategy.replace
        ? await applyFn()
        : await applyFnMerge();
    if (!mounted) return;
    setState(() => _isWorking = false);

    if (!result.success) {
      KazeNotifier.error(context, result.message ?? 'Gagal memulihkan data');
      return;
    }

    await context.read<VehicleProvider>().loadVehicles();
    if (!mounted) return;
    await context.read<TransactionProvider>().loadTransactions();
    if (!mounted) return;
    await context.read<ServiceProvider>().loadRecords();
    if (!mounted) return;

    KazeNotifier.success(
      context,
      'Berhasil memulihkan ${result.vehicleCount} kendaraan & ${result.transactionCount} transaksi',
    );
    Navigator.of(context).pop();
  }

  Future<RestoreStrategy?> _showRestoreDialog({
    required int vehicleCount,
    required int transactionCount,
    required String exportedAt,
  }) {
    String dateLabel = '-';
    try {
      final dt = DateTime.parse(exportedAt);
      dateLabel = DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {}

    return showDialog<RestoreStrategy>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Pulihkan Data',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogRow(label: 'Tanggal backup', value: dateLabel),
              const SizedBox(height: 4),
              _DialogRow(label: 'Kendaraan', value: '$vehicleCount unit'),
              const SizedBox(height: 4),
              _DialogRow(label: 'Transaksi', value: '$transactionCount entri'),
              const SizedBox(height: 14),
              const Text(
                'Pilih cara memulihkan:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, RestoreStrategy.merge),
              child: const Text('Gabungkan'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () => Navigator.pop(ctx, RestoreStrategy.replace),
              child: const Text('Ganti Semua'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
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
                      Icons.cloud_sync_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backup & Pulihkan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Lindungi data dari kehilangan',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Info Auto Backup
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 18,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto Backup Aktif',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Android otomatis membackup data ke Google Drive (saat HP charging + WiFi). Data akan otomatis pulih saat aplikasi di-install ulang.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Manual section header
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'BACKUP MANUAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              // Permission warning kalau belum granted
              if (!_hasStoragePermission)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Aktifkan akses storage agar backup tersimpan di folder Download HP (survives uninstall).',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isWorking
                              ? null
                              : _handleRequestPermission,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.warning,
                          ),
                          icon: const Icon(Icons.lock_open_rounded, size: 18),
                          label: const Text('Beri Izin Storage'),
                        ),
                      ),
                    ],
                  ),
                ),

              // Folder info
              if (_backupDirPath != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lokasi penyimpanan',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _backupDirPath!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Export action
              _ActionTile(
                icon: Icons.upload_file_outlined,
                iconColor: AppColors.primary,
                title: 'Buat Backup Sekarang',
                subtitle:
                    'Simpan file .kazegarage ke internal storage HP. File otomatis disertakan dalam Auto Backup.',
                disabled: _isWorking,
                onTap: _handleExport,
              ),
              const SizedBox(height: 10),
              // Import from picker
              _ActionTile(
                icon: Icons.download_outlined,
                iconColor: AppColors.accent,
                title: 'Pulihkan dari File Lain',
                subtitle:
                    'Pilih file .kazegarage dari Drive, email, atau folder lain',
                disabled: _isWorking,
                onTap: _handleImportFromPicker,
              ),

              const SizedBox(height: 18),

              // Saved backups list
              if (_savedBackups.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'BACKUP TERSIMPAN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ..._savedBackups.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SavedBackupTile(
                      file: f,
                      disabled: _isWorking,
                      onRestore: () => _handleRestoreFromSaved(f),
                      onShare: () => _handleShare(f),
                    ),
                  ),
                ),
              ],

              if (_isWorking) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2,
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disabled;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedBackupTile extends StatelessWidget {
  final File file;
  final bool disabled;
  final VoidCallback onRestore;
  final VoidCallback onShare;

  const _SavedBackupTile({
    required this.file,
    required this.disabled,
    required this.onRestore,
    required this.onShare,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final stat = file.statSync();
    final fileName = file.uri.pathSegments.last;
    final dateLabel = DateFormat(
      'd MMM yyyy, HH:mm',
      'id_ID',
    ).format(stat.modified);
    final sizeLabel = _formatSize(stat.size);

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateLabel · $sizeLabel',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Share button
            IconButton(
              tooltip: 'Bagikan',
              icon: const Icon(
                Icons.share_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: disabled ? null : onShare,
              visualDensity: VisualDensity.compact,
            ),
            // Restore button
            IconButton(
              tooltip: 'Pulihkan',
              icon: const Icon(
                Icons.restore_rounded,
                size: 20,
                color: AppColors.accent,
              ),
              onPressed: disabled ? null : onRestore,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
