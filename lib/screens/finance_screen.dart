import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Tambahan untuk simpan status reset terakhir

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final supabase = Supabase.instance.client;

  // Status keamanan PIN
  bool _isUnlocked = false;
  final TextEditingController _pinController = TextEditingController();
  final String _correctPin = "3939"; 

  // Filter default rentang tanggal (Bulan berjalan)
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _setDefaultCurrentMonth();
    // Jalankan pengecekan reset tahunan otomatis saat halaman dibuka
    _checkAndPerformYearlyReset();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _setDefaultCurrentMonth() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  // Fungsi Cek dan Reset Otomatis Tahun Lalu
  Future<void> _checkAndPerformYearlyReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final currentYear = now.year;
      
      // Ambil tahun terakhir kali reset dilakukan dari penyimpanan lokal HP
      final lastResetYear = prefs.getInt('last_reset_year') ?? currentYear;

      // Jika tahun sekarang lebih besar dari tahun terakhir reset, artinya sudah berganti tahun!
      if (currentYear > lastResetYear) {
        final targetYear = lastResetYear; // Tahun yang akan direkap & dibersihkan
        
        debugPrint('Mendeteksi pergantian tahun. Memproses rekap & reset otomatis untuk tahun $targetYear...');

        final startIso = DateTime(targetYear, 1, 1).toIso8601String();
        final endIso = DateTime(targetYear, 12, 31, 23, 59, 59).toIso8601String();

        // 1. Ambil data tahun lalu dari Supabase
        final rentRes = await supabase.from('transactions').select().gte('tgl_mulai', startIso).lte('tgl_mulai', endIso);
        final maintRes = await supabase.from('maintenance').select().gte('tanggal', startIso).lte('tanggal', endIso);

        List<Map<String, dynamic>> yearlyData = [];
        for (var item in rentRes) {
          final durasiVal = item['durasi'];
          final durasiStr = (durasiVal != null && durasiVal.toString().isNotEmpty) ? ' (Durasi: $durasiVal)' : '';

          yearlyData.add({
            'date': item['tgl_mulai'] != null ? DateTime.parse(item['tgl_mulai'].toString()) : DateTime.now(),
            'desc': 'Sewa: ${item['mobil'] ?? '-'} (${item['pelanggan'] ?? '-'})$durasiStr',
            'type': (item['status'] ?? '').toString().toUpperCase(),
            'amount': (item['nominal'] ?? 0).toDouble(),
          });
        }
        for (var item in maintRes) {
          yearlyData.add({
            'date': item['tanggal'] != null ? DateTime.parse(item['tanggal'].toString()) : DateTime.now(),
            'desc': 'Maint: ${item['deskripsi_servis'] ?? '-'} (${item['model_mobil'] ?? '-'})',
            'type': 'PENGELUARAN',
            'amount': (item['biaya'] ?? item['nominal'] ?? 0).toDouble(),
          });
        }

        // Jika ada data di tahun lalu, buat PDF rekapnya otomatis
        if (yearlyData.isNotEmpty) {
          yearlyData.sort((a, b) => b['date'].compareTo(a['date']));
          await _generateYearlyBackupPdf(targetYear, yearlyData);
        }

        // 2. Hapus data tahun lalu dari database Supabase
        await supabase.from('transactions').delete().gte('tgl_mulai', startIso).lte('tgl_mulai', endIso);
        await supabase.from('maintenance').delete().gte('tanggal', startIso).lte('tanggal', endIso);

        // 3. Simpan status bahwa tahun ini sudah di-reset
        await prefs.setInt('last_reset_year', currentYear);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text('✅ Data tahun $targetYear telah di-reset & PDF rekap otomatis dibuat!'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error pada proses yearly reset: $e');
    }
  }

  // Generator PDF khusus backup otomatis tahunan
  Future<void> _generateYearlyBackupPdf(int year, List<Map<String, dynamic>> data) async {
    try {
      final pdf = pw.Document();
      final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('REKAPAN OTOMATIS TAHUN $year', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Backup Otomatis Sistem', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Laporan Arsip Keuangan Tahun Berjalan Sebelumnya', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Tanggal', 'Keterangan', 'Status/Jenis', 'Nominal'],
                data: data.map((item) {
                  return [
                    DateFormat('dd/MM/yyyy').format(item['date']),
                    item['desc'],
                    item['type'],
                    currencyFormat.format(item['amount']),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF10B981)),
                cellStyle: const pw.TextStyle(fontSize: 10),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(2),
                },
              ),
            ];
          },
        ),
      );

      // Otomatis memicu dialog print/simpan PDF ke perangkat
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Rekapan_Otomatis_Tahun_$year.pdf',
      );
    } catch (e) {
      debugPrint('Gagal generate PDF backup tahunan: $e');
    }
  }

  // Fungsi untuk memverifikasi PIN
  void _verifyPin() {
    if (_pinController.text.trim() == _correctPin) {
      setState(() {
        _isUnlocked = true;
      });
      _pinController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('❌ PIN salah! Silakan coba lagi.'),
        ),
      );
      _pinController.clear();
    }
  }

  // Fungsi untuk mengunci kembali halaman finance
  void _lockScreen() {
    setState(() {
      _isUnlocked = false;
    });
  }

  // Fungsi untuk memilih rentang tanggal filter laporan
  Future<void> _selectDateRange(BuildContext context) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  // Fungsi pengambilan data keuangan dengan filter rentang tanggal
  Future<Map<String, double>> _fetchFinanceData() async {
    try {
      final startIso = _startDate.toIso8601String();
      final endIso = _endDate.toIso8601String();

      final response = await supabase
          .from('transactions')
          .select()
          .gte('tgl_mulai', startIso)
          .lte('tgl_mulai', endIso);

      final list = List<Map<String, dynamic>>.from(response);

      double totalPemasukan = 0;
      double totalPiutang = 0;

      for (var t in list) {
        final status = (t['status'] ?? '').toString().toLowerCase().trim();
        
        double nominal = 0;
        final nominalRaw = t['nominal'];
        if (nominalRaw != null) {
          if (nominalRaw is num) {
            nominal = nominalRaw.toDouble();
          } else {
            nominal = double.tryParse(nominalRaw.toString()) ?? 0;
          }
        }

        if (status == 'selesai') {
          totalPemasukan += nominal;
        } else if (status == 'belum_lunas') {
          totalPiutang += nominal;
        }
      }

      double totalPengeluaran = 0;
      try {
        final maintenanceRes = await supabase
            .from('maintenance')
            .select()
            .gte('tanggal', startIso)
            .lte('tanggal', endIso);

        final maintenanceList = List<Map<String, dynamic>>.from(maintenanceRes);

        for (var m in maintenanceList) {
          final biayaRaw = m['biaya'] ?? m['nominal'] ?? m['harga'];
          if (biayaRaw != null) {
            if (biayaRaw is num) {
              totalPengeluaran += biayaRaw.toDouble();
            } else {
              totalPengeluaran += double.tryParse(biayaRaw.toString()) ?? 0;
            }
          }
        }
      } catch (_) {}

      double labaBersih = totalPemasukan - totalPengeluaran;

      return {
        'totalPemasukan': totalPemasukan,
        'totalPengeluaran': totalPengeluaran,
        'labaBersih': labaBersih,
        'totalPiutang': totalPiutang,
      };
    } catch (e) {
      debugPrint('Error fetching finance data: $e');
      return {
        'totalPemasukan': 0,
        'totalPengeluaran': 0,
        'labaBersih': 0,
        'totalPiutang': 0,
      };
    }
  }

  // Dialog untuk memilih kategori & rentang tanggal sebelum export PDF
  void _showExportDialog(BuildContext context) {
    String selectedCategory = 'Semua';
    DateTime tempStart = _startDate;
    DateTime tempEnd = _endDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Export Laporan PDF'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pilih Kategori Transaksi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: ['Semua', 'Pemasukan (Selesai)', 'Piutang (Belum Lunas)', 'Pengeluaran (Maintenance)']
                          .map((cat) => DropdownMenuItem(
                                value: cat, 
                                child: Text(cat, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Rentang Tanggal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          DateTimeRange? picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                            initialDateRange: DateTimeRange(start: tempStart, end: tempEnd),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tempStart = picked.start;
                              tempEnd = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                            });
                          }
                        },
                        icon: const Icon(Icons.date_range, color: Color(0xFF10B981), size: 18),
                        label: Text(
                          '${DateFormat('dd/MM/yyyy').format(tempStart)} - ${DateFormat('dd/MM/yyyy').format(tempEnd)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () {
                    Navigator.pop(context);
                    _generateAndPrintPdf(selectedCategory, tempStart, tempEnd);
                  },
                  child: const Text('Download / Print PDF', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fungsi generator PDF manual
  Future<void> _generateAndPrintPdf(String category, DateTime start, DateTime end) async {
    try {
      final startIso = start.toIso8601String();
      final endIso = end.toIso8601String();

      List<Map<String, dynamic>> pdfData = [];

      if (category == 'Semua' || category == 'Pemasukan (Selesai)' || category == 'Piutang (Belum Lunas)') {
        final rentRes = await supabase.from('transactions').select().gte('tgl_mulai', startIso).lte('tgl_mulai', endIso);
        for (var item in rentRes) {
          final status = (item['status'] ?? '').toString().toLowerCase().trim();
          if (category == 'Pemasukan (Selesai)' && status != 'selesai') continue;
          if (category == 'Piutang (Belum Lunas)' && status != 'belum_lunas') continue;

          final durasiVal = item['durasi'];
          final durasiStr = (durasiVal != null && durasiVal.toString().isNotEmpty) ? ' (Durasi: $durasiVal)' : '';

          pdfData.add({
            'date': item['tgl_mulai'] != null ? DateTime.parse(item['tgl_mulai'].toString()) : DateTime.now(),
            'desc': 'Sewa: ${item['mobil'] ?? '-'} (${item['pelanggan'] ?? '-'})$durasiStr',
            'type': status.toUpperCase(),
            'amount': (item['nominal'] ?? 0).toDouble(),
          });
        }
      }

      if (category == 'Semua' || category == 'Pengeluaran (Maintenance)') {
        final maintRes = await supabase.from('maintenance').select().gte('tanggal', startIso).lte('tanggal', endIso);
        for (var item in maintRes) {
          pdfData.add({
            'date': item['tanggal'] != null ? DateTime.parse(item['tanggal'].toString()) : DateTime.now(),
            'desc': 'Maint: ${item['deskripsi_servis'] ?? '-'} (${item['model_mobil'] ?? '-'})',
            'type': 'PENGELUARAN',
            'amount': (item['biaya'] ?? item['nominal'] ?? 0).toDouble(),
          });
        }
      }

      pdfData.sort((a, b) => b['date'].compareTo(a['date']));

      final pdf = pw.Document();
      final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Laporan Keuangan Rental', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Periode: ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Filter Kategori: $category', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Tanggal', 'Keterangan', 'Status/Jenis', 'Nominal'],
                data: pdfData.map((item) {
                  return [
                    DateFormat('dd/MM/yyyy').format(item['date']),
                    item['desc'],
                    item['type'],
                    currencyFormat.format(item['amount']),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF10B981)),
                cellStyle: const pw.TextStyle(fontSize: 10),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(2),
                },
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Laporan_Keuangan_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Gagal export PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Keamanan Keuangan',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Masukkan PIN rahasia untuk melihat\nlaporan pendapatan dan laba.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 2,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _verifyPin(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 280,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _verifyPin,
                      child: const Text(
                        'Buka Laporan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, double>>(
          future: _fetchFinanceData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
            }

            if (snapshot.hasError) {
              return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
            }

            final data = snapshot.data ?? {};
            final double totalPemasukan = data['totalPemasukan'] ?? 0;
            final double totalPengeluaran = data['totalPengeluaran'] ?? 0;
            final double labaBersih = data['labaBersih'] ?? 0;
            final double totalPiutang = data['totalPiutang'] ?? 0;

            return RefreshIndicator(
              color: const Color(0xFF10B981),
              onRefresh: () async {
                setState(() {});
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Laporan Keuangan',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _showExportDialog(context),
                              icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF10B981)),
                              tooltip: 'Export PDF',
                            ),
                            IconButton(
                              onPressed: _lockScreen,
                              icon: const Icon(Icons.lock, color: Colors.grey),
                              tooltip: 'Kunci Halaman',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDateRange(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade700, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.date_range, size: 18, color: Color(0xFF10B981)),
                                const SizedBox(width: 8),
                                Text(
                                  'Periode: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Ubah Filter',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Laba Bersih Saat Ini',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rp ${_formatRupiah(labaBersih)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Rincian Arus Kas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFinanceRow(
                      'Total Pemasukan (Lunas)',
                      totalPemasukan,
                      Colors.green,
                    ),
                    _buildFinanceRow(
                      'Total Pengeluaran (Service)',
                      totalPengeluaran,
                      Colors.red,
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Dana Tertahan (Piutang)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.pending_actions, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Belum Dilunasi',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            'Rp ${_formatRupiah(totalPiutang)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatRupiah(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  Widget _buildFinanceRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            'Rp ${_formatRupiah(amount)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}