class MaintenanceModel {
  int id;
  String mobil;
  String plat;
  String jenisPerawatan;
  int biaya;
  DateTime tanggal;

  MaintenanceModel({
    required this.id,
    required this.mobil,
    required this.plat,
    required this.jenisPerawatan,
    required this.biaya,
    required this.tanggal,
  });
}