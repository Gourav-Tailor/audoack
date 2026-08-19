import 'package:flutter_test/flutter_test.dart';
import 'package:audoack/main.dart';

void main() {
  testWidgets('Audoack app starts', (tester) async {
    await tester.pumpWidget(const AutoAceApp());
    expect(find.byType(AutoAceApp), findsOneWidget);
  });
}
