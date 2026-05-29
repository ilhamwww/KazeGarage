// Modal popup "Versi Baru Tersedia".
//
// Ditampilkan saat UpdateService menemukan versi yang lebih baru di GitHub
// Release. Menampilkan perbandingan versi, catatan rilis singkat, dan tombol
// untuk membuka halaman/APK download via url_launcher.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/update_service.dart';
import '../theme/app_colors.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo info;

  /// Dipanggil saat user memilih "Nanti Saja" (untuk menyimpan versi skip).
  final VoidCallback? onDismiss;

  const UpdateDialog({super.key, required this.info, this.onDismiss});

  /// Helper untuk menampilkan dialog. Return true jika user menekan update.
  static Future<bool?> show(
    BuildContext context,
    UpdateInfo info, {
    VoidCallback? onDismiss,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: info, onDismiss: onDismiss),
    );
  }

  Future<void> _openDownload(BuildContext context) async {
    final uri = Uri.tryParse(info.downloadUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final notes = info.releaseNotes.trim();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Versi Baru Tersedia',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge perbandingan versi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'v${info.currentVersion}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                ),
                Text(
                  'v${info.latestVersion}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tersedia versi terbaru KazeGarage. Perbarui sekarang untuk mendapatkan fitur dan perbaikan terbaru.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Catatan Rilis',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: () {
            onDismiss?.call();
            Navigator.pop(context, false);
          },
          child: const Text('Nanti Saja'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => _openDownload(context),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Update Sekarang'),
        ),
      ],
    );
  }
}