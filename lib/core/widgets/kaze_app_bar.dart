// Shared App Bar untuk semua halaman utama KazeGarage
// Hanya menampilkan icon pengaturan di pojok kanan.
// Tap icon pengaturan membuka Backup & Restore sheet.

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../screens/settings/backup_restore_sheet.dart';

class KazeAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Override default action saat tombol pengaturan ditekan.
  /// Default-nya membuka [BackupRestoreSheet].
  final VoidCallback? onSettingsTap;

  const KazeAppBar({super.key, this.onSettingsTap});

  void _openBackupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BackupRestoreSheet(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(color: AppColors.surface),
        child: Row(
          children: [
            const Spacer(),
            // Icon Pengaturan
            GestureDetector(
              onTap: onSettingsTap ?? () => _openBackupSheet(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
