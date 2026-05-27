// Provider untuk manajemen state kendaraan

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/database/database_helper.dart';
import '../data/models/vehicle.dart';

class VehicleProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;

  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;

  Future<void> loadVehicles() async {
    _isLoading = true;
    notifyListeners();
    try {
      _vehicles = await _db.getAllVehicles();
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addVehicle({
    required String name,
    required String licensePlate,
    required double tankCapacity,
    String? imageUrl,
  }) async {
    try {
      final vehicle = Vehicle(
        id: const Uuid().v4(),
        name: name,
        licensePlate: licensePlate,
        tankCapacity: tankCapacity,
        imageUrl: imageUrl,
      );
      await _db.insertVehicle(vehicle);
      await loadVehicles();
      return true;
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
      return false;
    }
  }

  Future<bool> updateVehicle(Vehicle vehicle) async {
    try {
      await _db.updateVehicle(vehicle);
      await loadVehicles();
      return true;
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      return false;
    }
  }

  Future<bool> deleteVehicle(String id) async {
    try {
      await _db.deleteVehicle(id);
      await loadVehicles();
      return true;
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      return false;
    }
  }

  Vehicle? getVehicleById(String id) {
    try {
      return _vehicles.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }

  int get vehicleCount => _vehicles.length;

  // Filter for history screen
  Vehicle? _selectedFilterVehicle;
  Vehicle? get selectedFilterVehicle => _selectedFilterVehicle;

  void setFilterVehicle(String? vehicleId) {
    if (vehicleId == null) {
      _selectedFilterVehicle = null;
    } else {
      _selectedFilterVehicle = getVehicleById(vehicleId);
    }
    notifyListeners();
  }
}
