// Bottom sheet untuk menambah/edit kendaraan
// Mendukung gambar, tipe kendaraan, dan tanggal servis/pajak

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaze_notifier.dart';
import '../../data/models/vehicle.dart';
import '../../providers/vehicle_provider.dart';

class AddVehicleSheet extends StatefulWidget {
  final Vehicle? vehicle;

  const AddVehicleSheet({super.key, this.vehicle});

  @override
  State<AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<AddVehicleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _tankController = TextEditingController();

  String? _selectedType;
  DateTime? _serviceDate;
  DateTime? _taxDate;
  String? _imagePath;
  bool _isActive = false;
  bool _isLoading = false;

  static const List<String> _vehicleTypes = [
    'Mobil Penumpang',
    'Motor Sport',
    'Motor Bebek',
    'Motor Matic',
    'SUV',
    'Truk',
    'Lainnya',
  ];

  bool get isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final v = widget.vehicle!;
      _nameController.text = v.name;
      _plateController.text = v.licensePlate;
      _tankController.text = v.tankCapacity.toStringAsFixed(0);
      _selectedType = v.vehicleType;
      _serviceDate = v.serviceDate;
      _taxDate = v.taxDate;
      _imagePath = v.imageUrl;
      _isActive = v.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _tankController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  Future<void> _pickDate(bool isService) async {
    final initial = isService ? _serviceDate : _taxDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isService) {
          _serviceDate = picked;
        } else {
          _taxDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = context.read<VehicleProvider>();
    bool success;

    if (isEditing) {
      final updated = widget.vehicle!.copyWith(
        name: _nameController.text.trim(),
        licensePlate: _plateController.text.trim().toUpperCase(),
        tankCapacity: double.tryParse(_tankController.text) ?? 0,
        vehicleType: _selectedType,
        serviceDate: _serviceDate,
        taxDate: _taxDate,
        imageUrl: _imagePath,
        isActive: _isActive,
      );
      success = await provider.updateVehicle(updated);
      if (success && _isActive) {
        await provider.setActiveVehicle(updated.id);
      }
    } else {
      success = await provider.addVehicle(
        name: _nameController.text.trim(),
        licensePlate: _plateController.text.trim().toUpperCase(),
        tankCapacity: double.tryParse(_tankController.text) ?? 0,
        imageUrl: _imagePath,
        vehicleType: _selectedType,
        serviceDate: _serviceDate,
        taxDate: _taxDate,
        isActive: _isActive,
      );
    }

    setState(() => _isLoading = false);
    if (success && mounted) {
      Navigator.pop(context);
      KazeNotifier.success(context, isEditing ? 'Kendaraan diperbarui' : 'Kendaraan ditambahkan');
    } else if (!success && mounted) {
      KazeNotifier.error(context, 'Gagal menyimpan kendaraan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEditing ? 'Edit Kendaraan' : 'Tambah Kendaraan',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),

                // Image picker
                _buildImagePicker(),
                const SizedBox(height: 20),

                _buildLabel('Nama Kendaraan'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: _buildDecoration('Contoh: Honda Beat', icon: Icons.directions_car),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama kendaraan wajib diisi' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('Plat Nomor'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _plateController,
                  decoration: _buildDecoration('Contoh: B 1234 ABC', icon: Icons.confirmation_number),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Plat nomor wajib diisi' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('Kapasitas Tangki (Liter)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tankController,
                  decoration: _buildDecoration('Contoh: 15', icon: Icons.local_gas_station),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Kapasitas tangki wajib diisi';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Masukkan angka yang valid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildLabel('Tipe Kendaraan'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _vehicleTypes.map((t) {
                    final isSel = _selectedType == t;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = isSel ? null : t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSel ? AppColors.primary : AppColors.divider),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: _buildDateField('Tanggal Servis', _serviceDate, () => _pickDate(true))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDateField('Tanggal Pajak', _taxDate, () => _pickDate(false))),
                  ],
                ),
                const SizedBox(height: 16),

                // Active toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Set Sebagai Kendaraan Utama',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text('Akan dipakai default saat scan struk',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        activeThumbColor: AppColors.accent,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEditing ? 'Perbarui' : 'Simpan'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: _imagePath != null && _imagePath!.isNotEmpty && File(_imagePath!).existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(_imagePath!), fit: BoxFit.cover),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.textHint),
                  SizedBox(height: 6),
                  Text('Tambah Foto Kendaraan',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  date != null ? DateFormat('dd MMM yyyy', 'id_ID').format(date) : 'Pilih tanggal',
                  style: TextStyle(
                    fontSize: 13,
                    color: date != null ? AppColors.textPrimary : AppColors.textHint,
                    fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
      prefixIcon: icon != null ? Icon(icon, size: 18, color: AppColors.textSecondary) : null,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}