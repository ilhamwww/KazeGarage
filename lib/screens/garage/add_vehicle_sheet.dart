// Bottom sheet untuk menambah/edit kendaraan

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/vehicle.dart';
import '../../providers/vehicle_provider.dart';

class AddVehicleSheet extends StatefulWidget {
  final Vehicle? vehicle; // null = tambah baru, non-null = edit

  const AddVehicleSheet({super.key, this.vehicle});

  @override
  State<AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<AddVehicleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _tankController = TextEditingController();
  bool _isLoading = false;

  bool get isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.vehicle!.name;
      _plateController.text = widget.vehicle!.licensePlate;
      _tankController.text = widget.vehicle!.tankCapacity.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _tankController.dispose();
    super.dispose();
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
      );
      success = await provider.updateVehicle(updated);
    } else {
      success = await provider.addVehicle(
        name: _nameController.text.trim(),
        licensePlate: _plateController.text.trim().toUpperCase(),
        tankCapacity: double.tryParse(_tankController.text) ?? 0,
      );
    }

    setState(() => _isLoading = false);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Kendaraan diperbarui' : 'Kendaraan ditambahkan'),
          backgroundColor: AppColors.chartGreen,
        ),
      );
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan kendaraan'),
          backgroundColor: AppColors.chartRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                // Handle bar
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 24),
                // Nama kendaraan
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kendaraan',
                    hintText: 'Contoh: Honda Beat',
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama kendaraan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Plat nomor
                TextFormField(
                  controller: _plateController,
                  decoration: const InputDecoration(
                    labelText: 'Plat Nomor',
                    hintText: 'Contoh: B 1234 ABC',
                    prefixIcon: Icon(Icons.confirmation_number),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Plat nomor wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Kapasitas tangki
                TextFormField(
                  controller: _tankController,
                  decoration: const InputDecoration(
                    labelText: 'Kapasitas Tangki (Liter)',
                    hintText: 'Contoh: 15',
                    prefixIcon: Icon(Icons.local_gas_station),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Kapasitas tangki wajib diisi';
                    }
                    final n = double.tryParse(value);
                    if (n == null || n <= 0) {
                      return 'Masukkan angka yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Tombol simpan
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : Text(isEditing ? 'Perbarui' : 'Simpan'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}