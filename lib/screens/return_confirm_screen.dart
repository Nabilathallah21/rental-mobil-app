import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Formatter helper untuk memformat input angka secara otomatis menjadi format ribuan Rupiah
class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Bersihkan karakter selain angka
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    int parsedValue = int.parse(cleanText);
    String formatted = _formatter.format(parsedValue);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  // Fungsi statis untuk mengubah string terformat kembali ke integer murni
  static int parseToInt(String text) {
    String clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }
}

class ReturnConfirmScreen extends StatefulWidget {
  const ReturnConfirmScreen({super.key});

  @override
  State<ReturnConfirmScreen> createState() => _ReturnConfirmScreenState();
}

class _ReturnConfirmScreenState extends State<ReturnConfirmScreen> {
  final supabase = Supabase.instance.client;

  // Fungsi untuk mengambil data transaksi dengan status 'berjalan' (atau 'jalan') dari Supabase
  Future<List<Map<String, dynamic>>> _fetchJalanTransactions() async {
    try {
      final response = await supabase
          .from('transactions')
          .select();
      
      final list = List<Map<String, dynamic>>.from(response);
      return list.where((t) {
        final status = (t['status'] ?? '').toString().toLowerCase();
        return status == 'berjalan' || status == 'jalan' || status == 'active';
      }).toList();
    } catch (e) {
      debugPrint('Error fetching jalan transactions: $e');
      return [];
    }
  }

  // Fungsi untuk mengambil data transaksi dengan status 'belum_lunas' dari Supabase
  Future<List<Map<String, dynamic>>> _fetchBelumLunasTransactions() async {
    try {
      final response = await supabase
          .from('transactions')
          .select()
          .eq('status', 'belum_lunas');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching belum_lunas transactions: $e');
      return [];
    }
  }

