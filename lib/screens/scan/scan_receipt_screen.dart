// Scan Receipt Screen - Kamera + OCR untuk memindai struk BBM
// Hasil ditampilkan dalam card receipt-style yang elegan

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaze_app_bar.dart';
import '../../core/widgets/kaze_notifier.dart';
import '../../data/models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/transaction_provider.dart';
import '../transaction/add_transaction_screen.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Extracted data from OCR
  double? _extractedLiters;
  double? _extractedPricePerLiter;
  double? _extractedTotal;
  String? _extractedFuelType;
  String? _spbuName;
  String? _spbuCode;

  Vehicle? _selectedVehicle;
  DateTime _selectedDate = DateTime.now();
  final _odometerController = TextEditingController();

  static const List<String> _fuelTypeOptions = [
    'Pertalite',
    'Pertamax',
    'Pertamax Turbo',
    'Solar',
    'Dexlite',
    'Bio Solar',
    'Premium',
  ];

  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    // Auto-select active vehicle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vp = context.read<VehicleProvider>();
      if (vp.vehicles.isEmpty) {
        vp.loadVehicles().then((_) {
          if (!mounted) return;
          setState(() => _selectedVehicle = vp.activeVehicle);
        });
      } else {
        setState(() => _selectedVehicle = vp.activeVehicle);
      }
    });
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _odometerController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted;
    } else {
      if (Platform.isAndroid) {
        final mediaStatus = await Permission.photos.request();
        if (mediaStatus.isGranted) return true;
        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      }
      return true;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final granted = await _requestPermission(source);
      if (!granted) {
        setState(
          () => _errorMessage = source == ImageSource.camera
              ? 'Izin kamera diperlukan untuk memindai struk.'
              : 'Izin galeri diperlukan untuk memilih gambar.',
        );
        return;
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

  double? _parseIndonesianNumber(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && hasDot) {
      final lastComma = s.lastIndexOf(',');
      final lastDot = s.lastIndexOf('.');
      if (lastComma > lastDot) {
        return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
      } else {
        return double.tryParse(s.replaceAll(',', ''));
      }
    } else if (hasComma) {
      final parts = s.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        return double.tryParse(s.replaceAll(',', '.'));
      } else {
        return double.tryParse(s.replaceAll(',', ''));
      }
    } else if (hasDot) {
      final parts = s.split('.');
      if (parts.length == 2 && parts[1].length <= 2) {
        return double.tryParse(s);
      } else {
        return double.tryParse(s.replaceAll('.', ''));
      }
    }
    return double.tryParse(s);
  }

  void _extractReceiptData(String ocrText) {
    final text = ocrText.toUpperCase();
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    double? liters;
    double? pricePerLiter;
    double? total;
    String? fuelType;
    String? spbuName;
    String? spbuCode;

    // Detect SPBU name (Pertamina/Shell/BP/Vivo)
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.contains('PERTAMINA')) {
        spbuName = 'SPBU PERTAMINA';
        break;
      }
      if (upper.contains('SHELL')) {
        spbuName = 'SHELL';
        break;
      }
      if (upper.contains('VIVO')) {
        spbuName = 'VIVO';
        break;
      }
      if (upper.contains('BP ')) {
        spbuName = 'BP';
        break;
      }
    }
    spbuName ??= 'SPBU';

    // SPBU code: pattern XX.XXXXX (e.g., 34.12301)
    final codeMatch = RegExp(r'\b(\d{2}\.\d{4,5})\b').firstMatch(ocrText);
    if (codeMatch != null) {
      spbuCode = codeMatch.group(1);
    }

    // Fuel type
    final fuelTypes = [
      'PERTAMAX TURBO',
      'PERTAMAX',
      'PERTALITE',
      'DEXLITE',
      'BIO SOLAR',
      'SOLAR',
      'DEX',
      'PREMIUM',
      'V-POWER',
      'SUPER',
    ];
    for (final ft in fuelTypes) {
      if (text.contains(ft)) {
        fuelType = _capitalize(ft);
        break;
      }
    }

    // Volume / liters
    final literPatterns = [
      RegExp(
        r'[Vv]olume\s*[:=]\s*\(?\s*[Ll]\s*\)?\s*(\d+[.,]\d+)',
        caseSensitive: false,
      ),
      RegExp(r'[Vv]olume\s*[:=]\s*(\d+[.,]\d+)', caseSensitive: false),
      RegExp(r'[Vv]olume\s+(\d+[.,]\d+)', caseSensitive: false),
      RegExp(r'\(?[Ll]\)?\s*(\d+[.,]\d+)', caseSensitive: false),
      RegExp(
        r'(?:^|\s)(?:L|Liter|LT)\s*[:=]\s*(\d+[.,]\d+)',
        caseSensitive: false,
      ),
      RegExp(r'(\d+[.,]\d{1,2})\s*(?:L|LTR|Liter|LT)\b', caseSensitive: false),
    ];
    for (final p in literPatterns) {
      final m = p.firstMatch(ocrText);
      if (m != null) {
        liters = _parseIndonesianNumber(m.group(1)!);
        if (liters != null && liters > 0 && liters < 500) break;
        liters = null;
      }
    }

    // Price/liter
    final pricePatterns = [
      RegExp(
        r'[Hh]arga\s*/\s*[Ll]iter\s*[:=]?\s*[Rr][Pp]\.?\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'[Hh]arga\s*/\s*[Ll]iter\s*[:=]\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'[Hh]arga\s*[:=]\s*[Rr][Pp]\.?\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(r'[Rr][Pp]\.?\s*(\d[.,\d]+)\s*/\s*[Ll]', caseSensitive: false),
      RegExp(r'(\d[.,\d]+)\s*/\s*(?:L|Liter|LTR)', caseSensitive: false),
    ];
    for (final p in pricePatterns) {
      final m = p.firstMatch(ocrText);
      if (m != null) {
        pricePerLiter = _parseIndonesianNumber(m.group(1)!);
        if (pricePerLiter != null &&
            pricePerLiter >= 1000 &&
            pricePerLiter <= 50000) {
          break;
        }
        pricePerLiter = null;
      }
    }

    // Total
    final totalPatterns = [
      RegExp(
        r'[Tt]otal\s*[Hh]arga\s*[:=]?\s*[Rr][Pp]\.?\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'[Tt]otal\s*[:=]\s*[Rr][Pp]\.?\s*(\d[.,\d]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:TOTAL|JUMLAH|TAGIHAN)\s*[:=]?\s*(?:RP\.?\s*)?(\d[.,\d]+)',
        caseSensitive: false,
      ),
    ];
    for (final p in totalPatterns) {
      final m = p.firstMatch(ocrText);
      if (m != null) {
        total = _parseIndonesianNumber(m.group(1)!);
        if (total != null && total > 1000) break;
        total = null;
      }
    }

    // Fallback: derive total from liters * price
    if (liters != null && pricePerLiter != null) {
      total = liters * pricePerLiter;
    }

    setState(() {
      _extractedLiters = liters;
      _extractedPricePerLiter = pricePerLiter;
      _extractedTotal = total;
      _extractedFuelType = fuelType;
      _spbuName = spbuName;
      _spbuCode = spbuCode;
    });
  }

  String _capitalize(String s) {
    return s
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0] + w.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  Future<void> _save() async {
    if (_selectedVehicle == null) {
      KazeNotifier.error(context, 'Pilih kendaraan terlebih dahulu');
      return;
    }
    if (_extractedLiters == null ||
        _extractedPricePerLiter == null ||
        _extractedTotal == null) {
      KazeNotifier.error(
        context,
        'Data struk tidak lengkap, scan ulang atau input manual',
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<TransactionProvider>();
    final notes =
        '${_spbuName ?? "SPBU"}${_spbuCode != null ? " - $_spbuCode" : ""}';

    final odometer = double.tryParse(_odometerController.text.trim());

    final success = await provider.addTransaction(
      vehicleId: _selectedVehicle!.id,
      date: _selectedDate,
      totalCost: _extractedTotal!,
      liters: _extractedLiters!,
      pricePerLiter: _extractedPricePerLiter!,
      notes: notes,
      fuelType: _extractedFuelType,
      odometer: odometer,
    );
    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context);
      KazeNotifier.success(context, 'Transaksi berhasil disimpan');
    } else if (mounted) {
      KazeNotifier.error(context, 'Gagal menyimpan transaksi');
    }
  }

  void _resetScan() {
    setState(() {
      _imageFile = null;
      _errorMessage = null;
      _extractedLiters = null;
      _extractedPricePerLiter = null;
      _extractedTotal = null;
      _extractedFuelType = null;
      _spbuName = null;
      _spbuCode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const KazeAppBar(),
      body: _imageFile == null ? _buildSourceSelector() : _buildResultView(),
    );
  }

  Widget _buildSourceSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan Struk',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pindai struk SPBU untuk mencatat otomatis',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 56,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt, size: 20),
              label: const Text('Buka Kamera'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 20),
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
          const SizedBox(height: 20),
          // Divider with "atau"
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'atau',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.divider)),
            ],
          ),
          const SizedBox(height: 20),
          // Manual input button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.edit_note_rounded,
                size: 22,
                color: AppColors.textPrimary,
              ),
              label: const Text(
                'Tambah Manual',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surfaceMuted,
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
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.chartRed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.chartRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultView() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text(
              'Memproses struk...',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hasil Scan Struk',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Verifikasi detail pengisian bahan bakar Anda',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Vehicle selector
          _buildVehicleSelector(),
          const SizedBox(height: 16),

          // Receipt-style card
          _buildReceiptCard(),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 20),
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Transaksi'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _resetScan,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Scan Ulang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector() {
    return Consumer<VehicleProvider>(
      builder: (context, vp, _) {
        if (vp.vehicles.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.chartRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.chartRed.withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'Tambahkan kendaraan di Garasi terlebih dahulu',
              style: TextStyle(color: AppColors.chartRed, fontSize: 13),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: _VehicleSelectorRow(
            selected: _selectedVehicle,
            vehicles: vp.vehicles,
            onSelected: (v) => setState(() => _selectedVehicle = v),
          ),
        );
      },
    );
  }

  Widget _buildReceiptCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _editSpbu,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _spbuName ?? 'SPBU',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: AppColors.textHint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _spbuCode != null
                            ? _spbuCode!
                            : 'Lokasi tidak terdeteksi',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_gas_station,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Dashed divider
          const _DashedDivider(),
          const SizedBox(height: 16),

          _buildEditableRow(
            label: 'Jenis BBM',
            value: _extractedFuelType ?? '-',
            onTap: _editFuelType,
          ),
          const SizedBox(height: 10),
          _buildEditableRow(
            label: 'Harga/Liter',
            value: _extractedPricePerLiter != null
                ? _formatCurrency(_extractedPricePerLiter!)
                : '-',
            onTap: () => _editNumber(
              title: 'Harga per Liter',
              currentValue: _extractedPricePerLiter,
              isDecimal: false,
              prefix: 'Rp',
              onSave: (v) => setState(() {
                _extractedPricePerLiter = v;
                _recalculateTotal();
              }),
            ),
          ),
          const SizedBox(height: 10),
          _buildEditableRow(
            label: 'Volume',
            value: _extractedLiters != null
                ? '${_extractedLiters!.toStringAsFixed(2)} Liters'
                : '-',
            onTap: () => _editNumber(
              title: 'Jumlah Liter',
              currentValue: _extractedLiters,
              isDecimal: true,
              suffix: 'L',
              onSave: (v) => setState(() {
                _extractedLiters = v;
                _recalculateTotal();
              }),
            ),
          ),
          const SizedBox(height: 10),
          _buildEditableRow(
            label: 'Tanggal & Waktu',
            value: DateFormat(
              'dd MMMM yyyy · HH:mm',
              'id_ID',
            ).format(_selectedDate),
            onTap: _editDateTime,
          ),
          const SizedBox(height: 10),
          _buildEditableRow(
            label: 'Odometer',
            value: _odometerController.text.isNotEmpty
                ? '${_odometerController.text} km'
                : '-',
            onTap: _editOdometer,
          ),
          const SizedBox(height: 16),
          const _DashedDivider(),
          const SizedBox(height: 14),
          // Total
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL PEMBAYARAN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _editNumber(
              title: 'Total Pembayaran',
              currentValue: _extractedTotal,
              isDecimal: false,
              prefix: 'Rp',
              onSave: (v) => setState(() => _extractedTotal = v),
            ),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _extractedTotal != null
                      ? _formatCurrency(_extractedTotal!)
                      : '-',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _recalculateTotal() {
    if (_extractedLiters != null && _extractedPricePerLiter != null) {
      _extractedTotal = _extractedLiters! * _extractedPricePerLiter!;
    }
  }

  Widget _buildEditableRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.edit_outlined, size: 13, color: AppColors.textHint),
        ],
      ),
    );
  }

  Future<void> _editNumber({
    required String title,
    required double? currentValue,
    required bool isDecimal,
    String? prefix,
    String? suffix,
    required ValueChanged<double> onSave,
  }) async {
    final controller = TextEditingController(
      text: currentValue != null
          ? (isDecimal
                ? currentValue.toStringAsFixed(2)
                : currentValue.toStringAsFixed(0))
          : '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          decoration: InputDecoration(
            prefixText: prefix != null ? '$prefix ' : null,
            suffixText: suffix,
            filled: true,
            fillColor: AppColors.surfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = controller.text.replaceAll(',', '.');
              final v = double.tryParse(raw);
              if (v != null && v > 0) {
                onSave(v);
                Navigator.pop(ctx);
              } else {
                KazeNotifier.error(ctx, 'Masukkan angka yang valid');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSpbu() async {
    final nameController = TextEditingController(text: _spbuName ?? '');
    final codeController = TextEditingController(text: _spbuCode ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit SPBU'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Nama SPBU',
                hintText: 'Contoh: SPBU PERTAMINA',
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'Kode SPBU (Opsional)',
                hintText: 'Contoh: 34.12301',
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _spbuName = nameController.text.trim().isEmpty
                    ? null
                    : nameController.text.trim();
                _spbuCode = codeController.text.trim().isEmpty
                    ? null
                    : codeController.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _editFuelType() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Jenis BBM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _fuelTypeOptions.map((type) {
                  final isSelected = _extractedFuelType == type;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _extractedFuelType = type);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editOdometer() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Input Odometer'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: _odometerController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Contoh: 45000',
            suffixText: 'km',
            filled: true,
            fillColor: AppColors.surfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _editDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }
}

class _VehicleSelectorRow extends StatelessWidget {
  final Vehicle? selected;
  final List<Vehicle> vehicles;
  final ValueChanged<Vehicle> onSelected;

  const _VehicleSelectorRow({
    required this.selected,
    required this.vehicles,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSelector(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KENDARAAN TERPILIH',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selected != null
                      ? '${selected!.name} (${selected!.licensePlate})'
                      : 'Pilih kendaraan',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            selected != null ? Icons.check_circle : Icons.chevron_right,
            color: selected != null ? AppColors.success : AppColors.textHint,
            size: 22,
          ),
        ],
      ),
    );
  }

  void _showSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Pilih Kendaraan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ...vehicles.map(
              (v) => ListTile(
                leading: const Icon(
                  Icons.directions_car,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  v.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(v.licensePlate),
                trailing: v.id == selected?.id
                    ? const Icon(Icons.check_circle, color: AppColors.accent)
                    : null,
                onTap: () {
                  onSelected(v);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 1,
              color: AppColors.divider,
            ),
          ),
        );
      },
    );
  }
}
