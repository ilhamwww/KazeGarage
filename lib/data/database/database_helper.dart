// Database helper untuk SQLite
// Menggunakan sqflite untuk penyimpanan lokal

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vehicle.dart';
import '../models/fuel_transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kaze_garage.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel vehicles
    await db.execute('''
      CREATE TABLE vehicles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        license_plate TEXT NOT NULL,
        tank_capacity REAL NOT NULL,
        image_url TEXT,
        vehicle_type TEXT,
        service_date TEXT,
        tax_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabel fuel_transactions
    await db.execute('''
      CREATE TABLE fuel_transactions (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        date TEXT NOT NULL,
        total_cost REAL NOT NULL,
        liters REAL NOT NULL,
        price_per_liter REAL NOT NULL,
        odometer REAL,
        receipt_image_path TEXT,
        notes TEXT,
        fuel_type TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE fuel_transactions ADD COLUMN fuel_type TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN vehicle_type TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN service_date TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN tax_date TEXT');
      await db.execute(
        'ALTER TABLE vehicles ADD COLUMN is_active INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // ==================== VEHICLE OPERATIONS ====================

  Future<int> insertVehicle(Vehicle vehicle) async {
    final db = await database;
    return await db.insert(
      'vehicles',
      vehicle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateVehicle(Vehicle vehicle) async {
    final db = await database;
    return await db.update(
      'vehicles',
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<int> deleteVehicle(String id) async {
    final db = await database;
    // Hapus juga semua transaksi terkait
    await db.delete(
      'fuel_transactions',
      where: 'vehicle_id = ?',
      whereArgs: [id],
    );
    return await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Vehicle>> getAllVehicles() async {
    final db = await database;
    final maps = await db.query('vehicles', orderBy: 'created_at DESC');
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<Vehicle?> getVehicleById(String id) async {
    final db = await database;
    final maps = await db.query('vehicles', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Vehicle.fromMap(maps.first);
  }

  // ==================== TRANSACTION OPERATIONS ====================

  Future<int> insertTransaction(FuelTransaction transaction) async {
    final db = await database;
    return await db.insert(
      'fuel_transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTransaction(FuelTransaction transaction) async {
    final db = await database;
    return await db.update(
      'fuel_transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return await db.delete(
      'fuel_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<FuelTransaction>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query('fuel_transactions', orderBy: 'date DESC');
    return maps.map((map) => FuelTransaction.fromMap(map)).toList();
  }

  Future<List<FuelTransaction>> getTransactionsByVehicle(
    String vehicleId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'fuel_transactions',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => FuelTransaction.fromMap(map)).toList();
  }

  Future<List<FuelTransaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'fuel_transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((map) => FuelTransaction.fromMap(map)).toList();
  }

  Future<FuelTransaction?> getTransactionById(String id) async {
    final db = await database;
    final maps = await db.query(
      'fuel_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return FuelTransaction.fromMap(maps.first);
  }

  // ==================== STATISTICS OPERATIONS ====================

  Future<double> getTotalSpendingByVehicle(String vehicleId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(total_cost) as total FROM fuel_transactions WHERE vehicle_id = ?',
      [vehicleId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalLitersByVehicle(String vehicleId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(liters) as total FROM fuel_transactions WHERE vehicle_id = ?',
      [vehicleId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTransactionCountByVehicle(String vehicleId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM fuel_transactions WHERE vehicle_id = ?',
      [vehicleId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<double> getTotalSpendingAll() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(total_cost) as total FROM fuel_transactions',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTotalTransactionsAll() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM fuel_transactions',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getVehicleCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM vehicles');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getMonthlySpending() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', date) as month,
        SUM(total_cost) as total
      FROM fuel_transactions
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getSpendingByVehicle() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        v.name as vehicle_name,
        SUM(t.total_cost) as total
      FROM fuel_transactions t
      JOIN vehicles v ON t.vehicle_id = v.id
      GROUP BY t.vehicle_id
      ORDER BY total DESC
    ''');
  }

  // ==================== BACKUP / RESTORE ====================

  /// Hapus semua data dan ganti dengan data dari backup.
  /// Dijalankan dalam satu transaction supaya atomic — kalau gagal di tengah,
  /// state database tidak korup.
  Future<void> replaceAllData({
    required List<Vehicle> vehicles,
    required List<FuelTransaction> transactions,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Bersihkan tabel dulu (urutan: child → parent untuk FK)
      await txn.delete('fuel_transactions');
      await txn.delete('vehicles');

      // Insert vehicles dulu agar FK constraint puas
      for (final v in vehicles) {
        await txn.insert(
          'vehicles',
          v.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final t in transactions) {
        await txn.insert(
          'fuel_transactions',
          t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Merge data backup ke database existing — entry dengan id sama akan di-replace,
  /// entry baru ditambahkan, entry lokal yang tidak ada di backup tetap dipertahankan.
  Future<void> mergeData({
    required List<Vehicle> vehicles,
    required List<FuelTransaction> transactions,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final v in vehicles) {
        await txn.insert(
          'vehicles',
          v.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final t in transactions) {
        await txn.insert(
          'fuel_transactions',
          t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