  // Fungsi untuk memproses pengembalian mobil dari status 'berjalan'
  Future<void> _processReturn(
    BuildContext context,
    Map<String, dynamic> transaction,
    int nominal,
    bool isLunas,
  ) async {
    try {
      final String transactionId = transaction['id'].toString();
      final carId = transaction['plat'] ?? '';

      final newStatus = isLunas ? 'selesai' : 'belum_lunas';
      final updateData = <String, dynamic>{
        'status': newStatus,
        'nominal': nominal,
      };

      if (isLunas) {
        updateData['tgl_selesai'] = DateTime.now().toIso8601String();
      }

      await supabase.from('transactions').update(updateData).eq('id', transactionId);

      if (carId.isNotEmpty) {
        await supabase.from('cars').update({
          'status': 'tersedia', 
        }).eq('plat', carId);
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isLunas ? const Color(0xFF10B981) : Colors.orange,
          content: Text(
            isLunas
                ? '✅ Mobil Pulang & Transaksi Lunas!'
                : '⚠️ Mobil Pulang & Tersedia, masuk ke Tab Belum Lunas!',
          ),
        ),
      );

      setState(() {});
    } catch (e) {
      debugPrint('Error processing return: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Gagal memproses pengembalian: $e'),
        ),
      );
    }
  }

  // Fungsi untuk melunasi transaksi dari tab 'belum_lunas'
  Future<void> _processRepayment(
    BuildContext context,
    String transactionId,
    int nominal,
  ) async {
    try {
      await supabase.from('transactions').update({
        'status': 'selesai',
        'nominal': nominal,
        'tgl_selesai': DateTime.now().toIso8601String(),
      }).eq('id', transactionId);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('✅ Pembayaran Lunas! Transaksi dipindahkan ke History.'),
        ),
      );

      setState(() {});
    } catch (e) {
      debugPrint('Error processing repayment: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Gagal memproses pelunasan: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengembalian & Pelunasan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  indicatorColor: const Color(0xFF10B981),
                  labelColor: const Color(0xFF10B981),
                  unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
                  tabs: const [
                    Tab(text: 'Konfirmasi Pulang'),
                    Tab(text: 'Belum Lunas (Piutang)'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildJalanTab(isDark),
                      _buildBelumLunasTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJalanTab(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchJalanTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Terjadi kesalahan: ${snapshot.error}'),
          );
        }

        final jalanList = snapshot.data ?? [];

        if (jalanList.isEmpty) {
          return const Center(
            child: Text(
              'Tidak ada mobil yang sedang jalan.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: jalanList.length,
            itemBuilder: (context, index) {
              final t = jalanList[index];
              return _JalanCardItem(
                transaction: t,
                isDark: isDark,
                onProcessReturn: (transaction, nominal, isLunas) {
                  _processReturn(context, transaction, nominal, isLunas);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBelumLunasTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchBelumLunasTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Terjadi kesalahan: ${snapshot.error}'),
          );
        }

        final belumLunasList = snapshot.data ?? [];

        if (belumLunasList.isEmpty) {
          return const Center(
            child: Text(
              'Tidak ada tunggakan pembayaran.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: belumLunasList.length,
            itemBuilder: (context, index) {
              final t = belumLunasList[index];
              return _BelumLunasCardItem(
                transaction: t,
                onProcessRepayment: (id, nominal) {
                  _processRepayment(context, id, nominal);
                },
              );
            },
          ),
        );
      },
    );
  }
}

// Widget Stateful terpisah untuk card tab "Jalan"
class _JalanCardItem extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final bool isDark;
  final Function(Map<String, dynamic> transaction, int nominal, bool isLunas) onProcessReturn;

  const _JalanCardItem({
    required this.transaction,
    required this.isDark,
    required this.onProcessReturn,
  });

  @override
  State<_JalanCardItem> createState() => _JalanCardItemState();
}

class _JalanCardItemState extends State<_JalanCardItem> {
  late final TextEditingController _controller;
  bool _payment1Status = true;
  bool _payment2Status = false;

  @override
  void initState() {
    super.initState();
    final nominal = widget.transaction['nominal'];
    
    // Format awal nilai nominal dengan format Rupiah jika data tersedia
    String initialText = '';
    if (nominal != null && nominal > 0) {
      initialText = NumberFormat('#,###', 'id_ID').format(int.tryParse(nominal.toString()) ?? 0);
    }

    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final String mobil = t['mobil'] ?? '-';
    final String pelanggan = t['pelanggan'] ?? '-';
    final String plat = t['plat'] ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$mobil - $pelanggan',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(plat, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    dense: true,
                    activeColor: const Color(0xFF10B981),
                    title: const Text('Payment 1 (Lunas)'),
                    value: _payment1Status,
                    onChanged: (val) {
                      setState(() => _payment1Status = val ?? true);
                    },
                  ),
                  CheckboxListTile(
                    dense: true,
                    activeColor: const Color(0xFF10B981),
                    title: const Text('Payment 2 (Belum Lunas)'),
                    value: _payment2Status,
                    onChanged: (val) {
                      setState(() => _payment2Status = val ?? false);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                labelText: 'Nominal Pembayaran',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
                onPressed: () {
                  int nominal = CurrencyInputFormatter.parseToInt(_controller.text);
                  bool isLunas = !_payment2Status;

                  widget.onProcessReturn(widget.transaction, nominal, isLunas);
                },
                child: const Text(
                  'Konfirmasi Pengembalian Mobil',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// Widget terpisah untuk tab "Belum Lunas"
class _BelumLunasCardItem extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final Function(String id, int nominal) onProcessRepayment;

  const _BelumLunasCardItem({
    required this.transaction,
    required this.onProcessRepayment,
  });

  @override
  State<_BelumLunasCardItem> createState() => _BelumLunasCardItemState();
}

class _BelumLunasCardItemState extends State<_BelumLunasCardItem> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final int existingNominal = widget.transaction['nominal'] ?? 0;
    
    String initialText = '';
    if (existingNominal > 0) {
      initialText = NumberFormat('#,###', 'id_ID').format(existingNominal);
    }

    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final String id = t['id'].toString();
    final String mobil = t['mobil'] ?? '-';
    final String pelanggan = t['pelanggan'] ?? '-';
    final String plat = t['plat'] ?? '-';
    final int durasi = t['durasi'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.orange.shade50.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.orange, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$mobil - $pelanggan',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Belum Lunas',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Plat: $plat | Durasi: $durasi Hari',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                labelText: 'Pelunasan Akhir',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
                onPressed: () {
                  int nominal = CurrencyInputFormatter.parseToInt(_controller.text);

                  if (nominal <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text(
                          '⚠️ Harap masukan nominal pelunasan dengan benar!',
                        ),
                      ),
                    );
                    return;
                  }

                  widget.onProcessRepayment(id, nominal);
                },
                label: const Text(
                  'Konfirmasi Lunas',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}