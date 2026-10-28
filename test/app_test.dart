import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/screens/login_page.dart';
import 'package:memory_stack/screens/onboarding_page.dart';

Future<void> pumpLogin(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // phone-sized, so the whole form fits
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(const MaterialApp(home: LoginPage()));
}

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
    await tester.tap(find.widgetWithText(TextButton, 'Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'me@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign up'));
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

  testWidgets('intro slides: next, next, Get started; Skip ends it early', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: OnboardingPage(onDone: () => done++)));
    expect(find.text('Solve with a plan'), findsOneWidget);
    for (final title in ['Review on schedule', 'Watch it stick']) {
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      for (var f = 0; f < 20; f++) {
        await tester.pump(const Duration(milliseconds: 50)); // step through the slide animation
      }
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text('Get started'));
    expect(done, 1);

    await tester.pumpWidget(MaterialApp(home: OnboardingPage(key: UniqueKey(), onDone: () => done++)));
    await tester.tap(find.text('Skip'));
    expect(done, 2);
  });
}
