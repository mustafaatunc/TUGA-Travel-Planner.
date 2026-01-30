import 'package:flutter_test/flutter_test.dart';
import 'package:harita_uygulamasi/main.dart';

void main() {
  testWidgets('Uygulama başlatma testi', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(seenOnboarding: false));

    await tester.pumpAndSettle();
  });
}
