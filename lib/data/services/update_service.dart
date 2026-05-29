// Service untuk cek versi terbaru dari GitHub Release.
//
// Cara kerja (offline-first friendly):
//  - Memanggil GitHub Releases API untuk mengambil release terbaru.
//  - Membandingkan tag versi (mis. "v1.1.0") dengan versi lokal aplikasi.
//  - Jika gagal (offline, timeout, DNS error, dsb.) → return null tanpa error,
//    sehingga aplikasi tetap berjalan normal dalam mode offline.
//
// Tidak menambah dependency deteksi koneksi; cukup mengandalkan timeout pendek
// pada HTTP request + try-catch.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Informasi update yang tersedia dari GitHub Release.
class UpdateInfo {
  /// Versi terbaru (sudah dibersihkan dari prefix "v"), mis. "1.1.0".
  final String latestVersion;

  /// Tag asli dari GitHub, mis. "v1.1.0".
  final String tag;

  /// Versi yang terpasang saat ini, mis. "1.0.0".
  final String currentVersion;

  /// Judul release (field "name" di GitHub), bisa kosong.
  final String releaseName;

  /// Catatan rilis (field "body"), bisa kosong.
  final String releaseNotes;

  /// URL halaman release di GitHub (selalu ada).
  final String releaseUrl;

  /// URL langsung ke file APK (kalau ada di assets). Bisa null.
  final String? apkUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.tag,
    required this.currentVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.releaseUrl,
    this.apkUrl,
  });

  /// URL terbaik untuk diarahkan ke user: APK langsung kalau ada,
  /// jika tidak, halaman release GitHub.
  String get downloadUrl => apkUrl ?? releaseUrl;
}

class UpdateService {
  // Repo GitHub tempat rilis dipublikasikan.
  static const String _owner = 'ilhamwww';
  static const String _repo = 'KazeGarage';

  static const String _latestReleaseApi =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Cek apakah ada versi yang lebih baru di GitHub Release.
  ///
  /// Return [UpdateInfo] jika tersedia update, atau null jika:
  ///  - sudah versi terbaru,
  ///  - offline / request gagal / timeout,
  ///  - response tidak valid.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(
            Uri.parse(_latestReleaseApi),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'KazeGarage-App',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> json = jsonDecode(response.body);

      final String tag = (json['tag_name'] ?? '').toString();
      if (tag.isEmpty) return null;

      // Lewati release yang berstatus draft atau prerelease.
      if (json['draft'] == true || json['prerelease'] == true) return null;

      final String latestVersion = _normalizeVersion(tag);
      if (latestVersion.isEmpty) return null;

      final info = await PackageInfo.fromPlatform();
      final String currentVersion = info.version;

      // Tidak ada update kalau versi GitHub tidak lebih baru.
      if (_compareVersions(latestVersion, currentVersion) <= 0) return null;

      // Cari asset APK kalau ada.
      String? apkUrl;
      final assets = json['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is Map &&
              (asset['name'] ?? '').toString().toLowerCase().endsWith(
                '.apk',
              )) {
            apkUrl = (asset['browser_download_url'] ?? '').toString();
            if (apkUrl.isEmpty) apkUrl = null;
            break;
          }
        }
      }

      return UpdateInfo(
        latestVersion: latestVersion,
        tag: tag,
        currentVersion: currentVersion,
        releaseName: (json['name'] ?? '').toString(),
        releaseNotes: (json['body'] ?? '').toString(),
        releaseUrl: (json['html_url'] ?? '').toString(),
        apkUrl: apkUrl,
      );
    } catch (_) {
      // Offline atau error apa pun → anggap tidak ada update.
      return null;
    }
  }

  /// Bersihkan tag versi: hilangkan prefix "v" dan whitespace.
  /// "v1.2.0" → "1.2.0", "V1.0" → "1.0".
  String _normalizeVersion(String raw) {
    var v = raw.trim();
    if (v.toLowerCase().startsWith('v')) {
      v = v.substring(1);
    }
    // Buang metadata build seperti "1.2.0+3" atau "-beta".
    v = v.split('+').first.split('-').first.trim();
    return v;
  }

  /// Bandingkan dua versi semantic numerik.
  /// Return: >0 jika [a] > [b], 0 jika sama, <0 jika [a] < [b].
  /// "1.10.0" dianggap lebih besar dari "1.9.0".
  int _compareVersions(String a, String b) {
    final pa = _versionParts(a);
    final pb = _versionParts(b);
    final maxLen = pa.length > pb.length ? pa.length : pb.length;
    for (int i = 0; i < maxLen; i++) {
      final na = i < pa.length ? pa[i] : 0;
      final nb = i < pb.length ? pb[i] : 0;
      if (na != nb) return na - nb;
    }
    return 0;
  }

  List<int> _versionParts(String v) {
    return v
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}