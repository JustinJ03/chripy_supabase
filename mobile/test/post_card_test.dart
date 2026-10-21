import 'dart:convert';
import 'package:chripy/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryStorage extends GotrueAsyncStorage {
  const _MemoryStorage();
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
  @override
  Future<void> removeItem({required String key}) async {}
}

void main() {
  setUp(() async {
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });
  tearDown(() => Supabase.instance.dispose());

  Widget card() => PostCard(
    row: {
      'id': 'post-1',
      'author_id': 'user-1',
      'display_name': 'Alice',
      'username': 'alice',
      'body': 'Original post',
      'created_at': '2026-10-20T00:00:00Z',
      'like_count': 0,
      'comment_count': 0,
      'liked': false,
    },
    onChanged: () async {},
    onProfile: (_) async {},
  );

  testWidgets('Post card tolerates a session that has ended', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: card())));
    expect(tester.takeException(), isNull);
    expect(find.text('Original post'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  for (final action in ['Edit', 'Delete']) {
    testWidgets('$action dialog tolerates its post being removed', (
      tester,
    ) async {
      await Supabase.instance.client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'test-token',
          'token_type': 'bearer',
          'user': {'id': 'user-1'},
        }),
      );
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, show, _) => show ? card() : const SizedBox(),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      visible.value = false;
      await tester.pumpAndSettle();
      await tester.tap(find.text(action == 'Edit' ? 'Save' : 'Delete'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
}
