// Shared App Bar untuk semua halaman utama KazeGarage
// Menampilkan avatar, brand "KazeGarage", dan ikon notifikasi.
// Tap avatar default-nya membuka Backup & Restore sheet.

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../screens/settings/backup_restore_sheet.dart';

class KazeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;

  const KazeAppBar({super.key, this.onNotificationTap, this.onAvatarTap});

  void _openBackupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BackupRestoreSheet(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(color: AppColors.surface),
        child: Row(
          children: [
            // Avatar — default: open Backup & Restore sheet
            GestureDetector(
              onTap: onAvatarTap ?? () => _openBackupSheet(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 1),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.textOnPrimary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Brand Logo
            Image.asset(
              'assets/icon/kaze_garage_logo.png',
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'KazeGarage',
                  style: TextStyle(
                    fontFamily: 'HankenGrotesk',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                );
              },
            ),
            const Spacer(),
            // Notification
            GestureDetector(
              onTap: onNotificationTap,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
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
