import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionInputScreen extends StatefulWidget {
  const TransactionInputScreen({super.key});

  @override
  State<TransactionInputScreen> createState() => _TransactionInputScreenState();
}

class _CurrencyTextInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return const TextEditingValue(text: '');
    }

    int parsedValue = int.parse(cleanText);
    String formatted = _formatter.format(parsedValue).trim();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TransactionInputScreenState extends State<TransactionInputScreen> {
  // Mode Switcher: true = Sewa, false = Maintenance
  bool _isSewaMode = true;

  // Data dari Supabase
  List<Map<String, dynamic>> _carList = [];
  bool _isLoadingCars = true;
  bool _isSavingMaintenance = false;

  // Controller & State - Sewa
  final _namaPelangganController = TextEditingController();
  DateTime _tanggalMulai = DateTime.now();
  String? _selectedModel;
  String? _selectedPlat;
  // Diubah menjadi teks fleksibel (misal: '1.5 hari', '12 jam', dll)
  final _durasiController = TextEditingController(text: '1 hari');
  final _nominalSewaController = TextEditingController();

  // Controller & State - Maintenance
  String? _selectedPlatMaintenance;
  String _selectedJenisMaintenance = 'Ganti Oli';
  DateTime _tanggalMaintenance = DateTime.now(); // Tanggal Maintenance
  final _biayaPengeluaranController = TextEditingController();
  final _catatanMaintenanceController = TextEditingController();

  final List<String> _jenisMaintenanceList = [
    'Ganti Oli',
    'Servis Rutin',
    'Ganti Ban',
    'Perbaikan Rem',
    'Lainnya'
  ];

  @override
  void initState() {
    super.initState();
    _fetchCarsFromSupabase();
  }

  @override
  void dispose() {
    _namaPelangganController.dispose();
    _durasiController.dispose();
    _nominalSewaController.dispose();
    _biayaPengeluaranController.dispose();
    _catatanMaintenanceController.dispose();
    super.dispose();
  }

  // Mengambil data mobil dari Supabase (tabel 'cars')
  Future<void> _fetchCarsFromSupabase() async {
    try {
      final response = await Supabase.instance.client.from('cars').select();
      setState(() {
        _carList = List<Map<String, dynamic>>.from(response);
        _isLoadingCars = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCars = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Gagal memuat mobil: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final fieldBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    // Ambil daftar model mobil unik dari data Supabase
    final List<String> modelList = _carList.map((c) => c['model'].toString()).toSet().toList();
    
    // Ambil daftar plat berdasarkan model mobil yang dipilih
    final List<String> platList = _carList
        .where((c) => _selectedModel == null || c['model'] == _selectedModel)
        .map((c) => c['plat'].toString())
        .toList();

    return Scaffold(
      body: SafeArea(
        child: _isLoadingCars
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Catat Transaksi',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Custom Switcher Tab (Sewa vs Maintenance)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSewaMode = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isSewaMode ? const Color(0xFF10B981) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Sewa',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isSewaMode ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSewaMode = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isSewaMode ? const Color(0xFFEF4444) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Maintenance',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !_isSewaMode ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ================= FORM SEWA =================
                    if (_isSewaMode) ...[
                      _buildDarkTextField(
                        controller: _namaPelangganController,
                        hintText: 'Nama Pelanggan',
                        bgColor: cardBgColor,
                        borderColor: fieldBorderColor,
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Tanggal & Jam Mulai Perjalanan',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _tanggalMulai,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (pickedDate != null) {
                            if (!context.mounted) return;
                            TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(_tanggalMulai),
                            );
                            if (pickedTime != null) {
                              setState(() {
                                _tanggalMulai = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: fieldBorderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy, HH.mm').format(_tanggalMulai),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const Icon(Icons.access_time, size: 20, color: Color(0xFF10B981)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Pilih Model Mobil (dari Supabase)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedModel,
                            hint: const Text('-- Pilih Mobil --'),
                            isExpanded: true,
                            items: modelList.map((m) {
                              return DropdownMenuItem(value: m, child: Text(m));
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedModel = val;
                                _selectedPlat = null;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Pilih Plat Nomor (dari Supabase)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: fieldBorderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPlat,
                            hint: const Text('-- Pilih Plat Nomor --'),
                            isExpanded: true,
                            items: platList.map((p) {
                              return DropdownMenuItem(value: p, child: Text(p));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedPlat = val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Durasi Sewa (Contoh: 1.5 hari, 12 jam)',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      // Diubah menjadi input teks bebas agar bisa menulis '1.5 hari' / '12 jam'
                      _buildDarkTextField(
                        controller: _durasiController,
                        hintText: '1.5 hari / 12 jam',
                        keyboardType: TextInputType.text,
                        bgColor: cardBgColor,
                        borderColor: fieldBorderColor,
                      ),
                      const SizedBox(height: 16),

                      // Input Nominal Sewa
                      _buildCurrencyTextField(
                        controller: _nominalSewaController,
                        hintText: 'Nominal Sewa',
                        bgColor: cardBgColor,
                        borderColor: fieldBorderColor,
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _saveSewaTransactionToSupabase,
                          child: const Text(
                            'Konfirmasi Booking',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ]

                    // ================= FORM MAINTENANCE =================
                    else ...[
                      // Dropdown Plat Nomor & Model untuk Maintenance
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: fieldBorderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPlatMaintenance,
                            hint: const Text('-- Pilih Plat Nomor --'),
                            isExpanded: true,
                            items: _carList.map((c) {
                              return DropdownMenuItem(
                                value: c['plat'].toString(),
                                child: Text('${c['model']} - ${c['plat']}'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedPlatMaintenance = val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Jenis Maintenance
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: fieldBorderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedJenisMaintenance,
                            isExpanded: true,
                            items: _jenisMaintenanceList.map((j) {
                              return DropdownMenuItem(value: j, child: Text(j));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedJenisMaintenance = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input Tanggal & Jam Maintenance
                      const Text(
                        'Tanggal & Jam Maintenance',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _tanggalMaintenance,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (pickedDate != null) {
                            if (!context.mounted) return;
                            TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(_tanggalMaintenance),
                            );
                            if (pickedTime != null) {
                              setState(() {
                                _tanggalMaintenance = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: fieldBorderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy, HH.mm').format(_tanggalMaintenance),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const Icon(Icons.access_time, size: 20, color: Color(0xFFEF4444)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input Biaya Pengeluaran
                      _buildCurrencyTextField(
                        controller: _biayaPengeluaranController,
                        hintText: 'Biaya Pengeluaran',
                        bgColor: cardBgColor,
                        borderColor: fieldBorderColor,
                      ),
                      const SizedBox(height: 16),

                      // Input Catatan Tambahan Maintenance
                      _buildDarkTextField(
                        controller: _catatanMaintenanceController,
                        hintText: 'Catatan tambahan (opsional)',
                        bgColor: cardBgColor,
                        borderColor: fieldBorderColor,
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isSavingMaintenance ? null : _saveMaintenanceTransactionToSupabase,
                          child: _isSavingMaintenance
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Simpan Pengeluaran',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDarkTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCurrencyTextField({
    required TextEditingController controller,
    required String hintText,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _CurrencyTextInputFormatter(),
        ],
        decoration: InputDecoration(
          prefixText: 'Rp. ',
          prefixStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // Fungsi untuk menyimpan data transaksi sewa ke tabel 'transactions' di Supabase
  Future<void> _saveSewaTransactionToSupabase() async {
    if (_namaPelangganController.text.isEmpty ||
        _selectedModel == null ||
        _selectedPlat == null ||
        _nominalSewaController.text.isEmpty ||
        _durasiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('⚠️ Lengkapi seluruh data transaksi sewa termasuk durasi!'),
        ),
      );
      return;
    }

    // Mengambil string teks durasi secara langsung (misal: "1.5 hari" atau "12 jam")
    String durasiText = _durasiController.text.trim();
    int nominal = int.tryParse(
          _nominalSewaController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    try {
      await Supabase.instance.client.from('transactions').insert({
        'pelanggan': _namaPelangganController.text,
        'mobil': _selectedModel,
        'plat': _selectedPlat,
        'tgl_mulai': _tanggalMulai.toIso8601String(),
        'durasi': durasiText, // Disimpan sebagai String ke Supabase
        'nominal': nominal,
        'status': 'booking',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('✅ Transaksi berhasil disimpan ke Supabase!'),
        ),
      );

      _namaPelangganController.clear();
      _durasiController.text = '1 hari';
      _nominalSewaController.clear();
      setState(() {
        _selectedModel = null;
        _selectedPlat = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('❌ Gagal menyimpan ke Supabase: $e'),
        ),
      );
    }
  }

  // Fungsi untuk menyimpan data maintenance ke tabel 'maintenance' di Supabase
  Future<void> _saveMaintenanceTransactionToSupabase() async {
    if (_selectedPlatMaintenance == null || _biayaPengeluaranController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('⚠️ Pilih plat nomor dan isi biaya pengeluaran terlebih dahulu!'),
        ),
      );
      return;
    }

    setState(() {
      _isSavingMaintenance = true;
    });

    try {
      final selectedCar = _carList.firstWhere(
        (c) => c['plat'].toString() == _selectedPlatMaintenance,
        orElse: () => <String, dynamic>{},
      );

      final String modelMobil = selectedCar['model']?.toString() ?? 'Unknown';
      final String platNomor = _selectedPlatMaintenance!;
      final double biaya = double.tryParse(
            _biayaPengeluaranController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0.0;

      final String catatan = _catatanMaintenanceController.text.trim();
      final String finalDeskripsi = catatan.isNotEmpty
          ? '[$_selectedJenisMaintenance] $catatan'
          : '[$_selectedJenisMaintenance]';

      // Insert ke tabel 'maintenance' di Supabase termasuk kolom 'tanggal'
      await Supabase.instance.client.from('maintenance').insert({
        'model_mobil': modelMobil,
        'plat_nomor': platNomor,
        'deskripsi_servis': finalDeskripsi,
        'biaya': biaya,
        'tanggal': _tanggalMaintenance.toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('✅ Data maintenance berhasil disimpan ke Supabase!'),
        ),
      );

      _biayaPengeluaranController.clear();
      _catatanMaintenanceController.clear();
      setState(() {
        _selectedPlatMaintenance = null;
        _selectedJenisMaintenance = 'Ganti Oli';
        _tanggalMaintenance = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('❌ Gagal menyimpan maintenance: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingMaintenance = false;
        });
      }
    }
  }
}