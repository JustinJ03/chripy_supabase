// Import Material widgets, themes, navigation, and layout widgets such as Row.
import 'package:flutter/material.dart';
// Import Flutter test runners, simulated gestures, finders, and assertions.
import 'package:flutter_test/flutter_test.dart';
// Import the app widgets and dialog helpers exercised by these tests.
import 'package:chripy/main.dart';

// Register this file's tests with the Flutter test runner.
void main() {
  // Register a regression scenario that runs with a real Flutter widget tree.
  testWidgets('Setup error is actionable without a backend', (tester) async {
    // Mount this widget tree in the test environment.
    await tester.pumpWidget(const ChripyApp(problem: 'Missing settings'));
    // Compare the actual returned value or visible widgets with the expected result.
    expect(find.text('Chripy setup'), findsOneWidget);
    // Compare the actual returned value or visible widgets with the expected result.
    expect(find.text('Missing settings'), findsOneWidget);
  });
  // Register a regression scenario that runs with a real Flutter widget tree.
  testWidgets('Composer rejects whitespace and returns trimmed text', (
    // Supply this parameter/value to the surrounding function or request.
    tester,
    // Run this widget-test callback asynchronously so simulated gestures can be awaited.
  ) async {
    // Capture the value returned by the composer for the final assertion.
    String? saved;
    // Mount this widget tree in the test environment.
    await tester.pumpWidget(
      // Build the root Material app with a theme and navigator.
      MaterialApp(
        // Choose the first screen displayed by this MaterialApp.
        home: Builder(
          // Build widgets from the latest context and asynchronous or observable state.
          builder: (context) => Scaffold(
            // Supply the main screen content below the app bar.
            body: TextButton(
              // Connect this button to its action; null disables it while appropriate.
              onPressed: () async {
                // Capture the composer result after the test opens and submits the dialog.
                saved = await editText(context, 'New chirp');
              },
              // Supply the single widget or expression displayed inside this parent.
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    // Simulate tapping the located control to exercise the real UI callback.
    await tester.tap(find.text('Open'));
    // Advance frames until dialog transitions and scheduled rebuilds finish.
    await tester.pumpAndSettle();
    // Enter the test input through the widget rather than calling its private handler.
    await tester.enterText(find.byType(TextField), '   ');
    // Simulate tapping the located control to exercise the real UI callback.
    await tester.tap(find.text('Save'));
    // Advance frames until dialog transitions and scheduled rebuilds finish.
    await tester.pumpAndSettle();
    // Compare the actual returned value or visible widgets with the expected result.
    expect(find.text('Use 1–280 characters.'), findsOneWidget);
    // Enter the test input through the widget rather than calling its private handler.
    await tester.enterText(find.byType(TextField), ' Hello Chripy ');
    // Simulate tapping the located control to exercise the real UI callback.
    await tester.tap(find.text('Save'));
    // Advance frames until dialog transitions and scheduled rebuilds finish.
    await tester.pumpAndSettle();
    // Compare the actual returned value or visible widgets with the expected result.
    expect(saved, 'Hello Chripy');
  });

  // Exercise the oversized Unicode case separately for display name and biography.
  for (final field in ['Display name', 'Bio']) {
    // Register a regression scenario that runs with a real Flutter widget tree.
    testWidgets('Profile rejects oversized Unicode $field before saving', (
      // Supply this parameter/value to the surrounding function or request.
      tester,
      // Run this widget-test callback asynchronously so simulated gestures can be awaited.
    ) async {
      // Mount this widget tree in the test environment.
      await tester.pumpWidget(const MaterialApp(home: ProfileEditor()));
      // Locate a profile TextField by its label without depending on list position.
      Finder input(String label) => find.byWidgetPredicate(
        // Inspect each candidate widget before selecting the requested form field.
        (widget) =>
            // Match only the text input whose decoration has the expected label.
            widget is TextField && widget.decoration?.labelText == label,
      );
      // Enter the test input through the widget rather than calling its private handler.
      await tester.enterText(input('Username'), 'alice');
      // Enter the test input through the widget rather than calling its private handler.
      await tester.enterText(input('Display name'), 'Alice');
      // Each visible accented letter contains two database characters.
      // Enter the test input through the widget rather than calling its private handler.
      await tester.enterText(
        // Choose the profile field being tested in this loop iteration.
        input(field),
        // Create a visually short accented string that exceeds the database code-point limit.
        List.filled(field == 'Bio' ? 81 : 26, 'e\u0301').join(),
      );
      // Scroll the save control into view before simulating its tap.
      await tester.ensureVisible(find.text('Save profile'));
      // Simulate tapping the located control to exercise the real UI callback.
      await tester.tap(find.text('Save profile'));
      // Advance frames until dialog transitions and scheduled rebuilds finish.
      await tester.pumpAndSettle();
      // Compare the actual returned value or visible widgets with the expected result.
      expect(
        // Locate the text, input, or dialog required by this assertion/gesture.
        find.text(
          // Choose the appropriate expected validation message for this profile field.
          field == 'Bio'
              // Choose this value for the corresponding true/false branch of the condition above.
              ? 'Use at most 160 characters for your bio.'
              // Choose this value for the corresponding true/false branch of the condition above.
              : 'Use 1–50 characters for your display name.',
        ),
        // Require this matcher outcome for the value or widgets under test.
        findsOneWidget,
      );
    });
  }
}
