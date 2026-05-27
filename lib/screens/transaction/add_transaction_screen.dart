// Form layar penuh untuk input transaksi pengisian BBM manual
// Digunakan saat user memilih "Input Manual" dari dashboard

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/transaction_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  final Vehicle? preSelectedVehicle;

  const AddTransactionScreen({super.key, this.preSelectedVehicle});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _litersController = TextEditingController();
  final _priceController = TextEditingController();
  final _totalController = TextEditingController();
  final _odometerController = TextEditingController();
  final _notesController = TextEditingController();

  Vehicle? _selectedVehicle;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String? _selectedFuelType;

  static const List<String> _fuelTypes = [
    'Pertalite',
    'Pertamax',
    'Pertamax Turbo',
    'Solar',
    'Dexlite',
  ];

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.preSelectedVehicle;
    _litersController.addListener(_calculateTotal);
    _priceController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _litersController.dispose();
    _priceController.dispose();
    _totalController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final liters = double.tryParse(_litersController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    if (liters > 0 && price > 0) {
      _totalController.text = (liters * price).toStringAsFixed(0);
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kendaraan terlebih dahulu'), backgroundColor: AppColors.chartRed),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<TransactionProvider>();
    final success = await provider.addTransaction(
      vehicleId: _selectedVehicle!.id,
      date: _selectedDate,
      totalCost: double.parse(_totalController.text),
      liters: double.parse(_litersController.text),
      pricePerLiter: double.parse(_priceController.text),
      odometer: _odometerController.text.isNotEmpty ? double.tryParse(_odometerController.text) : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      fuelType: _selectedFuelType,
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi berhasil disimpan'),
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
        title: const Text('Input Transaksi'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
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
            const SizedBox(height: 20),

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
            const SizedBox(height: 20),

            // Liters
            _buildTextField(
              controller: _litersController,
              label: 'Jumlah Liter',
              hint: 'Contoh: 35.5',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              suffix: 'L',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if ((double.tryParse(v) ?? 0) <= 0) return 'Harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Price per liter
            _buildTextField(
              controller: _priceController,
              label: 'Harga per Liter',
              hint: 'Contoh: 13500',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefix: 'Rp',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if ((double.tryParse(v) ?? 0) <= 0) return 'Harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Fuel type (optional)
            const Text('Jenis BBM (Opsional)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _fuelTypes.map((type) {
                final isSelected = _selectedFuelType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFuelType = selected ? type : null;
                    });
                  },
                  selectedColor: AppColors.accent.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.accent : AppColors.divider,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Total (auto-calculated)
            _buildTextField(
              controller: _totalController,
              label: 'Total Biaya (Otomatis)',
              hint: 'Otomatis dari liter × harga',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefix: 'Rp',
              readOnly: true,
            ),
            const SizedBox(height: 16),

            // Odometer (optional)
            _buildTextField(
              controller: _odometerController,
              label: 'Odometer (Opsional)',
              hint: 'Contoh: 15230',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffix: 'km',
            ),
            const SizedBox(height: 16),

            // Notes (optional)
            _buildTextField(
              controller: _notesController,
              label: 'Catatan (Opsional)',
              hint: 'SPBU Pertamina, catatan kaki nota, dll.',
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
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
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefix,
    String? suffix,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix != null ? '$prefix ' : null,
            suffixText: suffix,
            filled: true,
            fillColor: readOnly ? AppColors.surface.withValues(alpha: 0.7) : AppColors.surface,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}