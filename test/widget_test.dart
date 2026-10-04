import 'package:flutter_test/flutter_test.dart';
import 'package:zahira_trans/main.dart';

void main() {
  testWidgets('Aplikasi Zahira Trans dapat dimuat', (WidgetTester tester) async {
    // Jalankan aplikasi ZahiraTransApp
    await tester.pumpWidget(const ZahiraTransApp());

    // Memastikan judul aplikasi 'Zahira Trans' muncul di layar
    expect(find.text('Zahira Trans'), findsOneWidget);
  });
}