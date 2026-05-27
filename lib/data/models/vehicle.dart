// Model untuk kendaraan di KazeGarage
// Skema database mendukung gambar, tipe, dan tanggal servis/pajak

class Vehicle {
  final String id;
  final String name;
  final String licensePlate;
  final double tankCapacity;
  final String? imageUrl;
  final String? vehicleType; // "Mobil Penumpang", "Motor Sport", dll
  final DateTime? serviceDate; // Jadwal servis berikutnya
  final DateTime? taxDate; // Tanggal pajak
  final bool isActive; // Kendaraan utama yang sedang dipakai
  final DateTime createdAt;

  Vehicle({
    required this.id,
    required this.name,
    required this.licensePlate,
    required this.tankCapacity,
    this.imageUrl,
    this.vehicleType,
    this.serviceDate,
    this.taxDate,
    this.isActive = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Konversi dari Map (dari database)
  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      name: map['name'] as String,
      licensePlate: map['license_plate'] as String,
      tankCapacity: (map['tank_capacity'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      vehicleType: map['vehicle_type'] as String?,
      serviceDate: map['service_date'] != null ? DateTime.parse(map['service_date'] as String) : null,
      taxDate: map['tax_date'] != null ? DateTime.parse(map['tax_date'] as String) : null,
      isActive: (map['is_active'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Konversi ke Map (untuk database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'license_plate': licensePlate,
      'tank_capacity': tankCapacity,
      'image_url': imageUrl,
      'vehicle_type': vehicleType,
      'service_date': serviceDate?.toIso8601String(),
      'tax_date': taxDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Copy with method untuk update
  Vehicle copyWith({
    String? id,
    String? name,
    String? licensePlate,
    double? tankCapacity,
    String? imageUrl,
    String? vehicleType,
    DateTime? serviceDate,
    DateTime? taxDate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      licensePlate: licensePlate ?? this.licensePlate,
      tankCapacity: tankCapacity ?? this.tankCapacity,
      imageUrl: imageUrl ?? this.imageUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      serviceDate: serviceDate ?? this.serviceDate,
      taxDate: taxDate ?? this.taxDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, name: $name, licensePlate: $licensePlate, tankCapacity: $tankCapacity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}