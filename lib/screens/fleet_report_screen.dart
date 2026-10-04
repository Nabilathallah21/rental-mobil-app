import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FleetReportScreen extends StatefulWidget {
  const FleetReportScreen({super.key});

  @override
  State<FleetReportScreen> createState() => _FleetReportScreenState();
}

class _FleetReportScreenState extends State<FleetReportScreen> {
  final supabase = Supabase.instance.client;

  // Filter rentang tanggal default (Bulan berjalan)
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = true;
  List<Map<String, dynamic>> _fleetReportData = [];

  @override
  void initState() {
    super.initState();
    _setDefaultCurrentMonth();
    _fetchFleetProductivity();
  }

  void _setDefaultCurrentMonth() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  // Fungsi untuk mengambil dan menghitung produktivitas per plat nomor kendaraan
  Future<void> _fetchFleetProductivity() async {
    setState(() => _isLoading = true);
    try {
      final startIso = _startDate.toIso8601String();
      final endIso = _endDate.toIso8601String();

      // Ambil data transaksi dalam rentang tanggal
      final response = await supabase
          .from('transactions')
          .select()
          .gte('tgl_mulai', startIso)
          .lte('tgl_mulai', endIso);

      final List<Map<String, dynamic>> transactions = List<Map<String, dynamic>>.from(response);

      // Mapping untuk merangkum data per Plat Nomor (unik)
      // Key: Plat Nomor, Value: { 'mobil': ..., 'plat': ..., 'totalSewa': ..., 'totalHari': ..., 'totalPendapatan': ... }
      Map<String, Map<String, dynamic>> aggregatedMap = {};

      for (var t in transactions) {
        final String mobil = t['mobil'] ?? 'Mobil Lain';
        final String plat = (t['plat'] != null && t['plat'].toString().trim().isNotEmpty) 
            ? t['plat'].toString().trim() 
            : 'Tanpa Plat';
        
        // Ambil nominal
        double nominal = 0;
        final nominalRaw = t['nominal'];
        if (nominalRaw != null) {
          nominal = nominalRaw is num ? nominalRaw.toDouble() : double.tryParse(nominalRaw.toString()) ?? 0;
        }

        // Ambil durasi (mendukung angka desimal seperti 1.5 atau 3)
        double durasi = 0;
        final durasiRaw = t['durasi'];
        if (durasiRaw != null) {
          durasi = durasiRaw is num ? durasiRaw.toDouble() : double.tryParse(durasiRaw.toString()) ?? 0;
        }

        // Menggunakan plat sebagai key utama pengelompokan
        if (!aggregatedMap.containsKey(plat)) {
          aggregatedMap[plat] = {
            'mobil': mobil, // Menyimpan nama jenis mobil sebagai referensi
            'plat': plat,
            'totalSewa': 0,
            'totalHari': 0.0,
            'totalPendapatan': 0.0,
          };
        } else {
          // Update nama mobil jika sebelumnya tercatat 'Mobil Lain' atau berbeda
          if (aggregatedMap[plat]!['mobil'] == 'Mobil Lain' && mobil != 'Mobil Lain') {
            aggregatedMap[plat]!['mobil'] = mobil;
          }
        }

        aggregatedMap[plat]!['totalSewa'] += 1;
        aggregatedMap[plat]!['totalHari'] += durasi;
        aggregatedMap[plat]!['totalPendapatan'] += nominal;
      }

      // Ubah map menjadi list dan urutkan berdasarkan total pendapatan / sewa terbanyak
      List<Map<String, dynamic>> resultList = aggregatedMap.values.toList();
      resultList.sort((a, b) => b['totalPendapatan'].compareTo(a['totalPendapatan']));

      setState(() {
        _fleetReportData = resultList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching fleet productivity: $e');
      setState(() => _isLoading = false);
    }
  }

  // Fungsi Pilih Rentang Tanggal
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
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _fetchFleetProductivity();
    }
  }

  // Fungsi Export Laporan Produktivitas ke PDF (Berdasarkan Plat Nomor)
  Future<void> _generateFleetPdf() async {
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
                    pw.Text('Laporan Produktivitas Per Plat Kendaraan', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Periode: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['No', 'Plat Nomor & Jenis', 'Total Disewa', 'Akumulasi Durasi', 'Total Pendapatan'],
                data: _fleetReportData.asMap().entries.map((entry) {
                  int index = entry.key;
                  var item = entry.value;
                  return [
                    (index + 1).toString(),
                    '${item['plat']}\n(${item['mobil']})',
                    '${item['totalSewa']}x',
                    '${item['totalHari']} Hari',
                    currencyFormat.format(item['totalPendapatan']),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF10B981)),
                cellStyle: const pw.TextStyle(fontSize: 10),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2.5),
                },
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Laporan_Produktivitas_Plat_${DateFormat('yyyyMMdd').format(_startDate)}.pdf',
      );
    } catch (e) {
      debugPrint('Gagal cetak PDF armada: $e');
    }
  }

  String _formatRupiah(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produktivitas Per Plat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF10B981)),
            tooltip: 'Export PDF Armada',
            onPressed: _fleetReportData.isEmpty ? null : _generateFleetPdf,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Tanggal Bar
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
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Text(
                      'Ubah Filter',
                      style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Performa Unit Berdasarkan Plat Nomor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // List / Daftar Produktivitas Per Plat
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                  : _fleetReportData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('Tidak ada data penyewaan pada periode ini.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF10B981),
                          onRefresh: _fetchFleetProductivity,
                          child: ListView.builder(
                            itemCount: _fleetReportData.length,
                            itemBuilder: (context, index) {
                              final item = _fleetReportData[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item['plat'], // Judul Utama: Plat Nomor
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Peringkat #${index + 1}',
                                              style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Jenis Mobil: ${item['mobil']}', style: const TextStyle(color: Colors.grey, fontSize: 13)), // Subteks: Jenis Mobil
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Frekuensi Disewa', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              const SizedBox(height: 2),
                                              Text('${item['totalSewa']} Kali', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Akumulasi Durasi', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              const SizedBox(height: 2),
                                              Text('${item['totalHari']} Hari', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Total Pendapatan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              const SizedBox(height: 2),
                                              Text('Rp ${_formatRupiah(item['totalPendapatan'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}