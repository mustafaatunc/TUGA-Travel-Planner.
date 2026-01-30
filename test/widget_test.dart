import 'package:flutter_test/flutter_test.dart';
import 'package:TUGA/main.dart';

void main() {
  testWidgets('Uygulama başlatma testi', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(seenOnboarding: false));

    await tester.pumpAndSettle();
  });
}
