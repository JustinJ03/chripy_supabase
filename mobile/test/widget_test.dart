import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chripy/main.dart';

void main() {
  testWidgets('Setup error is actionable without a backend', (tester) async {
    await tester.pumpWidget(const ChripyApp(problem: 'Missing settings'));
    expect(find.text('Chripy setup'), findsOneWidget);
    expect(find.text('Missing settings'), findsOneWidget);
  });
  testWidgets('Composer rejects whitespace and returns trimmed text', (
    tester,
  ) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await editText(context, 'New chirp');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Use 1–280 characters.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), ' Hello Chripy ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, 'Hello Chripy');
  });

  for (final field in ['Display name', 'Bio']) {
    testWidgets('Profile rejects oversized Unicode $field before saving', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileEditor()));
      Finder input(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.enterText(input('Username'), 'alice');
      await tester.enterText(input('Display name'), 'Alice');
      // Each visible accented letter contains two database characters.
      await tester.enterText(
        input(field),
        List.filled(field == 'Bio' ? 81 : 26, 'e\u0301').join(),
      );
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          field == 'Bio'
              ? 'Use at most 160 characters for your bio.'
              : 'Use 1–50 characters for your display name.',
        ),
        findsOneWidget,
      );
    });
  }
}
