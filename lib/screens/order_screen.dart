import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;

  const OrderScreen({super.key, this.onToggleTheme});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final supabase = Supabase.instance.client;

  // Fungsi untuk mengambil data order booking dari Supabase
  Future<List<Map<String, dynamic>>> _fetchBookingOrders() async {
    try {
      final response = await supabase
          .from('transactions')
          .select()
          .eq('status', 'booking');

      final List<Map<String, dynamic>> bookingList =
          List<Map<String, dynamic>>.from(response);

      // Urutkan berdasarkan tgl_mulai dari terdekat
      bookingList.sort((a, b) {
        final dateA = DateTime.parse(a['tgl_mulai'] ?? a['tglMulai'] ?? DateTime.now().toIso8601String());
        final dateB = DateTime.parse(b['tgl_mulai'] ?? b['tglMulai'] ?? DateTime.now().toIso8601String());
        return dateA.compareTo(dateB);
      });

      return bookingList;
    } catch (e) {
      debugPrint('Error fetching booking orders: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = isDark
        ? Colors.white70
        : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER: JUDUL + TOGGLE THEME
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daftar Order Booking',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onToggleTheme,
                    icon: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: isDark ? Colors.amber : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              Text(
                'Urutan jadwal persewaan terdekat:',
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchBookingOrders(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Terjadi kesalahan: ${snapshot.error}',
                          style: TextStyle(color: subTextColor),
                        ),
                      );
                    }

                    final bookingList = snapshot.data ?? [];

                    if (bookingList.isEmpty) {
                      return Center(
                        child: Text(
                          'Belum ada order booking.',
                          style: TextStyle(color: subTextColor),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: bookingList.length,
                        itemBuilder: (context, index) {
                          final item = bookingList[index];
                          
                          final String mobil = item['mobil'] ?? '-';
                          final String pelanggan = item['pelanggan'] ?? '-';
                          final int durasi = (item['durasi'] ?? 0) as int;
                          
                          final DateTime tglMulai = DateTime.parse(
                            item['tgl_mulai'] ?? item['tglMulai'] ?? DateTime.now().toIso8601String(),
                          );
                          
                          DateTime tglSelesaiVal = item['tgl_selesai'] != null || item['tglSelesai'] != null
                              ? DateTime.parse(item['tgl_selesai'] ?? item['tglSelesai'])
                              : tglMulai.add(Duration(days: durasi));

                          String strMulai = DateFormat('dd MMM yyyy').format(tglMulai);
                          String strSelesai = DateFormat('dd MMM yyyy').format(tglSelesaiVal);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: const CircleAvatar(
                                backgroundColor: Colors.amber,
                                child: Icon(Icons.bookmark, color: Colors.white),
                              ),
                              title: Text(
                                '$mobil - $pelanggan',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Jadwal: $strMulai - $strSelesai',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Durasi: $durasi Hari',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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