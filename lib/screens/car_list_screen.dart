import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CarListScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;

  const CarListScreen({super.key, this.onToggleTheme});

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
  // Fungsi untuk mengambil data mobil langsung dari kolom 'status' di tabel Supabase
  Future<List<Map<String, dynamic>>> _fetchCarsWithStatus() async {
    final supabase = Supabase.instance.client;

    try {
      // Ambil semua data mobil dari tabel 'cars'
      final carsRes = await supabase.from('cars').select();
      final cars = List<Map<String, dynamic>>.from(carsRes);

      // Evaluasi status langsung dari kolom 'status' di database
      for (var car in cars) {
        String dbStatus = (car['status'] ?? 'tersedia').toString().toLowerCase();
        
        // Jika status di database adalah 'disewa' atau 'berjalan', maka mobil tidak tersedia
        car['is_tersedia'] = (dbStatus != 'disewa' && dbStatus != 'berjalan');
      }

      return cars;
    } catch (e) {
      debugPrint('Error fetching cars list: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Armada Mobil'),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.amber : Colors.grey[800],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchCarsWithStatus(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Terjadi kesalahan: ${snapshot.error}'),
              );
            }

            final cars = snapshot.data ?? [];

            if (cars.isEmpty) {
              return const Center(
                child: Text('Belum ada armada mobil terdaftar.'),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: cars.length,
                  itemBuilder: (context, index) {
                    final car = cars[index];
                    final String nama = car['model'] ?? car['nama'] ?? car['name'] ?? 'Tanpa Nama';
                    final String plat = car['plat'] ?? car['plate_number'] ?? '-';
                    final bool isTersedia = car['is_tersedia'] ?? true;
                    final String statusText = isTersedia ? 'TERSEDIA' : 'TERSEWA';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTersedia
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.directions_car,
                            color: isTersedia ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          nama,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(plat),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isTersedia
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: isTersedia ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}