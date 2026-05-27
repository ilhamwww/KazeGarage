// Provider untuk state harga BBM terbaru
// Cache hasil scrape selama 6 jam untuk hemat bandwidth

import 'package:flutter/material.dart';
import '../data/models/fuel_price.dart';
import '../data/services/fuel_price_service.dart';

class FuelPriceProvider extends ChangeNotifier {
  final FuelPriceService _service = FuelPriceService();

  FuelPriceData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  FuelPriceData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasData => _data != null;

  static const Duration _cacheTtl = Duration(hours: 6);

  /// Fetch harga BBM. Pakai cache kalau masih segar, kecuali force=true.
  Future<void> loadPrices({bool force = false}) async {
    if (!force && _data != null) {
      final age = DateTime.now().difference(_data!.fetchedAt);
      if (age < _cacheTtl) return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await _service.fetchPrices();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('FuelPriceProvider error: $_errorMessage');
    }

    _isLoading = false;
    notifyListeners();
  }
}
