// Splash Screen KazeGarage
// Tampil saat aplikasi pertama kali dibuka, menampilkan:
// - Icon aplikasi
// - Nama aplikasi "KazeGarage"
// - Versi aplikasi (otomatis dari pubspec.yaml)
// - Tagline "By KAZEVIEW"
//
// Setelah animasi singkat (~1.5 detik) + warm-up provider/database,
// otomatis pindah ke AppInitializer yang melanjutkan flow normal.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  /// Widget yang akan ditampilkan setelah splash selesai.
  final Widget nextScreen;

  /// Durasi minimum splash tampil. Default 1500ms supaya UX tidak ke-skip.
  final Duration minDuration;

  const SplashScreen({
    super.key,
    required this.nextScreen,
    this.minDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  String _versionLabel = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Fetch versi paralel dengan animasi
    final futures = <Future>[
      _loadVersion(),
      Future.delayed(widget.minDuration),
    ];
    await Future.wait(futures);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => widget.nextScreen,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = 'v${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLabel = '');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Konten tengah
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _fadeIn.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon aplikasi
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 32,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Image.asset(
                                    'assets/icon/kaze_garage_icon.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.local_gas_station_rounded,
                                      size: 64,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // App name
                            const Text(
                              'KazeGarage',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.6,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Tagline
                            Text(
                              'Personal Vehicle Manager',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Footer: versi + by KAZEVIEW
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _fadeIn.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_versionLabel.isNotEmpty)
                            Text(
                              _versionLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.55),
                                letterSpacing: 0.3,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'By ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                              const Text(
                                'KAZEVIEW',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
