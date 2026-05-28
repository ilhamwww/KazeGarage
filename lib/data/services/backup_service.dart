// Service untuk backup & restore data KazeGarage ke/dari file .kazegarage.
//
// Format file: JSON di-encode dengan ekstensi .kazegarage agar mudah
// dikenali sebagai backup KazeGarage di File Manager:
// {
//   "version": 1,
//   "app": "KazeGarage",
//   "exportedAt": "2026-05-28T10:00:00.000Z",
//   "vehicles": [ ... ],
//   "transactions": [ ... ]
// }
//
// File otomatis disimpan ke folder publik di internal storage HP:
//   /storage/emulated/0/Android/data/com.kazegarage.kaze_garage/files/Backups/
// Folder ini:
//   - Tidak butuh permission storage (app-specific external)
//   - Terlihat di File Manager bawaan HP
//   - Otomatis di-include oleh Android Auto Backup (cloud-backup)
//
// Gunakan kombinasi dengan Android Auto Backup untuk redudansi.

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/fuel_transaction.dart';
import '../models/service_record.dart';
import '../models/vehicle.dart';

/// Strategi restore saat data lokal sudah ada
enum RestoreStrategy {
  /// Hapus data lokal lalu pakai data backup (default)
  replace,

  /// Gabungkan: backup overwrite entry id sama, lokal lain tetap dipertahankan
  merge,
}

class BackupResult {
  final bool success;
  final String? message;
  final String? filePath;
  final int vehicleCount;
  final int transactionCount;

  const BackupResult({
    required this.success,
    this.message,
    this.filePath,
    this.vehicleCount = 0,
    this.transactionCount = 0,
  });
}

class BackupService {
  static const int _formatVersion = 1;
  static const String _appTag = 'KazeGarage';
  static const String _fileExtension = 'kazegarage';
  static const String _backupFolderName = 'Backups';

  final DatabaseHelper _db = DatabaseHelper();

