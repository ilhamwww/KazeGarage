// Main Screen - Bottom navigation 5 slot dengan FAB Scan di tengah:
// [ Beranda ] [ Servis ] [ ⚡ SCAN ] [ Garasi ] [ Pengaturan ]
//
// Pengaturan = tap → buka BackupRestoreSheet.

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'dashboard/dashboard_screen.dart';
import 'garage/garage_screen.dart';
import 'history/history_screen.dart';
import 'scan/scan_receipt_screen.dart';
import 'service/service_screen.dart';
import 'settings/backup_restore_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    DashboardScreen(onSeeAllHistory: _openHistory),
    const ServiceScreen(),
    const GarageScreen(),
  ];

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  void _openScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BackupRestoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: GestureDetector(
        onTap: _openScan,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.accentDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              // Beranda
              Expanded(
                child: _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Beranda',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
              ),
              // Servis
              Expanded(
                child: _NavItem(
                  icon: Icons.build_rounded,
                  label: 'Servis',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
              ),
              // FAB Scan placeholder (slot tengah)
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(height: 28),
                    Text(
                      'Scan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                ),
              ),
              // Garasi
              Expanded(
                child: _NavItem(
                  icon: Icons.directions_car_rounded,
                  label: 'Garasi',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
              ),
              // Pengaturan
              Expanded(
                child: _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Pengaturan',
                  isActive: false,
                  onTap: _openSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accent : AppColors.textHint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
