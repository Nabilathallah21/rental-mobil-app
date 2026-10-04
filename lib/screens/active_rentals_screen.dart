import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveRentalScreen extends StatefulWidget {
  const ActiveRentalScreen({super.key});

  @override
  State<ActiveRentalScreen> createState() => _ActiveRentalScreenState();
}

class _ActiveRentalScreenState extends State<ActiveRentalScreen> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchActiveRentals() async {
    try {
      final response = await supabase
          .from('transactions')
          .select()
          .eq('status', 'berjalan');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching active rentals: $e');
      return [];
    }
  }

  // Fungsi untuk memformat tanggal mulai sewa agar mudah dibaca
  String _formatTanggalMulai(String? tglMulaiStr) {
    if (tglMulaiStr == null || tglMulaiStr.isEmpty) return 'Tanggal belum dicatat';
    
    try {
      DateTime parsedDate = DateTime.parse(tglMulaiStr);
      // Format tanggal: Hari, DD/MM/YYYY Jam:Menit (sesuaikan kebutuhan)
      return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return tglMulaiStr;
    }
  }

  // Fungsi untuk menampilkan Dialog Ubah Durasi
void _showEditDurasiDialog(Map<String, dynamic> transaction) {
    final TextEditingController durasiController = TextEditingController(
      text: transaction['durasi']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) { // <-- Beri nama dialogCtx di sini
        return AlertDialog(
          title: const Text('Perbarui Durasi Sewa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mobil: ${transaction['mobil']} (${transaction['plat']})', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Pelanggan: ${transaction['pelanggan']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: durasiController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Durasi Baru (Contoh: 1.5 atau 3)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixText: 'Hari',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () async {
                final String durasiBaru = durasiController.text.trim();
                if (durasiBaru.isEmpty) return;

                try {
                  await supabase
                      .from('transactions')
                      .update({'durasi': durasiBaru})
                      .eq('id', transaction['id']);

                  // Cek apakah dialog masih aktif menggunakan dialogCtx.mounted
                  if (!dialogCtx.mounted) return;

                  Navigator.pop(dialogCtx);
                  
                  // Gunakan context utama dari State untuk SnackBar
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.green,
                      content: Text('✅ Durasi sewa berhasil diperbarui!'),
                    ),
                  );
                  setState(() {});
                } catch (e) {
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: Colors.red, content: Text('Gagal memperbarui durasi: $e')),
                  );
                }
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobil Sedang Berjalan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchActiveRentals(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
            }

            final activeList = snapshot.data ?? [];

            if (activeList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_filled, size: 48, color: subTextColor),
                    const SizedBox(height: 8),
                    Text('Tidak ada mobil yang sedang disewa.', style: TextStyle(color: subTextColor)),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView.builder(
                itemCount: activeList.length,
                itemBuilder: (context, index) {
                  final t = activeList[index];
                  final String mobil = t['mobil'] ?? '-';
                  final String plat = t['plat'] ?? '-';
                  final String pelanggan = t['pelanggan'] ?? '-';
                  
                  // Mengambil data tgl_mulai dari database
                  final String? tglMulai = t['tgl_mulai'] ?? t['tgl_diambil'];
                  final String durasiSewa = t['durasi']?.toString() ?? '-';

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
                              Text(mobil, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'SEDANG BERJALAN',
                                  style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Plat Nomor: $plat', style: TextStyle(color: subTextColor)),
                          const SizedBox(height: 2),
                          Text('Pelanggan: $pelanggan', style: const TextStyle(fontWeight: FontWeight.w500)),
                          const Divider(height: 16),
                          
                          // Baris Informasi Durasi & Tombol Ubah Durasi
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.timer, size: 16, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Durasi Sewa: $durasiSewa Hari',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showEditDurasiDialog(t),
                                icon: const Icon(Icons.edit, size: 14, color: Color(0xFF10B981)),
                                label: const Text('Ubah Durasi', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: const Size(0, 30),
                                  side: const BorderSide(color: Color(0xFF10B981), width: 0.8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          // Menampilkan Tanggal Mulai Sewa
                          Row(
                            children: [
                              const Icon(Icons.date_range, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                'Mulai Sewa: ${_formatTanggalMulai(tglMulai)}',
                                style: TextStyle(fontSize: 12, color: subTextColor),
                              ),
                            ],
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
    );
  }
}