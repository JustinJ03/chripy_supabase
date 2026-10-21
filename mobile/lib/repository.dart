import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef DataRow = Map<String, dynamic>;

class Repository {
  Repository(this.client);
  final SupabaseClient client;
  String? get currentUid => client.auth.currentUser?.id;
  String get uid =>
      currentUid ?? (throw const AuthException('Please log in again.'));

  Future<DataRow?> profile(String id) =>
      client.from('profiles').select().eq('id', id).maybeSingle();
  Future<void> saveProfile(DataRow values, {required bool create}) async {
    if (create) {
      await client.from('profiles').insert({'id': uid, ...values});
    } else {
      await client
          .from('profiles')
          .update(values)
          .eq('id', uid)
          .select()
          .single();
    }
  }

  Future<List<DataRow>> posts({String? author, DataRow? cursor}) async {
    var query = client.from('feed').select();
    if (author != null) query = query.eq('author_id', author);
    if (cursor != null) {
      query = query.or(
        'created_at.lt.${cursor['created_at']},and(created_at.eq.${cursor['created_at']},id.lt.${cursor['id']})',
      );
    }
    return await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(20);
  }

  Future<DataRow> post(String id) =>
      client.from('feed').select().eq('id', id).single();
  Future<void> writePost(String text, {String? id}) async {
    if (id == null) {
      await client.from('posts').insert({
        'author_id': uid,
        'body': text.trim(),
      });
    } else {
      await client
          .from('posts')
          .update({'body': text.trim()})
          .eq('id', id)
          .select()
          .single();
    }
  }

  Future<void> deletePost(String id) async {
    await client.from('posts').delete().eq('id', id).select().single();
  }

  Future<void> setLike(String postId, bool liked) async {
    if (liked) {
      try {
        await client.from('likes').insert({'post_id': postId, 'user_id': uid});
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // Repeated like is harmless.
      }
    } else {
      await client
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    }
  }

  Future<List<DataRow>> comments(String postId, {DataRow? cursor}) async {
    var query = client.from('comment_feed').select().eq('post_id', postId);
    if (cursor != null) {
      query = query.or(
        'created_at.lt.${cursor['created_at']},and(created_at.eq.${cursor['created_at']},id.lt.${cursor['id']})',
      );
    }
    return await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(20);
  }

  Future<void> comment(String postId, String text) async {
    await client.from('comments').insert({
      'post_id': postId,
      'author_id': uid,
      'body': text.trim(),
    });
  }

  Future<void> deleteComment(String id) async {
    await client.from('comments').delete().eq('id', id).select().single();
  }

  Future<Uint8List> avatar(String path) =>
      client.storage.from('avatars').download(path);

  /// Returns an optional cleanup warning; a saved photo must not look like a failed save.
  Future<String?> replaceAvatar(XFile file, String? oldPath) async {
    if (await file.length() > 20 * 1024 * 1024) {
      throw Exception('Choose an image under 20 MB before resizing.');
    }
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null)
      throw Exception('Choose JPEG or PNG. Export HEIC as JPEG first.');
    final oriented = img.bakeOrientation(decoded);
    final resized = img.copyResize(
      oriented,
      width: oriented.width >= oriented.height ? 512 : null,
      height: oriented.height > oriented.width ? 512 : null,
    );
    final bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    if (bytes.length > 2 * 1024 * 1024)
      throw Exception('Photo must be under 2 MB after resizing.');
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    try {
      await saveProfile({'avatar_path': path}, create: false);
    } catch (_) {
      try {
        await client.storage.from('avatars').remove([path]);
      } catch (_) {}
      rethrow;
    }
    if (oldPath != null) {
      try {
        await client.storage.from('avatars').remove([oldPath]);
      } catch (_) {
        return 'Photo saved. The old file could not be removed; retry cleanup in Storage.';
      }
    }
    return null;
  }

  Future<String?> removeAvatar(String? path) async {
    await saveProfile({'avatar_path': null}, create: false);
    if (path != null) {
      try {
        await client.storage.from('avatars').remove([path]);
      } catch (_) {
        return 'Photo removed from profile. Storage cleanup needs a retry.';
      }
    }
    return null;
  }
}
