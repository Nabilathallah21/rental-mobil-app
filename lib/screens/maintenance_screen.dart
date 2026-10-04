import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final supabase = Supabase.instance.client;

  // Fungsi untuk mengambil data maintenance dari Supabase
  Future<List<Map<String, dynamic>>> _fetchMaintenance() async {
    try {
      final response = await supabase.from('maintenance').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching maintenance data: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Perawatan Armada',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchMaintenance(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Terjadi kesalahan: ${snapshot.error}'),
                      );
                    }

                    final maintenanceList = snapshot.data ?? [];

                    if (maintenanceList.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada catatan perawatan.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: maintenanceList.length,
                        itemBuilder: (context, index) {
                          final item = maintenanceList[index];
                          final String mobil = item['mobil'] ?? '-';
                          final String jenis = item['jenis_perawatan'] ?? item['jenisPerawatan'] ?? '-';
                          final int biaya = (item['biaya'] ?? 0) as int;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                mobil,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(jenis),
                              trailing: Text(
                                'Rp ${NumberFormat('#,###').format(biaya)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
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