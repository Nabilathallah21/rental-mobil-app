import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PickupConfirmScreen extends StatefulWidget {
  const PickupConfirmScreen({super.key});

  @override
  State<PickupConfirmScreen> createState() => _PickupConfirmScreenState();
}

class _PickupConfirmScreenState extends State<PickupConfirmScreen> {
  final supabase = Supabase.instance.client;

  // Fungsi untuk mengambil data transaksi dengan status 'booking' dari Supabase
  Future<List<Map<String, dynamic>>> _fetchBookingTransactions() async {
    try {
      final response = await supabase
          .from('transactions')
          .select()
          .eq('status', 'booking');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching booking transactions: $e');
      return [];
    }
  }

  // Fungsi untuk menyimpan konfirmasi pengambilan & update status mobil via Plat
  Future<void> _confirmPickup(
    BuildContext context,
    String transactionId,
    String carPlat,
  ) async {
    try {
      final waktuAktualDiambil = DateTime.now();

      // 1. Cek sekali lagi apakah plat ini sudah berstatus 'berjalan' (mencegah bentrok)
      final cekBerjalan = await supabase
          .from('transactions')
          .select()
          .eq('plat', carPlat)
          .eq('status', 'berjalan');

      if ((cekBerjalan as List).isNotEmpty) {
        if (!context.mounted) return;
        Navigator.pop(context); // Tutup dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Gagal: Mobil dengan plat ini sedang berjalan / disewa!'),
          ),
        );
        return;
      }

      // 2. Update status transaksi di database menjadi 'berjalan'
      await supabase.from('transactions').update({
        'status': 'berjalan',
        'tgl_diambil': waktuAktualDiambil.toIso8601String(),
      }).eq('id', transactionId);

      // 3. Update status mobil di tabel 'cars' berdasarkan PLAT agar tidak keliru unit
      if (carPlat.isNotEmpty && carPlat != '-') {
        await supabase.from('cars').update({
          'status': 'disewa', // Mengubah status mobil menjadi disewa / tidak tersedia
        }).eq('plat', carPlat); 
      }

      if (!context.mounted) return;

      Navigator.pop(context); // Tutup dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('✅ Pengambilan mobil berhasil dikonfirmasi & status berubah jadi Berjalan!'),
        ),
      );

      // Refresh tampilan
      setState(() {});
    } catch (e) {
      debugPrint('Error confirming pickup: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Gagal mengkonfirmasi pengambilan: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Konfirmasi Pengambilan Mobil',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Catat jam aktual mobil diambil atau diserahkan.',
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchBookingTransactions(),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.checklist_rtl, size: 48, color: subTextColor),
                            const SizedBox(height: 8),
                            Text(
                              'Tidak ada antrean mobil siap diambil.',
                              style: TextStyle(color: subTextColor),
                            ),
                          ],
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
                          final t = bookingList[index];
                          
                          final String id = t['id'].toString();
                          final String mobil = t['mobil'] ?? '-';
                          final String plat = t['plat'] ?? '-';
                          final String pelanggan = t['pelanggan'] ?? '-';
                          
                          final DateTime tglMulai = DateTime.parse(
                            t['tgl_mulai'] ?? DateTime.now().toIso8601String(),
                          );
                          
                          String strJadwal = DateFormat('dd MMM yyyy, HH.mm').format(tglMulai);

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
                                      Text(
                                        plat,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: subTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pelanggan: $pelanggan',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Jadwal Booking: $strJadwal',
                                    style: TextStyle(color: subTextColor, fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.access_time_filled,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Konfirmasi Mobil Diambil',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () => _showPickupDialog(context, id, mobil, plat, tglMulai),
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

  // Dialog konfirmasi pengambilan
  void _showPickupDialog(
    BuildContext context, 
    String transactionId, 
    String mobil, 
    String plat, 
    DateTime tglMulai,
  ) {
    DateTime waktuAktualDiambil = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Pengambilan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unit: $mobil ($plat)', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Jadwal Asli: ${DateFormat('dd/MM/yyyy HH:mm').format(tglMulai)}'),
              const SizedBox(height: 8),
              Text('Waktu Diserahkan Sekarang: ${DateFormat('dd/MM/yyyy HH:mm').format(waktuAktualDiambil)}'),
              const SizedBox(height: 12),
              const Text(
                'Status transaksi akan diubah jadi "berjalan" dan status mobil di database menjadi "disewa".',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () {
                _confirmPickup(context, transactionId, plat);
              },
              child: const Text('Ya, Konfirmasi', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}