class TransactionModel {
  final int id;
  final String pelanggan;
  final String mobil;
  final String plat;
  final DateTime tglMulai;
  int durasi;     // <-- Kata 'final' dihapus agar bisa diubah
  int nominal;    // <-- Kata 'final' dihapus agar bisa diubah
  String status; // 'booking', 'berjalan', 'selesai'
  DateTime? tglDiambil; // Waktu aktual mobil diambil/diantar
  DateTime? tglSelesai;  // Waktu aktual mobil dikembalikan
  int biayaOvertime;     // Tambahan biaya jika overtime

  TransactionModel({
    required this.id,
    required this.pelanggan,
    required this.mobil,
    required this.plat,
    required this.tglMulai,
    required this.durasi,
    required this.nominal,
    this.status = 'booking',
    this.tglDiambil,
    this.tglSelesai,
    this.biayaOvertime = 0,
  });
}