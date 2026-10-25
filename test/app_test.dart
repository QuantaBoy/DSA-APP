import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/main.dart';

void main() {
  testWidgets('app starts and shows its name', (tester) async {
    await tester.pumpWidget(const MemoryStackApp());
    expect(find.text('Memory Stack'), findsOneWidget);
  });
}
