// Import JSON encoding for the synthetic session used by these tests.
import 'dart:convert';
// Import the app widgets and dialog helpers exercised by these tests.
import 'package:chripy/main.dart';
// Import Material widgets, themes, navigation, and layout widgets such as Row.
import 'package:flutter/material.dart';
// Import Flutter test runners, simulated gestures, finders, and assertions.
import 'package:flutter_test/flutter_test.dart';
// Import Supabase initialization, authentication, database, and storage APIs.
import 'package:supabase_flutter/supabase_flutter.dart';

// Provide a no-op PKCE storage adapter so tests do not require platform plugins.
class _MemoryStorage extends GotrueAsyncStorage {
  // Construct this MemoryStorage and accept its immutable inputs/callbacks.
  const _MemoryStorage();
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Return no saved PKCE data in this backend-independent test fixture.
  Future<String?> getItem({required String key}) async => null;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Accept PKCE writes without creating files or calling a platform plugin.
  Future<void> setItem({required String key, required String value}) async {}
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Accept PKCE cleanup without touching real device storage.
  Future<void> removeItem({required String key}) async {}
}

// Register this file's tests with the Flutter test runner.
void main() {
  // Initialize an isolated SDK fixture before each test in this file.
  setUp(() async {
    // Initialize the SDK with these server/auth options before any client access.
    await Supabase.initialize(
      // Use this Supabase server address; the phone build must use a reachable LAN address.
      url: 'http://localhost:54321',
      // Pass a client publishable/anon key; privileged server keys never belong here.
      publishableKey: 'test-key',
      // Configure session storage and authentication behavior.
      authOptions: const FlutterAuthClientOptions(
        // Choose the session persistence adapter for this platform or test.
        localStorage: EmptyLocalStorage(),
        // Avoid SharedPreferences platform calls by supplying the test-only PKCE adapter.
        pkceAsyncStorage: _MemoryStorage(),
        // Disable periodic token refresh for this synthetic test session.
        autoRefreshToken: false,
        // Disable deep-link session detection in this widget test.
        detectSessionInUri: false,
      ),
    );
  });
  // Dispose the singleton after every test so auth state cannot leak into another case.
  tearDown(() => Supabase.instance.dispose());

  // Build the shared post-card fixture with deterministic author, text, and counters.
  Widget card() => PostCard(
    // Pass the feed record to PostCard using its row parameter.
    row: {
      // Supply this deterministic post field so the widget test needs no database record.
      'id': 'post-1',
      // Attribute the new content to the authenticated user; the database checks ownership.
      'author_id': 'user-1',
      // Supply this deterministic post field so the widget test needs no database record.
      'display_name': 'Alice',
      // Supply this deterministic post field so the widget test needs no database record.
      'username': 'alice',
      // Supply this deterministic post field so the widget test needs no database record.
      'body': 'Original post',
      // Supply this deterministic post field so the widget test needs no database record.
      'created_at': '2026-10-20T00:00:00Z',
      // Supply this deterministic post field so the widget test needs no database record.
      'like_count': 0,
      // Supply this deterministic post field so the widget test needs no database record.
      'comment_count': 0,
      // Supply this deterministic post field so the widget test needs no database record.
      'liked': false,
    },
    // Refresh the surrounding feed or conversation after a mutation.
    onChanged: () async {},
    // Open the selected author's profile from the card.
    onProfile: (_) async {},
  );

  // Register a regression scenario that runs with a real Flutter widget tree.
  testWidgets('Post card tolerates a session that has ended', (tester) async {
    // Mount this widget tree in the test environment.
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: card())));
    // Assert that rendering or confirming the dialog raised no Flutter exception.
    expect(tester.takeException(), isNull);
    // Compare the actual returned value or visible widgets with the expected result.
    expect(find.text('Original post'), findsOneWidget);
    // Compare the actual returned value or visible widgets with the expected result.
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  // Run the same disposal regression for both the Edit and Delete dialogs.
  for (final action in ['Edit', 'Delete']) {
    // Register a regression scenario that runs with a real Flutter widget tree.
    testWidgets('$action dialog tolerates its post being removed', (
      // Supply this parameter/value to the surrounding function or request.
      tester,
      // Run this widget-test callback asynchronously so simulated gestures can be awaited.
    ) async {
      // Install a synthetic session so the card exposes its owner menu without contacting Auth.
      await Supabase.instance.client.auth.setInitialSession(
        // Serialize this minimal fake session using the same format consumed by the auth client.
        jsonEncode({
          // Use a synthetic token; no real credentials or backend request are needed.
          'access_token': 'test-token',
          // Supply the token type required by the session JSON structure.
          'token_type': 'bearer',
          // Make the synthetic signed-in user match the post author for owner-menu tests.
          'user': {'id': 'user-1'},
        }),
      );
      // Let the test remove the underlying card while keeping its dialog open.
      final visible = ValueNotifier(true);
      // Release the fixture notifier after the test finishes.
      addTearDown(visible.dispose);
      // Mount this widget tree in the test environment.
      await tester.pumpWidget(
        // Build the root Material app with a theme and navigator.
        MaterialApp(
          // Choose the first screen displayed by this MaterialApp.
          home: Scaffold(
            // Supply the main screen content below the app bar.
            body: ValueListenableBuilder<bool>(
              // Rebuild the fixture when the test removes the underlying post card.
              valueListenable: visible,
              // Build widgets from the latest context and asynchronous or observable state.
              builder: (_, show, _) => show ? card() : const SizedBox(),
            ),
          ),
        ),
      );
      // Simulate tapping the located control to exercise the real UI callback.
      await tester.tap(find.byType(PopupMenuButton<String>));
      // Advance frames until dialog transitions and scheduled rebuilds finish.
      await tester.pumpAndSettle();
      // Simulate tapping the located control to exercise the real UI callback.
      await tester.tap(find.text(action));
      // Advance frames until dialog transitions and scheduled rebuilds finish.
      await tester.pumpAndSettle();
      // Remove the underlying post card before confirming the still-open dialog.
      visible.value = false;
      // Advance frames until dialog transitions and scheduled rebuilds finish.
      await tester.pumpAndSettle();
      // Simulate tapping the located control to exercise the real UI callback.
      await tester.tap(find.text(action == 'Edit' ? 'Save' : 'Delete'));
      // Advance frames until dialog transitions and scheduled rebuilds finish.
      await tester.pumpAndSettle();
      // Assert that rendering or confirming the dialog raised no Flutter exception.
      expect(tester.takeException(), isNull);
      // Compare the actual returned value or visible widgets with the expected result.
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
}
