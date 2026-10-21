// Import Uint8List, the byte buffer used for downloaded and encoded photos.
import 'dart:typed_data';
// Import image decoding, orientation, resizing, and JPEG encoding under the img prefix.
import 'package:image/image.dart' as img;
// Import the photo-library picker and its XFile result type.
import 'package:image_picker/image_picker.dart';
// Import Supabase initialization, authentication, database, and storage APIs.
import 'package:supabase_flutter/supabase_flutter.dart';

// Name the JSON-like map returned by Supabase; UI code refers to it as db.DataRow.
typedef DataRow = Map<String, dynamic>;

// Keep Supabase queries and avatar processing outside the widget code.
class Repository {
  // Construct this Repository and accept its immutable inputs/callbacks.
  Repository(this.client);
  // Retain the authenticated SDK client injected into this repository.
  final SupabaseClient client;
  // Return null safely when the current auth session has ended.
  String? get currentUid => client.auth.currentUser?.id;
  // Require authentication for operations that must attach a user ID.
  String get uid =>
      // Return the signed-in ID or produce a readable auth error instead of a null assertion.
      currentUid ?? (throw const AuthException('Please log in again.'));

  // Read one profile, returning null when onboarding has not created it yet.
  Future<DataRow?> profile(String id) =>
      // Read the matching profile/feed record through the Supabase Data API.
      client.from('profiles').select().eq('id', id).maybeSingle();
  // Insert an onboarding profile or update only the current user's profile.
  Future<void> saveProfile(DataRow values, {required bool create}) async {
    // Insert a profile only for the initial onboarding save.
    if (create) {
      // Attach the current user ID to the new profile; server grants and RLS validate it.
      await client.from('profiles').insert({'id': uid, ...values});
      // Use the alternative branch when the preceding condition did not match.
    } else {
      // Start a database mutation and wait for the complete chained request.
      await client
          // Select the table or bucket used by this chained SDK request.
          .from('profiles')
          // Send only the supplied mutable fields; RLS and column grants remain authoritative.
          .update(values)
          // Narrow the request to the specified record, owner, or conversation.
          .eq('id', uid)
          // Request the modified row back so zero-row writes can be detected.
          .select()
          // Require exactly one returned row; missing or unauthorized writes become errors.
          .single();
    }
  }

  // Read one page of feed records, optionally filtered by author and cursor.
  Future<List<DataRow>> posts({String? author, DataRow? cursor}) async {
    // Start from the enriched, security-invoker feed view.
    var query = client.from('feed').select();
    // Restrict results to one author when displaying a profile timeline.
    if (author != null) query = query.eq('author_id', author);
    // Apply keyset pagination only when continuing after an existing record.
    if (cursor != null) {
      // Select records older than the cursor, breaking timestamp ties with the UUID.
      query = query.or(
        // Match an earlier timestamp, or the same timestamp with a smaller ID.
        'created_at.lt.${cursor['created_at']},and(created_at.eq.${cursor['created_at']},id.lt.${cursor['id']})',
      );
    }
    // Execute the filtered query with the ordering and page limit below.
    return await query
        // Apply descending order; timestamp plus ID provides a stable pagination order.
        .order('created_at', ascending: false)
        // Apply descending order; timestamp plus ID provides a stable pagination order.
        .order('id', ascending: false)
        // Return at most twenty records in this page.
        .limit(20);
  }

  // Read exactly one enriched feed record for a conversation page.
  Future<DataRow> post(String id) =>
      // Read the matching profile/feed record through the Supabase Data API.
      client.from('feed').select().eq('id', id).single();
  // Insert a new post or update the specified post with trimmed body text.
  Future<void> writePost(String text, {String? id}) async {
    // Create a new post when no existing post ID was supplied.
    if (id == null) {
      // Execute this database write with the current authenticated client and server-side RLS.
      await client.from('posts').insert({
        // Attribute the new content to the authenticated user; the database checks ownership.
        'author_id': uid,
        // Remove surrounding whitespace before saving the content body.
        'body': text.trim(),
      });
      // Use the alternative branch when the preceding condition did not match.
    } else {
      // Start a database mutation and wait for the complete chained request.
      await client
          // Select the table or bucket used by this chained SDK request.
          .from('posts')
          // Send only the supplied mutable fields; RLS and column grants remain authoritative.
          .update({'body': text.trim()})
          // Narrow the request to the specified record, owner, or conversation.
          .eq('id', id)
          // Request the modified row back so zero-row writes can be detected.
          .select()
          // Require exactly one returned row; missing or unauthorized writes become errors.
          .single();
    }
  }

