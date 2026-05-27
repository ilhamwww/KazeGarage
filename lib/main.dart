// KazeGarage - Aplikasi Pencatat Pengeluaran BBM
// Entry point dengan setup Provider dan tema

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'providers/vehicle_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/main_screen.dart';

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
      ],
      child: MaterialApp(
        title: 'KazeGarage',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppInitializer(),
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
    await Future.wait([
      vehicleProvider.loadVehicles(),
      transactionProvider.loadTransactions(),
    ]);
    if (mounted) {
      setState(() => _isInitialized = true);
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