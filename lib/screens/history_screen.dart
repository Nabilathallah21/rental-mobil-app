import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Rentang tanggal filter (Default: Tanggal 1 sampai akhir bulan berjalan)
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _setDefaultCurrentMonth();
  }

  // Mengatur default tanggal ke bulan berjalan (Tanggal 1 sampai akhir bulan)
  void _setDefaultCurrentMonth() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    // Mengambil hari terakhir di bulan berjalan
    _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  // Fungsi untuk mengambil data transaksi berdasarkan filter rentang tanggal & status 'selesai'
  Future<List<Map<String, dynamic>>> _fetchHistoryTransactions() async {
    final startIso = _startDate.toIso8601String();
    final endIso = _endDate.toIso8601String();

    final response = await Supabase.instance.client
        .from('transactions')
        .select()
        .eq('status', 'selesai') // Menyaring hanya transaksi yang lunas/selesai
        .gte('tgl_mulai', startIso) // Filter tanggal mulai dari
        .lte('tgl_mulai', endIso) // Filter tanggal mulai sampai
        .order('tgl_mulai', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Fungsi untuk membuka Date Range Picker guna menyortir bulan/tanggal lain
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
        // Pastikan jam akhir mencakup pukul 23:59:59 pada hari tersebut
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = isDark
        ? Colors.white70
        : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
    final cardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Tombol Filter Sortir
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Riwayat Transaksi Lunas',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _selectDateRange(context),
                    icon: const Icon(Icons.filter_list, color: Color(0xFF10B981)),
                    tooltip: 'Sortir Tanggal',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Daftar penyewaan yang telah selesai & lunas dari database.',
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
              const SizedBox(height: 12),

              // Kotak Informasi Periode & Tombol Ubah Sortir
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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Ubah Sortir',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Daftar Riwayat dengan FutureBuilder
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchHistoryTransactions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF10B981)),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Gagal memuat riwayat: ${snapshot.error}',
                          style: TextStyle(color: subTextColor),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final historyList = snapshot.data ?? [];

                    if (historyList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 48,
                              color: subTextColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Belum ada riwayat selesai pada periode ini.',
                              style: TextStyle(color: subTextColor),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: historyList.length,
                      itemBuilder: (context, index) {
                        final t = historyList[index];

                        final String mobil = t['mobil'] ?? '-';
                        final String plat = t['plat'] ?? '-';
                        final String pelanggan = t['pelanggan'] ?? '-';
                        final String durasiSewa = t['durasi']?.toString() ?? '-';

                        // Format tanggal mulai sewa
                        String strMulai = '-';
                        if (t['tgl_mulai'] != null) {
                          try {
                            DateTime parsedDate = DateTime.parse(t['tgl_mulai']);
                            strMulai = DateFormat('dd MMM yyyy').format(parsedDate);
                          } catch (_) {}
                        }

                        // Format nominal Rupiah
                        int nominal = t['nominal'] ?? 0;
                        String formattedNominal = NumberFormat('#,###', 'id_ID').format(nominal);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      mobil,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'LUNAS',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Plat Nomor: $plat', style: TextStyle(color: subTextColor)),
                                const SizedBox(height: 2),
                                Text('Pelanggan: $pelanggan', style: const TextStyle(fontWeight: FontWeight.w500)),
                                const Divider(height: 16),
                                
                                // Informasi Durasi & Tanggal Mulai Sewa Mobil
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.timer, size: 16, color: Colors.orange),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Durasi: $durasiSewa Hari',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Rp $formattedNominal',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.date_range, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Mulai Sewa: $strMulai',
                                      style: TextStyle(fontSize: 12, color: subTextColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}