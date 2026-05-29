// KazeGarage - Aplikasi Pencatat Pengeluaran BBM
// Entry point dengan setup Provider dan tema

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/kaze_notifier.dart';
import 'core/widgets/update_dialog.dart';
import 'data/services/backup_service.dart';
import 'data/services/update_service.dart';
import 'providers/vehicle_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/fuel_price_provider.dart';
import 'providers/service_provider.dart';
import 'screens/main_screen.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const KazeGarageApp());
}

class KazeGarageApp extends StatelessWidget {
  const KazeGarageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => FuelPriceProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
      ],
      child: MaterialApp(
        title: 'KazeGarage',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(nextScreen: AppInitializer()),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    final vehicleProvider = context.read<VehicleProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final serviceProvider = context.read<ServiceProvider>();
    await Future.wait([
      vehicleProvider.loadVehicles(),
      transactionProvider.loadTransactions(),
      serviceProvider.loadRecords(),
    ]);

    // Cek auto-restore: kalau DB kosong dan ada backup file di internal storage,
    // tawarkan pemulihan otomatis (case: app baru di-install ulang setelah uninstall).
    if (mounted &&
        vehicleProvider.vehicles.isEmpty &&
        transactionProvider.transactions.isEmpty) {
      await _maybeOfferAutoRestore();
    }

    if (mounted) {
      setState(() => _isInitialized = true);
    }

    // Setelah UI siap, cek versi terbaru di GitHub (silent kalau offline).
    if (mounted) {
      await _maybeCheckForUpdate();
    }
  }

  // Key untuk menyimpan versi yang sudah pernah ditolak user lewat "Nanti Saja".
  // Popup tidak akan muncul lagi untuk versi yang sama, tapi tetap muncul
  // kalau ada versi yang lebih baru lagi.
  static const String _dismissedUpdateVersionKey = 'update_dismissed_version';

  Future<void> _maybeCheckForUpdate() async {
    final updateInfo = await UpdateService().checkForUpdate();
    // Null = sudah terbaru, offline, atau gagal → tidak melakukan apa-apa.
    if (updateInfo == null || !mounted) return;

    // Cek apakah user sudah menolak versi ini sebelumnya.
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_dismissedUpdateVersionKey);
    if (dismissedVersion == updateInfo.latestVersion) return;
    if (!mounted) return;

    await UpdateDialog.show(
      context,
      updateInfo,
      onDismiss: () {
        // Simpan versi yang ditolak agar tidak muncul ulang untuk versi ini.
        SharedPreferences.getInstance().then(
          (p) => p.setString(
            _dismissedUpdateVersionKey,
            updateInfo.latestVersion,
          ),
        );
      },
    );
  }

  // Key untuk menandai bahwa dialog auto-restore sudah pernah ditampilkan.
  // Mencegah dialog muncul ulang setiap launch jika user pilih "Nanti Saja".
  static const String _autoRestoreFlagKey = 'auto_restore_offered_v1';

  Future<void> _maybeOfferAutoRestore() async {
    // Cek flag — kalau sudah pernah offer, skip
    final prefs = await SharedPreferences.getInstance();
    final alreadyOffered = prefs.getBool(_autoRestoreFlagKey) ?? false;
    if (alreadyOffered) return;

    final service = BackupService();
    final files = await service.listBackupFiles();
    if (files.isEmpty || !mounted) {
      // Tetap tandai sudah dicek agar tidak scan tiap launch
      await prefs.setBool(_autoRestoreFlagKey, true);
      return;
    }

    final latest = files.first;
    final stat = latest.statSync();
    final dateLabel = DateFormat(
      'd MMM yyyy, HH:mm',
      'id_ID',
    ).format(stat.modified);

    final shouldRestore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Backup Ditemukan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aplikasi menemukan file backup tersimpan di HP. Pulihkan data sekarang?',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latest.uri.pathSegments.last,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti Saja'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pulihkan'),
          ),
        ],
      ),
    );

    // Tandai dialog sudah pernah muncul — apapun pilihan user.
    await prefs.setBool(_autoRestoreFlagKey, true);

    if (shouldRestore != true || !mounted) return;

    try {
      final parsed = await service.parseBackupFile(latest);
      final result = await service.applyRestore(
        vehicles: parsed.vehicles,
        transactions: parsed.transactions,
        serviceRecords: parsed.serviceRecords,
        strategy: RestoreStrategy.replace,
      );
      if (!mounted) return;
      if (result.success) {
        await context.read<VehicleProvider>().loadVehicles();
        if (!mounted) return;
        await context.read<TransactionProvider>().loadTransactions();
        if (!mounted) return;
        await context.read<ServiceProvider>().loadRecords();
        if (!mounted) return;
        KazeNotifier.success(
          context,
          'Data berhasil dipulihkan: ${result.vehicleCount} kendaraan, ${result.transactionCount} transaksi',
        );
      } else {
        KazeNotifier.error(context, result.message ?? 'Gagal memulihkan data');
      }
    } catch (e) {
      if (!mounted) return;
      KazeNotifier.error(context, 'Gagal memulihkan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_gas_station, size: 64, color: Color(0xFFFF6B35)),
              SizedBox(height: 16),
              Text(
                'KazeGarage',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Color(0xFFFF6B35)),
            ],
          ),
        ),
      );
    }
    return const MainScreen();
  }
}
