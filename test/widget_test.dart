// KazeGarage widget smoke test.
//
// Catatan: KazeGarageApp() tidak bisa di-test langsung karena splash screen
// memanggil Future.delayed dan PackageInfo + sqflite yang tidak tersedia di
// flutter_test environment (akan menyisakan pending Timer).
//
// Untuk verifikasi parsing struk OCR, lihat `test/receipt_parser_test.dart`.
// Test smoke ini hanya memastikan tema aplikasi bisa di-build.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaze_garage/core/theme/app_theme.dart';

void main() {
  testWidgets('App theme dapat dibangun tanpa error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Center(child: Text('KazeGarage'))),
      ),
    );

    expect(find.text('KazeGarage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