  /// Cek apakah aplikasi punya akses tulis ke folder Download publik.
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.manageExternalStorage.status;
    return status.isGranted;
  }

  /// Request akses ke All Files Storage (untuk Android 11+).
  /// Akan membuka halaman Settings sistem; user harus enable manual lalu
  /// kembali ke aplikasi.
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  /// Resolve folder backup. Lokasi disusun berurutan dari yang paling publik:
  ///
  /// 1. **Download publik** — `/storage/emulated/0/Download/KazeGarage/`
  ///    Mengikuti pattern KazeView Manager. Survives uninstall.
  ///    Butuh permission MANAGE_EXTERNAL_STORAGE (Android 11+).
  /// 2. **Fallback internal app** — `getApplicationDocumentsDirectory()/Backups`
  ///    Selalu writable, tidak butuh permission. Tidak survive uninstall
  ///    sendiri tapi ikut Android Auto Backup.
  ///
  /// Folder dibuat recursive jika belum ada.
  Future<Directory> getBackupDirectory() async {
    if (Platform.isAndroid) {
      try {
        if (await hasStoragePermission()) {
          // /storage/emulated/0/Download/KazeGarage/
          final downloadPath = '/storage/emulated/0/Download/$_appTag';
          final dir = Directory(downloadPath);
          await dir.create(recursive: true);
          // Verifikasi writable
          final probe = File('${dir.path}/.kazegarage_probe');
          await probe.writeAsString('ok');
          await probe.delete();
          return dir;
        }
      } catch (e) {
        debugPrint(
          'Download folder tidak bisa dipakai, fallback ke internal: $e',
        );
      }
    }

    // Fallback: internal app storage (selalu writable, tidak butuh permission)
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_backupFolderName');
    await dir.create(recursive: true);
    return dir;
  }

  /// Generate nama file backup berdasarkan timestamp sekarang.
  String _generateFileName([DateTime? now]) {
    final t = now ?? DateTime.now();
    final y = t.year.toString();
    final mo = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    return 'kazegarage-backup-$y$mo$d-$h$mi.$_fileExtension';
  }

  /// Export semua data ke file .kazegarage di internal storage.
  Future<BackupResult> exportToFile() async {
    try {
      final vehicles = await _db.getAllVehicles();
      final transactions = await _db.getAllTransactions();
      final serviceRecords = await _db.getAllServiceRecords();

      final payload = {
        'version': _formatVersion,
        'app': _appTag,
        'exportedAt': DateTime.now().toIso8601String(),
        'vehicles': vehicles.map((v) => v.toMap()).toList(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'serviceRecords': serviceRecords.map((s) => s.toMap()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

      final dir = await getBackupDirectory();
      final fileName = _generateFileName();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonString);

      return BackupResult(
        success: true,
        filePath: file.path,
        vehicleCount: vehicles.length,
        transactionCount: transactions.length,
        message: 'Backup tersimpan di ${dir.path}',
      );
    } catch (e) {
      debugPrint('Export error: $e');
      return BackupResult(success: false, message: 'Gagal mengekspor data: $e');
    }
  }

  /// Trigger share sheet untuk file backup yang sudah dibuat.
  Future<void> shareBackupFile(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/octet-stream')],
      text: 'Backup data KazeGarage',
      subject: 'KazeGarage Backup',
    );
  }

  /// Daftar semua file backup yang tersimpan di internal storage.
  /// Diurutkan dari terbaru ke terlama berdasarkan modified time.
  Future<List<File>> listBackupFiles() async {
    try {
      final dir = await getBackupDirectory();
      if (!await dir.exists()) return [];
      final entries = await dir.list().toList();
      final files = entries
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.$_fileExtension'))
          .toList();
      // Sort terbaru duluan
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      return files;
    } catch (e) {
      debugPrint('List backup error: $e');
      return [];
    }
  }

  /// Pilih file backup dari storage user dan parse.
  /// Mengembalikan parsed data tanpa menulis ke DB — caller harus
  /// memanggil [applyRestore] setelah konfirmasi user.
  ///
  /// Menerima file dengan ekstensi .kazegarage (utama) atau .json (legacy).
  Future<
    ({
      List<Vehicle> vehicles,
      List<FuelTransaction> transactions,
      List<ServiceRecord> serviceRecords,
      String exportedAt,
    })?
  >
  pickAndParseBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      if (path == null) return null;

      // Validasi ekstensi (case-insensitive)
      final lowerPath = path.toLowerCase();
      if (!lowerPath.endsWith('.$_fileExtension') &&
          !lowerPath.endsWith('.json')) {
        throw Exception(
          'Pilih file dengan ekstensi .$_fileExtension (atau .json untuk backup lama)',
        );
      }

      return await _parseBackupFile(File(path));
    } catch (e) {
      debugPrint('Pick/parse error: $e');
      rethrow;
    }
  }

  /// Parse file backup yang sudah diketahui path-nya
  /// (dipakai juga oleh auto-restore saat first launch).
  Future<
    ({
      List<Vehicle> vehicles,
      List<FuelTransaction> transactions,
      List<ServiceRecord> serviceRecords,
      String exportedAt,
    })
  >
  parseBackupFile(File file) => _parseBackupFile(file);

  Future<
    ({
      List<Vehicle> vehicles,
      List<FuelTransaction> transactions,
      List<ServiceRecord> serviceRecords,
      String exportedAt,
    })
  >
  _parseBackupFile(File file) async {
    if (!await file.exists()) {
      throw Exception('File tidak ditemukan');
    }

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    // Validasi format
    final app = json['app'] as String?;
    if (app != _appTag) {
      throw Exception('File backup tidak dikenali (bukan backup KazeGarage)');
    }
    final version = json['version'] as int?;
    if (version == null || version > _formatVersion) {
      throw Exception(
        'Versi backup ($version) tidak didukung oleh aplikasi versi ini',
      );
    }

    final vehiclesList = (json['vehicles'] as List? ?? []);
    final transactionsList = (json['transactions'] as List? ?? []);
    final serviceRecordsList = (json['serviceRecords'] as List? ?? []);

    final vehicles = vehiclesList
        .map((m) => Vehicle.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    final transactions = transactionsList
        .map(
          (m) => FuelTransaction.fromMap(Map<String, dynamic>.from(m as Map)),
        )
        .toList();
    final serviceRecords = serviceRecordsList
        .map((m) => ServiceRecord.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();

    final exportedAt = (json['exportedAt'] as String?) ?? '';

    return (
      vehicles: vehicles,
      transactions: transactions,
      serviceRecords: serviceRecords,
      exportedAt: exportedAt,
    );
  }

  /// Apply hasil parse ke database dengan strategi yang dipilih.
  Future<BackupResult> applyRestore({
    required List<Vehicle> vehicles,
    required List<FuelTransaction> transactions,
    List<ServiceRecord> serviceRecords = const [],
    required RestoreStrategy strategy,
  }) async {
    try {
      switch (strategy) {
        case RestoreStrategy.replace:
          await _db.replaceAllData(
            vehicles: vehicles,
            transactions: transactions,
            serviceRecords: serviceRecords,
          );
          break;
        case RestoreStrategy.merge:
          await _db.mergeData(
            vehicles: vehicles,
            transactions: transactions,
            serviceRecords: serviceRecords,
          );
          break;
      }
      return BackupResult(
        success: true,
        vehicleCount: vehicles.length,
        transactionCount: transactions.length,
        message: 'Data berhasil dipulihkan',
      );
    } catch (e) {
      debugPrint('Apply restore error: $e');
      return BackupResult(success: false, message: 'Gagal memulihkan data: $e');
    }
  }
}
