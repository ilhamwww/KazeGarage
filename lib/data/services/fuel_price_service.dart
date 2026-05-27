// Service untuk scraping harga BBM dari isibens.in
// Diadaptasi dari kode Express/Cheerio (full.js) ke Dart menggunakan
// http + html package.

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/fuel_price.dart';

class FuelPriceService {
  static const String _sourceUrl = 'https://isibens.in';

  // Brands & RON sesuai struktur tabel di isibens.in
  static const List<String> _gasolineBrands = [
    'Pertamina',
    'Vivo',
    'BP',
    'Shell',
  ];
  static const List<String> _gasolineRons = ['90', '92', '95', '98'];
  static const List<String> _dieselBrands = ['Pertamina', 'BP', 'Shell'];
  static const List<String> _dieselRons = ['48', '51', '53'];

  /// Fetch dan parse harga BBM dari isibens.in
  Future<FuelPriceData> fetchPrices() async {
    final response = await http
        .get(
          Uri.parse(_sourceUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Gagal memuat harga BBM (HTTP ${response.statusCode})');
    }

    final document = html_parser.parse(response.body);

    // Update date — cari "ul.text-small li strong"
    String updateDate = _extractUpdateDate(document);

    final tables = document.querySelectorAll('table');
    if (tables.length < 2) {
      throw Exception(
        'Format halaman isibens.in berubah, tabel tidak ditemukan',
      );
    }

    final gasolineColumns = _getTableColumns(tables[0]);
    final dieselColumns = _getTableColumns(tables[1]);

    final gasoline = _formatBrandData(
      _gasolineBrands,
      _gasolineRons,
      gasolineColumns,
    );
    final diesel = _formatBrandData(_dieselBrands, _dieselRons, dieselColumns);

    return FuelPriceData(
      gasoline: gasoline,
      diesel: diesel,
      updateDate: updateDate,
      source: _sourceUrl,
    );
  }

  String _extractUpdateDate(Document document) {
    final strongElements = document.querySelectorAll('ul.text-small li strong');
    final combined = strongElements.map((e) => e.text).join(' ');
    final match = RegExp(r'\d+\s\w+\s\d+').firstMatch(combined);
    return match?.group(0) ?? 'Tanggal tidak ditemukan';
  }

  /// Mengembalikan data per kolom (brand) dari tabel.
  /// Setiap kolom berisi list cell text per baris (RON).
  List<List<String>> _getTableColumns(Element table) {
    final List<List<String>> columns = [];
    final rows = table.querySelectorAll('tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      for (int i = 0; i < cells.length; i++) {
        if (columns.length <= i) {
          columns.add([]);
        }
        columns[i].add(cells[i].text.trim());
      }
    }
    // Filter kolom kosong
    return columns.where((c) => c.isNotEmpty).toList();
  }

  List<FuelBrandPrices> _formatBrandData(
    List<String> brands,
    List<String> rons,
    List<List<String>> data,
  ) {
    final result = <FuelBrandPrices>[];
    for (int b = 0; b < brands.length; b++) {
      if (b >= data.length) break;
      final col = data[b];
      final items = <FuelPriceItem>[];
      for (int r = 0; r < rons.length; r++) {
        if (r >= col.length) break;
        final raw = col[r];
        final parsed = _parseCell(raw);
        items.add(
          FuelPriceItem(
            productName: parsed.productName,
            ron: rons[r],
            price: parsed.price,
          ),
        );
      }
      result.add(FuelBrandPrices(brand: brands[b], items: items));
    }
    return result;
  }

  /// Cell di isibens.in biasanya berformat:
  ///   "Rp14.400\nPertamax"
  ///   "—" atau kosong jika tidak tersedia
  _ParsedCell _parseCell(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '—' || trimmed == '-') {
      return _ParsedCell(productName: '', price: null);
    }

    // Split by whitespace/newline
    final parts = trimmed
        .split(RegExp(r'[\n\s]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return _ParsedCell(productName: '', price: null);

    // Bagian pertama adalah harga (Rp14.400), sisanya nama produk
    final priceStr = parts.first;
    final productName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    // Parse harga: hilangkan "Rp" dan separator titik/koma
    final cleaned = priceStr
        .replaceAll(RegExp(r'[Rr][Pp]\.?'), '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .trim();
    final price = double.tryParse(cleaned);

    return _ParsedCell(productName: productName, price: price);
  }
}

class _ParsedCell {
  final String productName;
  final double? price;

  _ParsedCell({required this.productName, required this.price});
}
