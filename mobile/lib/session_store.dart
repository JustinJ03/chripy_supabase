import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// iPhone sessions use Keychain. The URL-specific key isolates local/cloud sessions.
class SessionStore extends LocalStorage {
  SessionStore(this.key);
  final String key;
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() => storage.read(key: key);
  @override
  Future<bool> hasAccessToken() => storage.containsKey(key: key);
  @override
  Future<void> persistSession(String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> removePersistedSession() => storage.delete(key: key);
}
