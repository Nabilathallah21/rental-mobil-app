import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'active_rentals_screen.dart';
import 'car_list_screen.dart';
import 'pickup_confirm_screen.dart';
import 'return_confirm_screen.dart';
import 'fleet_report_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  final VoidCallback? onToggleTheme;

  const HomeScreen({
    super.key, 
    this.onNavigate,
    this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<Map<String, int>> _fetchCounts() async {
    final supabase = Supabase.instance.client;

    try {
      final carsRes = await supabase.from('cars').select('id');
      final totalArmadaCount = (carsRes as List).length;

      final txRes = await supabase.from('transactions').select('status');
      final transactions = List<Map<String, dynamic>>.from(txRes);

      final mobilJalanCount = transactions.where((t) => t['status'] == 'berjalan').length;
      final bookingCount = transactions.where((t) => t['status'] == 'booking').length;

      return {
        'totalArmadaCount': totalArmadaCount,
        'mobilJalanCount': mobilJalanCount,
        'bookingCount': bookingCount,
      };
    } catch (e) {
      debugPrint('Error fetching dashboard counts: $e');
      return {
        'totalArmadaCount': 0,
        'mobilJalanCount': 0,
        'bookingCount': 0,
      };
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
        child: FutureBuilder<Map<String, int>>(
          future: _fetchCounts(),
          builder: (context, snapshot) {
            final counts = snapshot.data ?? {
              'totalArmadaCount': 0,
              'mobilJalanCount': 0,
              'bookingCount': 0,
            };

            final int mobilJalanCount = counts['mobilJalanCount']!;
            final int bookingCount = counts['bookingCount']!;
            final int totalArmadaCount = counts['totalArmadaCount']!;

            return RefreshIndicator(
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard Operasional',
                              style: TextStyle(
                                fontSize: 22, 
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Zahira Trans',
                              style: TextStyle(color: subTextColor, fontSize: 13),
                            ),
                          ],
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
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ActiveRentalScreen(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Icon(Icons.directions_car, color: Color(0xFF10B981)),
                                        Icon(Icons.arrow_forward_ios, size: 14, color: subTextColor),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '$mobilJalanCount',
                                      style: const TextStyle(
                                        fontSize: 27,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Mobil Jalan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: (isDark ? Colors.amber.shade400 : Colors.amber)
                                .withValues(alpha: isDark ? 0.2 : 0.1),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (widget.onNavigate != null) {
                                  widget.onNavigate!(1);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(
                                          Icons.bookmark, 
                                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade700
                                        ),
                                        Icon(Icons.arrow_forward_ios, size: 14, color: subTextColor),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '$bookingCount',
                                      style: TextStyle(
                                        fontSize: 27,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Booking',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: (isDark ? Colors.blue.shade400 : Colors.blue)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CarListScreen(onToggleTheme: widget.onToggleTheme),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.directions_car_filled, 
                                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Armada Mobil',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Total $totalArmadaCount unit terdaftar',
                                      style: TextStyle(
                                        color: subTextColor, 
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: (isDark ? Colors.teal.shade400 : Colors.teal)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PickupConfirmScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.checklist_rtl_rounded, 
                                          color: isDark ? Colors.teal.shade300 : Colors.teal.shade700
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Konfirmasi Pengambilan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$bookingCount unit menunggu diambil & cek overtime',
                                      style: TextStyle(
                                        color: subTextColor, 
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: (isDark ? Colors.orange.shade400 : Colors.orange)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReturnConfirmScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.assignment_returned_rounded, 
                                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade700
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Konfirmasi Pengembalian',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Kelola mobil kembali & cek status belum lunas',
                                      style: TextStyle(
                                        color: subTextColor, 
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: (isDark ? Colors.purple.shade400 : Colors.purple)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FleetReportScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Diperbaiki
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.analytics_rounded, 
                                          color: isDark ? Colors.purple.shade300 : Colors.purple.shade700
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Produktivitas Armada',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Lihat performa & total sewa per unit mobil',
                                      style: TextStyle(
                                        color: subTextColor, 
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
                              ],
                            ),
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
      ),
    );
  }
}