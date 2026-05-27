// Model untuk transaksi pengisian bahan bakar
// Sesuai dengan skema database dari PRD

class FuelTransaction {
  final String id;
  final String vehicleId;
  final DateTime date;
  final double totalCost;
  final double liters;
  final double pricePerLiter;
  final double? odometer;
  final String? receiptImagePath;
  final String? notes;
  final String? fuelType;
  final DateTime createdAt;

  FuelTransaction({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.totalCost,
    required this.liters,
    required this.pricePerLiter,
    this.odometer,
    this.receiptImagePath,
    this.notes,
    this.fuelType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Menghitung efisiensi (km per liter) jika odometer tersedia
  double? calculateEfficiency(double? previousOdometer) {
    if (odometer == null || previousOdometer == null) return null;
    final distance = odometer! - previousOdometer;
    if (distance <= 0 || liters <= 0) return null;
    return distance / liters;
  }

  // Konversi dari Map (dari database)
  factory FuelTransaction.fromMap(Map<String, dynamic> map) {
    return FuelTransaction(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.parse(map['date'] as String),
      totalCost: (map['total_cost'] as num).toDouble(),
      liters: (map['liters'] as num).toDouble(),
      pricePerLiter: (map['price_per_liter'] as num).toDouble(),
      odometer: map['odometer'] != null ? (map['odometer'] as num).toDouble() : null,
      receiptImagePath: map['receipt_image_path'] as String?,
      notes: map['notes'] as String?,
      fuelType: map['fuel_type'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Konversi ke Map (untuk database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'total_cost': totalCost,
      'liters': liters,
      'price_per_liter': pricePerLiter,
      'odometer': odometer,
      'receipt_image_path': receiptImagePath,
      'notes': notes,
      'fuel_type': fuelType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Copy with method untuk update
  FuelTransaction copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    double? totalCost,
    double? liters,
    double? pricePerLiter,
    double? odometer,
    String? receiptImagePath,
    String? notes,
    String? fuelType,
    DateTime? createdAt,
  }) {
    return FuelTransaction(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      totalCost: totalCost ?? this.totalCost,
      liters: liters ?? this.liters,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      odometer: odometer ?? this.odometer,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      notes: notes ?? this.notes,
      fuelType: fuelType ?? this.fuelType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'FuelTransaction(id: $id, vehicleId: $vehicleId, date: $date, totalCost: $totalCost, liters: $liters)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FuelTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}