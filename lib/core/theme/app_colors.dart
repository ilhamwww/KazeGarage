// Warna utama aplikasi KazeGarage
// Mengikuti design system dari PRD

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Warna Utama - Deep Navy (untuk hero card)
  static const Color primary = Color(0xFF0F1B2D);
  static const Color primaryLight = Color(0xFF1A2A40);
  static const Color primaryDark = Color(0xFF080F1A);

  // Warna Aksen - Race Red
  static const Color accent = Color(0xFFE63946);
  static const Color accentLight = Color(0xFFFF6B6B);
  static const Color accentDark = Color(0xFFC42A36);

  // Warna Latar
  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F5);
  static const Color surfaceMuted = Color(0xFFEEF1F5);

  // Warna Teks
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // Warna Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Warna Chart
  static const Color chartBlue = Color(0xFF3B82F6);
  static const Color chartGreen = Color(0xFF10B981);
  static const Color chartOrange = Color(0xFFF97316);
  static const Color chartPurple = Color(0xFF8B5CF6);
  static const Color chartRed = Color(0xFFEF4444);

  // Warna Divider & Border
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFD1D5DB);

  // Warna Overlay
  static const Color overlay = Color(0x80000000);
  static const Color shimmer = Color(0xFFE0E0E0);
}