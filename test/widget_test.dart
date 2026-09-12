import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/auth/presentation/welcome_screen.dart';

void main() {
  testWidgets('Welcome screen shows branding and entry points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WelcomeScreen()),
    );

    expect(find.text('SafeStep'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
