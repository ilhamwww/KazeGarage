// Provider untuk manajemen state catatan servis kendaraan.

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/database/database_helper.dart';
import '../data/models/service_record.dart';

class ServiceProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<ServiceRecord> _records = [];
  bool _isLoading = false;
  String? _filterVehicleId;

  List<ServiceRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get filterVehicleId => _filterVehicleId;

  Future<void> loadRecords({String? vehicleId}) async {
    _isLoading = true;
    _filterVehicleId = vehicleId;
    notifyListeners();
    try {
      if (vehicleId != null) {
        _records = await _db.getServiceRecordsByVehicle(vehicleId);
      } else {
        _records = await _db.getAllServiceRecords();
      }
    } catch (e) {
      debugPrint('Error loading service records: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addRecord({
    required String vehicleId,
    required DateTime date,
    required String serviceType,
    required double odometer,
    double? cost,
    String? location,
    String? notes,
    DateTime? nextDueDate,
    double? nextDueOdometer,
  }) async {
    try {
      final record = ServiceRecord(
        id: const Uuid().v4(),
        vehicleId: vehicleId,
        date: date,
        serviceType: serviceType,
        odometer: odometer,
        cost: cost,
        location: location,
        notes: notes,
        nextDueDate: nextDueDate,
        nextDueOdometer: nextDueOdometer,
      );
      await _db.insertServiceRecord(record);
      await loadRecords(vehicleId: _filterVehicleId);
      return true;
    } catch (e) {
      debugPrint('Error adding service record: $e');
      return false;
    }
  }

  Future<bool> updateRecord(ServiceRecord record) async {
    try {
      await _db.updateServiceRecord(record);
      await loadRecords(vehicleId: _filterVehicleId);
      return true;
    } catch (e) {
      debugPrint('Error updating service record: $e');
      return false;
    }
  }

  Future<bool> deleteRecord(String id) async {
    try {
      await _db.deleteServiceRecord(id);
      await loadRecords(vehicleId: _filterVehicleId);
      return true;
    } catch (e) {
      debugPrint('Error deleting service record: $e');
      return false;
    }
  }

  /// Catatan servis terbaru per kendaraan + jenis servis.
  /// Berguna untuk hitung "servis berikutnya" hanya dari record terbaru.
  ServiceRecord? latestForVehicleAndType(String vehicleId, String serviceType) {
    final filtered = _records
        .where((r) => r.vehicleId == vehicleId && r.serviceType == serviceType)
        .toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered.first;
  }

  /// Reminder yang akan jatuh tempo dalam [withinDays] hari atau
  /// dalam [withinKm] KM dari odometer terkini.
  List<ServiceRecord> upcomingReminders({
    int withinDays = 30,
    double? currentOdometer,
    double withinKm = 1000,
  }) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: withinDays));
    return _records.where((r) {
      bool dueByDate = false;
      bool dueByKm = false;
      if (r.nextDueDate != null) {
        dueByDate = !r.nextDueDate!.isAfter(cutoff);
      }
      if (r.nextDueOdometer != null && currentOdometer != null) {
        dueByKm = (r.nextDueOdometer! - currentOdometer) <= withinKm;
      }
      return dueByDate || dueByKm;
    }).toList();
  }
}
