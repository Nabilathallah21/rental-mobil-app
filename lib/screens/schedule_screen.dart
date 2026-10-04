import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final supabase = Supabase.instance.client;

  String? selectedCarModel;
  DateTime? selectedDate;

  Future<List<String>> _fetchCarModels() async {
    try {
      final response = await supabase.from('cars').select('nama');
      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(response);
      return data.map((c) => c['nama'].toString()).toSet().toList();
    } catch (e) {
      debugPrint('Error fetching car models: $e');
      return [];
    }
  }

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
              Text(
                'Jadwal Booking Armada',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Daftar mobil yang akan disewa mendatang.',
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<String>>(
                future: _fetchCarModels(),
                builder: (context, carSnapshot) {
                  final carModels = carSnapshot.data ?? [];

                  return Card(
                    elevation: 0,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedCarModel,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Filter Mobil',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(),
                              ),
                              hint: const Text('Semua Mobil'),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Semua Mobil'),
                                ),
                                ...carModels.map(
                                  (model) => DropdownMenuItem(
                                    value: model,
                                    child: Text(
                                      model,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => selectedCarModel = val),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() => selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Filter Tanggal',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      selectedDate == null
                                          ? 'Semua'
                                          : DateFormat('dd/MM/yy')
                                              .format(selectedDate!),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const Icon(Icons.calendar_today, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                        child: Text('Terjadi kesalahan: ${snapshot.error}'),
                      );
                    }

                    final rawTransactions = snapshot.data ?? [];

                    final bookingList = rawTransactions.where((t) {
                      bool matchCar = selectedCarModel == null ||
                          t['mobil'] == selectedCarModel;
                      bool matchDate = true;

                      if (selectedDate != null) {
                        DateTime filterDay = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                        );

                        DateTime tglMulai = DateTime.parse(t['tgl_mulai']);
                        DateTime start = DateTime(
                          tglMulai.year,
                          tglMulai.month,
                          tglMulai.day,
                        );

                        DateTime? tglSelesaiParsed = t['tgl_selesai'] != null
                            ? DateTime.parse(t['tgl_selesai'])
                            : null;
                        DateTime endDateVal = tglSelesaiParsed ?? tglMulai;
                        DateTime end = DateTime(
                          endDateVal.year,
                          endDateVal.month,
                          endDateVal.day,
                        );

                        matchDate = (filterDay.isAfter(
                              start.subtract(const Duration(days: 1)),
                            ) &&
                            filterDay.isBefore(
                              end.add(const Duration(days: 1)),
                            ));
                      }

                      return matchCar && matchDate;
                    }).toList();

                    if (bookingList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy,
                                size: 48, color: subTextColor),
                            const SizedBox(height: 8),
                            Text(
                              'Tidak ada jadwal booking ditemukan.',
                              style: TextStyle(color: subTextColor),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => setState(() {}),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: bookingList.length,
                        itemBuilder: (context, index) {
                          final item = bookingList[index];
                          final DateTime tglMulai =
                              DateTime.parse(item['tgl_mulai']);
                          
                          // Variabel strSelesai sekarang digunakan untuk menampilkan tanggal selesai
                          final DateTime? tglSelesai = item['tgl_selesai'] != null
                              ? DateTime.parse(item['tgl_selesai'])
                              : null;
                          String strSelesai = tglSelesai != null
                              ? DateFormat('dd MMM yyyy, HH:mm').format(tglSelesai)
                              : 'Selesai otomatis';

                          String strMulai = DateFormat('dd MMM yyyy, HH:mm').format(tglMulai);
                          final String mobil = item['mobil'] ?? '-';
                          final String plat = item['plat'] ?? '-';
                          final String pelanggan = item['pelanggan'] ?? '-';
                          final String durasiSewa = item['durasi']?.toString() ?? '-';

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
                                          color: Colors.amber,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'BOOKING',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
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
                                  Row(
                                    children: [
                                      const Icon(Icons.timer, size: 16, color: Colors.orange),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Durasi Peminjaman: $durasiSewa Hari',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.date_range, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Mulai: $strMulai\nSelesai: $strSelesai',
                                          style: TextStyle(fontSize: 12, color: subTextColor),
                                        ),
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
            ],
          ),
        ),
      ),
    );
  }
}