// Bottom sheet untuk menambah/edit catatan servis kendaraan.
//
// Auto-suggest reminder berikutnya berdasarkan interval yang sudah
// di-input user di Garasi (serviceIntervalKm + serviceIntervalMonths).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaze_notifier.dart';
import '../../data/models/service_record.dart';
import '../../data/models/vehicle.dart';
import '../../providers/service_provider.dart';
import '../../providers/vehicle_provider.dart';

class AddServiceSheet extends StatefulWidget {
  /// Catatan untuk mode edit. Null = mode tambah baru.
  final ServiceRecord? record;

  /// Pre-select kendaraan saat tambah baru (opsional).
  final String? initialVehicleId;

  const AddServiceSheet({super.key, this.record, this.initialVehicleId});

  @override
  State<AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends State<AddServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _odometerController = TextEditingController();
  final _customTypeController = TextEditingController();
  final _costController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedVehicleId;
  String? _selectedType;
  bool _isCustomType = false;
  DateTime _date = DateTime.now();

  // Reminder berikutnya (auto-filled dari interval kendaraan)
  bool _hasNextReminder = false;
  DateTime? _nextDueDate;
  final _nextDueOdometerController = TextEditingController();

  bool _isLoading = false;

  bool get isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final r = widget.record!;
      _selectedVehicleId = r.vehicleId;
      _selectedType = ServiceTypes.presets.contains(r.serviceType)
          ? r.serviceType
          : 'Lainnya';
      _isCustomType = _selectedType == 'Lainnya';
      if (_isCustomType) _customTypeController.text = r.serviceType;
      _odometerController.text = r.odometer.toStringAsFixed(0);
      _costController.text = r.cost?.toStringAsFixed(0) ?? '';
      _locationController.text = r.location ?? '';
      _notesController.text = r.notes ?? '';
      _date = r.date;
      _hasNextReminder = r.nextDueDate != null || r.nextDueOdometer != null;
      _nextDueDate = r.nextDueDate;
      if (r.nextDueOdometer != null) {
        _nextDueOdometerController.text = r.nextDueOdometer!.toStringAsFixed(0);
      }
    } else {
      _selectedVehicleId = widget.initialVehicleId;
      _selectedType = ServiceTypes.presets.first;
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _customTypeController.dispose();
    _costController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _nextDueOdometerController.dispose();
    super.dispose();
  }

  /// Auto-fill reminder berdasarkan interval di Vehicle yang dipilih.
  void _autoSuggestReminder() {
    if (_selectedVehicleId == null) return;
    final vehicleProvider = context.read<VehicleProvider>();
    final vehicle = vehicleProvider.getVehicleById(_selectedVehicleId!);
    if (vehicle == null) return;

    final intervalKm = vehicle.serviceIntervalKm;
    final intervalMonths = vehicle.serviceIntervalMonths;

    if (intervalKm == null && intervalMonths == null) return;

    setState(() {
      _hasNextReminder = true;
      // Tanggal berikutnya
      if (intervalMonths != null && intervalMonths > 0) {
        _nextDueDate = DateTime(
          _date.year,
          _date.month + intervalMonths,
          _date.day,
        );
      }
      // Odometer berikutnya
      if (intervalKm != null && intervalKm > 0) {
        final currentOdo = double.tryParse(_odometerController.text.trim());
        if (currentOdo != null) {
          _nextDueOdometerController.text = (currentOdo + intervalKm)
              .toStringAsFixed(0);
        }
      }
    });
  }

  Future<void> _pickServiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
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
      setState(() => _date = picked);
    }
  }

  Future<void> _pickNextDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate ?? DateTime.now().add(const Duration(days: 30)),
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
      setState(() => _nextDueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleId == null) {
      KazeNotifier.error(context, 'Pilih kendaraan terlebih dahulu');
      return;
    }

    final type = _isCustomType
        ? _customTypeController.text.trim()
        : (_selectedType ?? 'Lainnya');
    if (type.isEmpty) {
      KazeNotifier.error(context, 'Jenis servis wajib diisi');
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<ServiceProvider>();

    final odometer = double.tryParse(_odometerController.text.trim()) ?? 0;
    final cost = double.tryParse(_costController.text.trim());
    final nextOdo = _hasNextReminder
        ? double.tryParse(_nextDueOdometerController.text.trim())
        : null;
    final nextDate = _hasNextReminder ? _nextDueDate : null;

    bool success;
    if (isEditing) {
      final updated = widget.record!.copyWith(
        vehicleId: _selectedVehicleId!,
        date: _date,
        serviceType: type,
        odometer: odometer,
        cost: cost,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        nextDueDate: nextDate,
        nextDueOdometer: nextOdo,
      );
      success = await provider.updateRecord(updated);
    } else {
      success = await provider.addRecord(
        vehicleId: _selectedVehicleId!,
        date: _date,
        serviceType: type,
        odometer: odometer,
        cost: cost,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        nextDueDate: nextDate,
        nextDueOdometer: nextOdo,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.pop(context);
      KazeNotifier.success(
        context,
        isEditing ? 'Catatan servis diperbarui' : 'Catatan servis ditambahkan',
      );
    } else {
      KazeNotifier.error(context, 'Gagal menyimpan catatan servis');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = context.watch<VehicleProvider>().vehicles;
    final selectedVehicle = _selectedVehicleId != null
        ? vehicles.firstWhere(
            (v) => v.id == _selectedVehicleId,
            orElse: () =>
                Vehicle(id: '', name: '', licensePlate: '', tankCapacity: 0),
          )
        : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEditing ? 'Edit Catatan Servis' : 'Catat Servis Baru',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Pilih kendaraan
                _buildLabel('Kendaraan'),
                const SizedBox(height: 8),
                if (vehicles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Belum ada kendaraan. Tambahkan di halaman Garasi dulu.',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: vehicles.map((v) {
                      final isSel = _selectedVehicleId == v.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedVehicleId = v.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel
                                  ? AppColors.primary
                                  : AppColors.divider,
                            ),
                          ),
                          child: Text(
                            '${v.name} • ${v.licensePlate}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),

                // Jenis servis
                _buildLabel('Jenis Servis'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ServiceTypes.presets.map((t) {
                    final isSel = _selectedType == t;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedType = t;
                        _isCustomType = t == 'Lainnya';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.accent : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSel ? AppColors.accent : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_isCustomType) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customTypeController,
                    decoration: _decoration(
                      'Tulis jenis servis (custom)',
                      icon: Icons.build_outlined,
                    ),
                    validator: (v) {
                      if (_isCustomType && (v == null || v.trim().isEmpty)) {
                        return 'Jenis servis wajib diisi';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Tanggal servis
                _buildLabel('Tanggal Servis'),
                const SizedBox(height: 6),
                _buildDateBox(_date, _pickServiceDate),
                const SizedBox(height: 16),

                // Odometer
                _buildLabel('Odometer (KM)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _odometerController,
                  decoration: _decoration('Contoh: 25000', icon: Icons.speed),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Odometer wajib diisi';
                    }
                    final n = double.tryParse(v);
                    if (n == null || n < 0) return 'Masukkan angka yang valid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Biaya (opsional)
                _buildLabel('Biaya Servis (opsional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _costController,
                  decoration: _decoration(
                    'Contoh: 350000',
                    icon: Icons.payments_outlined,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Lokasi (opsional)
                _buildLabel('Lokasi / Bengkel (opsional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _locationController,
                  decoration: _decoration(
                    'Nama bengkel / lokasi',
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // Catatan
                _buildLabel('Catatan (opsional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  decoration: _decoration(
                    'Catatan tambahan',
                    icon: Icons.notes_outlined,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Reminder berikutnya
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Reminder Servis Berikutnya',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Switch(
                            value: _hasNextReminder,
                            activeThumbColor: AppColors.accent,
                            onChanged: (v) =>
                                setState(() => _hasNextReminder = v),
                          ),
                        ],
                      ),
                      if (_hasNextReminder) ...[
                        const SizedBox(height: 4),
                        if (selectedVehicle != null &&
                            (selectedVehicle.serviceIntervalKm != null ||
                                selectedVehicle.serviceIntervalMonths != null))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Interval kendaraan: '
                                    '${selectedVehicle.serviceIntervalKm?.toStringAsFixed(0) ?? '-'} km / '
                                    '${selectedVehicle.serviceIntervalMonths ?? '-'} bulan',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _autoSuggestReminder,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 24),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Auto-isi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildLabel('Tanggal Servis Berikutnya'),
                        const SizedBox(height: 6),
                        _buildDateBox(_nextDueDate, _pickNextDueDate),
                        const SizedBox(height: 12),
                        _buildLabel('Odometer Berikutnya (KM)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nextDueOdometerController,
                          decoration: _decoration(
                            'Contoh: 30000',
                            icon: Icons.speed,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
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

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildDateBox(DateTime? date, VoidCallback onTap) {
    return GestureDetector(
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
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              date != null
                  ? DateFormat('dd MMM yyyy', 'id_ID').format(date)
                  : 'Pilih tanggal',
              style: TextStyle(
                fontSize: 13,
                color: date != null
                    ? AppColors.textPrimary
                    : AppColors.textHint,
                fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: AppColors.textSecondary)
          : null,
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
