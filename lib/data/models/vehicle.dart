// Model untuk kendaraan di KazeGarage
// Sesuai dengan skema database dari PRD

class Vehicle {
  final String id;
  final String name;
  final String licensePlate;
  final double tankCapacity;
  final String? imageUrl;
  final DateTime createdAt;

  Vehicle({
    required this.id,
    required this.name,
    required this.licensePlate,
    required this.tankCapacity,
    this.imageUrl,
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
    DateTime? createdAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      licensePlate: licensePlate ?? this.licensePlate,
      tankCapacity: tankCapacity ?? this.tankCapacity,
      imageUrl: imageUrl ?? this.imageUrl,
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