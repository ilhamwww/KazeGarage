// Scan Receipt Screen - Kamera + OCR untuk memindai struk BBM
// Menggunakan Google ML Kit Text Recognition untuk ekstrak teks dari struk

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/transaction_provider.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _rawOcrText;
  String? _errorMessage;

  // Extracted data from OCR
  double? _extractedLiters;
  double? _extractedPricePerLiter;
  double? _extractedTotal;
  String? _extractedFuelType;

  // Editable controllers (pre-filled from OCR)
  final _litersController = TextEditingController();
  final _priceController = TextEditingController();
  final _totalController = TextEditingController();
  final _odometerController = TextEditingController();
  final _notesController = TextEditingController();

  Vehicle? _selectedVehicle;
  DateTime _selectedDate = DateTime.now();
  bool _showManualInput = false;

  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    _litersController.addListener(_recalculateTotal);
    _priceController.addListener(_recalculateTotal);
  }

  @override
  void dispose() {
    _litersController.dispose();
    _priceController.dispose();
    _totalController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  void _recalculateTotal() {
    final liters = double.tryParse(_litersController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    if (liters > 0 && price > 0) {
      _totalController.text = (liters * price).toStringAsFixed(0);
    }
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final granted = await _requestCameraPermission();
        if (!granted) {
          setState(() => _errorMessage = 'Izin kamera diperlukan untuk memindai struk.');
          return;
        }
      }

      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _isProcessing = true;
        _errorMessage = null;
        _rawOcrText = null;
        _showManualInput = false;
      });

      await _processImage();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Gagal mengambil gambar: $e';
      });
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    try {
      final inputImage = InputImage.fromFile(_imageFile!);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      setState(() {
        _rawOcrText = recognizedText.text;
        _isProcessing = false;
      });

      _extractReceiptData(recognizedText.text);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Gagal memproses gambar: $e';
      });
    }
  }

  void _extractReceiptData(String ocrText) {
    final text = ocrText.toUpperCase();
    final lines = ocrText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    double? liters;
    double? pricePerLiter;
    double? total;
    String? fuelType;

    // Try to find fuel type
    final fuelTypes = ['PERTALITE', 'PERTAMAX TURBO', 'PERTAMAX', 'DEXLITE', 'BIO SOLAR', 'SOLAR', 'DEX', 'PREMIUM'];
    for (final ft in fuelTypes) {
      if (text.contains(ft)) {
        fuelType = ft;
        break;
      }
    }

    // Try to find liters/volume - Pertamina format: "Volume : (L) 27.77" or "Volume : 27.77 L"
    final literPatterns = [
      RegExp(r'Volume\s*:\s*\(L\)\s*(\d+[.,]\d+)', caseSensitive: false),
      RegExp(r'Volume\s*:\s*(\d+[.,]\d+)\s*\(L\)', caseSensitive: false),
      RegExp(r'Volume\s*:\s*(\d+[.,]\d+)', caseSensitive: false),
      RegExp(r'(\d+[.,]\d+)\s*(?:L|LTR|LITER|LT)\b', caseSensitive: false),
      RegExp(r'(?:L|LTR|LITER|LT)\s*[:=]?\s*(\d+[.,]\d+)', caseSensitive: false),
      RegExp(r'(?:VOLUME|JUMLAH|QTY)\s*[:=]?\s*(\d+[.,]\d+)', caseSensitive: false),
    ];

    for (final pattern in literPatterns) {
      final match = pattern.firstMatch(ocrText);
      if (match != null) {
        final valueStr = match.group(1)!.replaceAll(',', '.');
        liters = double.tryParse(valueStr);
        if (liters != null && liters > 0) break;
      }
    }

    // Try to find price per liter - Pertamina format: "Harga/Liter : Rp. 9,000" or "Harga/Liter: Rp. 13,500"
    final pricePatterns = [
      RegExp(r'Harga/Liter\s*:\s*Rp\.?\s*(\d{1,3}[.,]?\d{0,3})', caseSensitive: false),
      RegExp(r'Harga\s*:\s*Rp\.?\s*(\d{1,3}[.,]?\d{0,3})', caseSensitive: false),
      RegExp(r'(?:HARGA|PRICE)\s*[:=]?\s*(?:RP\.?\s*)?(\d+[.,]?\d*)', caseSensitive: false),
      RegExp(r'(?:RP\.?\s*)(\d{4,6})\s*/?\s*(?:L|LTR|LITER)?', caseSensitive: false),
      RegExp(r'(\d{4,6})\s*/\s*(?:L|LTR|LITER)', caseSensitive: false),
    ];

    for (final pattern in pricePatterns) {
      final match = pattern.firstMatch(ocrText);
      if (match != null) {
        final valueStr = match.group(1)!.replaceAll('.', '').replaceAll(',', '.');
        pricePerLiter = double.tryParse(valueStr);
        if (pricePerLiter != null && pricePerLiter > 1000) break;
        pricePerLiter = null;
      }
    }

    // Try to find total - Pertamina format: "Total Harga : Rp. 250,000" or "CASH 250,000"
    final totalPatterns = [
      RegExp(r'Total Harga\s*:\s*Rp\.?\s*(\d{1,3}[.,]?\d{3}(?:[.,]?\d{3})*)', caseSensitive: false),
      RegExp(r'Total\s*:\s*Rp\.?\s*(\d{1,3}[.,]?\d{3}(?:[.,]?\d{3})*)', caseSensitive: false),
      RegExp(r'(?:TOTAL|JUMLAH|TAGIHAN)\s*[:=]?\s*(?:RP\.?\s*)?(\d+[.,]?\d*)', caseSensitive: false),
      RegExp(r'(?:RP\.?\s*)(\d{5,9})', caseSensitive: false),
    ];

    for (final pattern in totalPatterns) {
      final match = pattern.firstMatch(ocrText);
      if (match != null) {
        final valueStr = match.group(1)!.replaceAll('.', '').replaceAll(',', '.');
        total = double.tryParse(valueStr);
        if (total != null && total > 1000) break;
        total = null;
      }
    }

    // Try to parse all numbers from lines as fallback
    if (liters == null || pricePerLiter == null || total == null) {
      final allNumbers = <double>[];
      for (final line in lines) {
        final numMatches = RegExp(r'(\d+[.,]?\d*)').allMatches(line);
        for (final m in numMatches) {
          final s = m.group(1)!.replaceAll(',', '.');
          final n = double.tryParse(s);
          if (n != null && n > 0) allNumbers.add(n);
        }
      }

      // Heuristic: small number (1-200) is likely liters, medium (5000-20000) is price/liter, large is total
      if (liters == null) {
        for (final n in allNumbers) {
          if (n >= 0.5 && n <= 200) {
            liters = n;
            break;
          }
        }
      }
      if (pricePerLiter == null) {
        for (final n in allNumbers) {
          if (n >= 5000 && n <= 25000) {
            pricePerLiter = n;
            break;
          }
        }
      }
      if (total == null && liters != null && pricePerLiter != null) {
        total = liters * pricePerLiter;
      }
    }

    setState(() {
      _extractedLiters = liters;
      _extractedPricePerLiter = pricePerLiter;
      _extractedTotal = total;
      _extractedFuelType = fuelType;
      _showManualInput = true;
    });

    // Pre-fill controllers
    if (liters != null) _litersController.text = liters.toStringAsFixed(1);
    if (pricePerLiter != null) _priceController.text = pricePerLiter.toStringAsFixed(0);
    if (total != null) {
      _totalController.text = total.toStringAsFixed(0);
    } else if (liters != null && pricePerLiter != null) {
      _totalController.text = (liters * pricePerLiter).toStringAsFixed(0);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: AppColors.background,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kendaraan terlebih dahulu'), backgroundColor: AppColors.chartRed),
      );
      return;
    }

    final liters = double.tryParse(_litersController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final total = double.tryParse(_totalController.text) ?? 0;

    if (liters <= 0 || price <= 0 || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi liter, harga, dan total dengan benar'), backgroundColor: AppColors.chartRed),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<TransactionProvider>();
    final notes = _notesController.text.isNotEmpty
        ? _notesController.text
        : (_extractedFuelType != null ? 'Jenis: $_extractedFuelType (Scan OCR)' : 'Scan OCR');

    final success = await provider.addTransaction(
      vehicleId: _selectedVehicle!.id,
      date: _selectedDate,
      totalCost: total,
      liters: liters,
      pricePerLiter: price,
      odometer: _odometerController.text.isNotEmpty ? double.tryParse(_odometerController.text) : null,
      notes: notes,
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi berhasil disimpan dari scan struk'),
          backgroundColor: AppColors.accent,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan transaksi'), backgroundColor: AppColors.chartRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Struk'),
        actions: [
          if (_imageFile != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Scan Ulang',
              onPressed: () {
                setState(() {
                  _imageFile = null;
                  _rawOcrText = null;
                  _showManualInput = false;
                  _errorMessage = null;
                  _extractedLiters = null;
                  _extractedPricePerLiter = null;
                  _extractedTotal = null;
                  _extractedFuelType = null;
                  _litersController.clear();
                  _priceController.clear();
                  _totalController.clear();
                  _odometerController.clear();
                  _notesController.clear();
                });
              },
            ),
        ],
      ),
      body: _imageFile == null ? _buildSourceSelector() : _buildResultView(),
    );
  }

  Widget _buildSourceSelector() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.document_scanner, size: 64, color: AppColors.accent),
            ),
            const SizedBox(height: 32),
            const Text(
              'Pindai Struk BBM',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ambil foto atau pilih gambar struk pengisian BBM untuk mengekstrak data secara otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Buka Kamera'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Pilih dari Galeri'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.chartRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.chartRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.chartRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return Column(
      children: [
        // Image preview
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_imageFile!, fit: BoxFit.cover),
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.accent),
                        SizedBox(height: 12),
                        Text('Memproses gambar...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // OCR result / manual input form
        Expanded(
          child: _isProcessing
              ? const SizedBox()
              : _showManualInput
                  ? _buildEditForm()
                  : _buildOcrResult(),
        ),
      ],
    );
  }

  Widget _buildOcrResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_rawOcrText != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Teks Terdeteksi:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _rawOcrText!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showManualInput = true),
                icon: const Icon(Icons.edit),
                label: const Text('Input Manual'),
              ),
            ),
          ] else ...[
            const Center(
              child: Text('Tidak ada teks yang terdeteksi', style: TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showManualInput = true),
                icon: const Icon(Icons.edit),
                label: const Text('Input Manual'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Extraction summary
          if (_extractedLiters != null || _extractedPricePerLiter != null || _extractedTotal != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data terdeteksi dari struk${_extractedFuelType != null ? " ($_extractedFuelType)" : ""}. Periksa dan edit jika perlu.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          // Vehicle selector
          const Text('Kendaraan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Consumer<VehicleProvider>(
            builder: (context, vehicleProvider, _) {
              if (vehicleProvider.vehicles.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.chartRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Tambahkan kendaraan terlebih dahulu di menu Garasi.',
                    style: TextStyle(color: AppColors.chartRed, fontSize: 13),
                  ),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Vehicle>(
                    value: _selectedVehicle,
                    hint: const Text('Pilih kendaraan'),
                    isExpanded: true,
                    items: vehicleProvider.vehicles.map((v) {
                      return DropdownMenuItem(
                        value: v,
                        child: Text('${v.name} - ${v.licensePlate}'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedVehicle = v),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Date
          const Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate),
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Liters
          _buildField(
            controller: _litersController,
            label: 'Jumlah Liter',
            hint: 'Contoh: 35.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: 'L',
            isDetected: _extractedLiters != null,
          ),
          const SizedBox(height: 12),

          // Price per liter
          _buildField(
            controller: _priceController,
            label: 'Harga per Liter',
            hint: 'Contoh: 13500',
            keyboardType: TextInputType.number,
            prefix: 'Rp',
            isDetected: _extractedPricePerLiter != null,
          ),
          const SizedBox(height: 12),

          // Total
          _buildField(
            controller: _totalController,
            label: 'Total Biaya',
            hint: 'Otomatis dari liter × harga',
            keyboardType: TextInputType.number,
            prefix: 'Rp',
            isDetected: _extractedTotal != null,
          ),
          const SizedBox(height: 12),

          // Odometer
          _buildField(
            controller: _odometerController,
            label: 'Odometer (Opsional)',
            hint: 'Contoh: 15230',
            keyboardType: TextInputType.number,
            suffix: 'km',
          ),
          const SizedBox(height: 12),

          // Notes
          _buildField(
            controller: _notesController,
            label: 'Catatan (Opsional)',
            hint: 'Catatan tambahan...',
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                    )
                  : const Text('Simpan Transaksi'),
            ),
          ),
          const SizedBox(height: 16),

          // OCR raw text toggle
          if (_rawOcrText != null && _rawOcrText!.isNotEmpty)
            ExpansionTile(
              title: const Text(
                'Teks OCR Mentah',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _rawOcrText!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? prefix,
    String? suffix,
    bool isDetected = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
            if (isDetected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('OCR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accent)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix != null ? '$prefix ' : null,
            suffixText: suffix,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}