  // Delete the selected post; database rules enforce ownership and cascading cleanup.
  Future<void> deletePost(String id) async {
    // Execute this database write with the current authenticated client and server-side RLS.
    await client.from('posts').delete().eq('id', id).select().single();
  }

  // Insert or remove the current user's like, tolerating an already existing like.
  Future<void> setLike(String postId, bool liked) async {
    // Insert a like when the requested resulting state is liked.
    if (liked) {
      // Catch failures from the asynchronous operation so the UI can report them.
      try {
        // Execute this database write with the current authenticated client and server-side RLS.
        await client.from('likes').insert({'post_id': postId, 'user_id': uid});
        // Catch the failure and translate it into feedback for this operation.
      } on PostgrestException catch (e) {
        // Ignore only duplicate-key errors from repeated likes; surface all other database failures.
        if (e.code != '23505') rethrow; // Repeated like is harmless.
      }
      // Use the alternative branch when the preceding condition did not match.
    } else {
      // Start a database mutation and wait for the complete chained request.
      await client
          // Select the table or bucket used by this chained SDK request.
          .from('likes')
          // Delete matching rows subject to the current user's ownership policies.
          .delete()
          // Narrow the request to the specified record, owner, or conversation.
          .eq('post_id', postId)
          // Narrow the request to the specified record, owner, or conversation.
          .eq('user_id', uid);
    }
  }

  // Read one page of enriched replies belonging to the selected post.
  Future<List<DataRow>> comments(String postId, {DataRow? cursor}) async {
    // Start from replies enriched with author details and restrict them to one post.
    var query = client.from('comment_feed').select().eq('post_id', postId);
    // Apply keyset pagination only when continuing after an existing record.
    if (cursor != null) {
      // Select records older than the cursor, breaking timestamp ties with the UUID.
      query = query.or(
        // Match an earlier timestamp, or the same timestamp with a smaller ID.
        'created_at.lt.${cursor['created_at']},and(created_at.eq.${cursor['created_at']},id.lt.${cursor['id']})',
      );
    }
    // Execute the filtered query with the ordering and page limit below.
    return await query
        // Apply descending order; timestamp plus ID provides a stable pagination order.
        .order('created_at', ascending: false)
        // Apply descending order; timestamp plus ID provides a stable pagination order.
        .order('id', ascending: false)
        // Return at most twenty records in this page.
        .limit(20);
  }

  // Create a trimmed reply owned by the current user.
  Future<void> comment(String postId, String text) async {
    // Execute this database write with the current authenticated client and server-side RLS.
    await client.from('comments').insert({
      // Supply this literal message, label, or formatted value to the surrounding expression.
      'post_id': postId,
      // Attribute the new content to the authenticated user; the database checks ownership.
      'author_id': uid,
      // Remove surrounding whitespace before saving the content body.
      'body': text.trim(),
    });
  }

  // Delete one reply; database policies allow only its author to delete it.
  Future<void> deleteComment(String id) async {
    // Execute this database write with the current authenticated client and server-side RLS.
    await client.from('comments').delete().eq('id', id).select().single();
  }

  // Download an avatar using the signed-in client and private-bucket permissions.
  Future<Uint8List> avatar(String path) =>
      // Download from the private avatars bucket with the current session credentials.
      client.storage.from('avatars').download(path);

