// Provider untuk manajemen state transaksi bahan bakar

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/database/database_helper.dart';
import '../data/models/fuel_transaction.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<FuelTransaction> _transactions = [];
  bool _isLoading = false;
  String? _filterVehicleId;

  List<FuelTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get filterVehicleId => _filterVehicleId;

  Future<void> loadTransactions({String? vehicleId}) async {
    _isLoading = true;
    _filterVehicleId = vehicleId;
    notifyListeners();
    try {
      if (vehicleId != null) {
        _transactions = await _db.getTransactionsByVehicle(vehicleId);
      } else {
        _transactions = await _db.getAllTransactions();
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addTransaction({
    required String vehicleId,
    required DateTime date,
    required double totalCost,
    required double liters,
    required double pricePerLiter,
    double? odometer,
    String? receiptImagePath,
    String? notes,
    String? fuelType,
  }) async {
    try {
      final transaction = FuelTransaction(
        id: const Uuid().v4(),
        vehicleId: vehicleId,
        date: date,
        totalCost: totalCost,
        liters: liters,
        pricePerLiter: pricePerLiter,
        odometer: odometer,
        receiptImagePath: receiptImagePath,
        notes: notes,
        fuelType: fuelType,
      );
      await _db.insertTransaction(transaction);
      await loadTransactions(vehicleId: _filterVehicleId);
      return true;
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      return false;
    }
  }

  Future<bool> updateTransaction(FuelTransaction transaction) async {
    try {
      await _db.updateTransaction(transaction);
      await loadTransactions(vehicleId: _filterVehicleId);
      return true;
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await _db.deleteTransaction(id);
      await loadTransactions(vehicleId: _filterVehicleId);
      return true;
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      return false;
    }
  }

  // Statistik
  Future<double> getTotalSpending() async {
    return await _db.getTotalSpendingAll();
  }

  Future<double> getTotalSpendingByVehicle(String vehicleId) async {
    return await _db.getTotalSpendingByVehicle(vehicleId);
  }

  Future<double> getTotalLitersByVehicle(String vehicleId) async {
    return await _db.getTotalLitersByVehicle(vehicleId);
  }

  Future<List<Map<String, dynamic>>> getMonthlySpending() async {
    return await _db.getMonthlySpending();
  }

  Future<List<Map<String, dynamic>>> getSpendingByVehicle() async {
    return await _db.getSpendingByVehicle();
  }

  int get transactionCount => _transactions.length;

  // Total spending untuk semua transaksi yang sedang ditampilkan
  double get displayedTotalSpending {
    return _transactions.fold(0.0, (sum, t) => sum + t.totalCost);
  }

  // Total liter untuk semua transaksi yang sedang ditampilkan
  double get displayedTotalLiters {
    return _transactions.fold(0.0, (sum, t) => sum + t.liters);
  }
}