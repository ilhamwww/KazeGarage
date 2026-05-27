// Notifikasi toast di pojok kanan atas, menggantikan SnackBar bawah
// Tidak mengganggu Scan FAB di bottom navigation

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum KazeNotifierType { success, error, info }

class KazeNotifier {
  KazeNotifier._();

  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    KazeNotifierType type = KazeNotifierType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Dismiss any existing notification first
    _dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => _KazeNotifierWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: _dismiss,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, type: KazeNotifierType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, type: KazeNotifierType.error);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: KazeNotifierType.info);
  }

  static void _dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _KazeNotifierWidget extends StatefulWidget {
  final String message;
  final KazeNotifierType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _KazeNotifierWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_KazeNotifierWidget> createState() => _KazeNotifierWidgetState();
}

class _KazeNotifierWidgetState extends State<_KazeNotifierWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();

    // Auto-dismiss
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _bgColor {
    switch (widget.type) {
      case KazeNotifierType.success:
        return AppColors.success;
      case KazeNotifierType.error:
        return AppColors.chartRed;
      case KazeNotifierType.info:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case KazeNotifierType.success:
        return Icons.check_circle_outline_rounded;
      case KazeNotifierType.error:
        return Icons.error_outline_rounded;
      case KazeNotifierType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: mq.padding.top + 8,
      right: 12,
      left: 12,
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slide.value * 80),
              child: Opacity(opacity: _fade.value, child: child),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () async {
                await _controller.reverse();
                widget.onDismiss();
              },
              child: Align(
                alignment: Alignment.topRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _bgColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _bgColor.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}