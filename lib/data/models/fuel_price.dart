// Model untuk harga BBM yang di-scrape dari isibens.in
// Disusun per brand (Pertamina/Vivo/BP/Shell) dengan list produk

class FuelPriceItem {
  final String productName; // e.g., "Pertamax Turbo"
  final String ron; // e.g., "98" atau CN "53"
  final double? price; // dalam Rupiah, null jika tidak tersedia

  FuelPriceItem({required this.productName, required this.ron, this.price});
}

class FuelBrandPrices {
  final String brand; // "Pertamina", "Vivo", "BP", "Shell"
  final List<FuelPriceItem> items;

  FuelBrandPrices({required this.brand, required this.items});
}

class FuelPriceData {
  final List<FuelBrandPrices> gasoline;
  final List<FuelBrandPrices> diesel;
  final String updateDate;
  final String source;
  final DateTime fetchedAt;

  FuelPriceData({
    required this.gasoline,
    required this.diesel,
    required this.updateDate,
    required this.source,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();
}
