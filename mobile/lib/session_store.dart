// Import the platform secure-storage plugin used for native session persistence.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Import Supabase initialization, authentication, database, and storage APIs.
import 'package:supabase_flutter/supabase_flutter.dart';

/// iPhone sessions use Keychain. The URL-specific key isolates local/cloud sessions.
// Implement Supabase LocalStorage with secure native storage, including iOS Keychain.
class SessionStore extends LocalStorage {
  // Construct this SessionStore and accept its immutable inputs/callbacks.
  SessionStore(this.key);
  // Keep the backend-specific key used for all secure session operations.
  final String key;
  // Use the platform secure-storage implementation rather than plain preferences.
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Satisfy the storage lifecycle; this adapter needs no separate initialization work.
  Future<void> initialize() async {}
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Read the serialized session under this backend-specific secure-storage key.
  Future<String?> accessToken() => storage.read(key: key);
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Report whether a serialized session is stored for this backend.
  Future<bool> hasAccessToken() => storage.containsKey(key: key);
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Save the complete serialized session supplied by Supabase Auth.
  Future<void> persistSession(String value) =>
      // Delegate this session operation to the secure-storage plugin using the backend key.
      storage.write(key: key, value: value);
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Remove the saved session when Supabase signs out.
  Future<void> removePersistedSession() => storage.delete(key: key);
}
