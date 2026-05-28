// Model untuk catatan servis kendaraan di KazeGarage.
//
// Mencatat aktivitas servis seperti ganti oli, filter, busi, dll
// beserta odometer saat servis dan estimasi servis berikutnya
// (auto-suggest berdasarkan interval di Vehicle).

class ServiceRecord {
  final String id;
  final String vehicleId;

  /// Tanggal servis dilakukan
  final DateTime date;

  /// Jenis servis, contoh: "Ganti Oli Mesin", "Ganti Filter Udara"
  final String serviceType;

  /// Pembacaan odometer (KM) saat servis
  final double odometer;

  /// Biaya servis (Rupiah). Opsional.
  final double? cost;

  /// Lokasi servis / nama bengkel. Opsional.
  final String? location;

  /// Catatan tambahan
  final String? notes;

  /// Estimasi tanggal servis berikutnya (auto-calculated)
  final DateTime? nextDueDate;

  /// Estimasi odometer servis berikutnya (auto-calculated)
  final double? nextDueOdometer;

  final DateTime createdAt;

  ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.serviceType,
    required this.odometer,
    this.cost,
    this.location,
    this.notes,
    this.nextDueDate,
    this.nextDueOdometer,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    return ServiceRecord(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.parse(map['date'] as String),
      serviceType: map['service_type'] as String,
      odometer: (map['odometer'] as num).toDouble(),
      cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      nextDueDate: map['next_due_date'] != null
          ? DateTime.parse(map['next_due_date'] as String)
          : null,
      nextDueOdometer: map['next_due_odometer'] != null
          ? (map['next_due_odometer'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'service_type': serviceType,
      'odometer': odometer,
      'cost': cost,
      'location': location,
      'notes': notes,
      'next_due_date': nextDueDate?.toIso8601String(),
      'next_due_odometer': nextDueOdometer,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ServiceRecord copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    String? serviceType,
    double? odometer,
    double? cost,
    String? location,
    String? notes,
    DateTime? nextDueDate,
    double? nextDueOdometer,
    DateTime? createdAt,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      serviceType: serviceType ?? this.serviceType,
      odometer: odometer ?? this.odometer,
      cost: cost ?? this.cost,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      nextDueOdometer: nextDueOdometer ?? this.nextDueOdometer,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Daftar preset jenis servis untuk quick-pick di UI.
class ServiceTypes {
  ServiceTypes._();

  static const List<String> presets = [
    'Ganti Oli Mesin',
    'Ganti Oli Gardan',
    'Ganti Oli Transmisi',
    'Ganti Filter Oli',
    'Ganti Filter Udara',
    'Ganti Filter Bensin',
    'Ganti Busi',
    'Ganti Aki',
    'Ganti Ban',
    'Ganti Kampas Rem',
    'Ganti Coolant / Radiator',
    'Tune Up',
    'Servis Berkala',
    'Lainnya',
  ];

  /// Mapping icon untuk setiap jenis servis (Material icon code).
  static int iconCodeFor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('oli')) return 0xe332; // local_gas_station
    if (lower.contains('filter')) return 0xe9be; // air_filter (ish)
    if (lower.contains('busi')) return 0xe1ac; // bolt
    if (lower.contains('aki')) return 0xe1a3; // battery
    if (lower.contains('ban')) return 0xea0e; // tire_repair (fallback car)
    if (lower.contains('rem')) return 0xeb3a; // car_repair (ish)
    if (lower.contains('coolant') || lower.contains('radiator')) return 0xeb3a;
    return 0xe531; // build (general wrench)
  }
}
