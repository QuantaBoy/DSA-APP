import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/screens/login_page.dart';

Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(const MaterialApp(home: LoginPage()));

void main() {
  testWidgets('sign in with empty fields shows validation errors', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('create account asks for name and an 8+ character password', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'me@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('forgot password without email asks for it first', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    expect(find.textContaining('Type your email above first'), findsOneWidget);
  });
}