  /// Returns an optional cleanup warning; a saved photo must not look like a failed save.
  // Resize and upload a new JPEG, save its path, then clean up the previous file.
  Future<String?> replaceAvatar(XFile file, String? oldPath) async {
    // Reject an oversized source file before decoding it into memory.
    if (await file.length() > 20 * 1024 * 1024) {
      // Stop the operation and pass this readable validation failure to the surrounding handler.
      throw Exception('Choose an image under 20 MB before resizing.');
    }
    // Read the selected bytes and attempt to decode a supported image format.
    final decoded = img.decodeImage(await file.readAsBytes());
    // Report unsupported input, including HEIC when the decoder cannot handle it.
    if (decoded == null)
      // Stop the operation and pass this readable validation failure to the surrounding handler.
      throw Exception('Choose JPEG or PNG. Export HEIC as JPEG first.');
    // Apply orientation metadata so the JPEG is not accidentally rotated.
    final oriented = img.bakeOrientation(decoded);
    // Resize the longer dimension to 512 pixels, preserving proportions.
    final resized = img.copyResize(
      // Use the orientation-corrected pixels as the resize input.
      oriented,
      // Resize by width for landscape/square photos while preserving aspect ratio.
      width: oriented.width >= oriented.height ? 512 : null,
      // Resize by height for portrait photos while preserving aspect ratio.
      height: oriented.height > oriented.width ? 512 : null,
    );
    // Encode the resized photo as an 85-quality JPEG byte buffer.
    final bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    // Enforce the avatars bucket's two-megabyte limit after compression.
    if (bytes.length > 2 * 1024 * 1024)
      // Stop the operation and pass this readable validation failure to the surrounding handler.
      throw Exception('Photo must be under 2 MB after resizing.');
    // Store a new filename inside the owner's UUID folder instead of overwriting an object.
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    // Upload through the authenticated storage client.
    await client.storage
        // Select the table or bucket used by this chained SDK request.
        .from('avatars')
        // Upload the JPEG bytes at a new owner-prefixed storage path.
        .uploadBinary(
          // Supply this parameter/value to the surrounding function or request.
          path,
          // Supply this parameter/value to the surrounding function or request.
          bytes,
          // Label the uploaded bytes as JPEG for the storage MIME restriction.
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Save the new photo path only after its upload has succeeded.
      await saveProfile({'avatar_path': path}, create: false);
      // Handle cleanup/save failures without losing the original operation's outcome.
    } catch (_) {
      // Catch failures from the asynchronous operation so the UI can report them.
      try {
        // Remove this stored object using the current user's storage permissions.
        await client.storage.from('avatars').remove([path]);
        // Handle cleanup/save failures without losing the original operation's outcome.
      } catch (_) {}
      // Propagate the original failure after best-effort cleanup.
      rethrow;
    }
    // Clean up the previous object only after the replacement has been saved.
    if (oldPath != null) {
      // Catch failures from the asynchronous operation so the UI can report them.
      try {
        // Remove the old avatar to avoid leaving unused private objects.
        await client.storage.from('avatars').remove([oldPath]);
        // Handle cleanup/save failures without losing the original operation's outcome.
      } catch (_) {
        // Return this result/message to the caller instead of continuing the operation.
        return 'Photo saved. The old file could not be removed; retry cleanup in Storage.';
      }
    }
    // Report no validation/cleanup warning, or no saved value for the no-op test adapter.
    return null;
  }

  // Clear the profile photo first, then try to remove the old stored object.
  Future<String?> removeAvatar(String? path) async {
    // Clear the profile reference before attempting storage deletion.
    await saveProfile({'avatar_path': null}, create: false);
    // Skip object deletion when the profile had no stored photo.
    if (path != null) {
      // Catch failures from the asynchronous operation so the UI can report them.
      try {
        // Remove this stored object using the current user's storage permissions.
        await client.storage.from('avatars').remove([path]);
        // Handle cleanup/save failures without losing the original operation's outcome.
      } catch (_) {
        // Return this result/message to the caller instead of continuing the operation.
        return 'Photo removed from profile. Storage cleanup needs a retry.';
      }
    }
    // Report no validation/cleanup warning, or no saved value for the no-op test adapter.
    return null;
  }
}
