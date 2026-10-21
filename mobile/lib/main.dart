import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'repository.dart' as db;
import 'session_store.dart';
import 'validation.dart';

db.Repository get repo => db.Repository(Supabase.instance.client);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  String? problem;
  if (url.isEmpty || key.isEmpty) {
    problem =
        'Missing Supabase settings. Follow README.md and run with '
        '--dart-define-from-file=config.local.json.';
  } else {
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: key,
        authOptions: FlutterAuthClientOptions(
          // Web preview deliberately does not retain credentials after reload.
          localStorage: kIsWeb
              ? const EmptyLocalStorage()
              : SessionStore('chripy.session.$url'),
        ),
      );
    } catch (_) {
      problem =
          'Could not initialize Supabase. Check your configuration and restart.';
    }
  }
  runApp(ChripyApp(problem: problem));
}

class ChripyApp extends StatelessWidget {
  const ChripyApp({super.key, this.problem});
  final String? problem;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Chripy',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f83)),
      scaffoldBackgroundColor: const Color(0xfff7faf9),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: problem == null
        ? const AuthGate()
        : Scaffold(
            appBar: AppBar(title: const Text('Chripy setup')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(problem!),
            ),
          ),
  );
}

String message(Object e) {
  if (e is AuthException) return e.message;
  if (e is PostgrestException) {
    if (e.code == '23505') return 'That username or record already exists.';
    if (e.code == '23514')
      return 'Check the text length, username and photo path.';
    if (e.code == '42501')
      return 'Permission denied. Check your account and database policies.';
    return e.message;
  }
  if (e is StorageException) return e.message;
  if (e is TimeoutException)
    return 'Request timed out. Check your PC and Wi-Fi.';
  final text = e.toString();
  if (text.contains('SocketException') || text.contains('ClientException')) {
    return 'Cannot reach Supabase. Check Docker, your PC address and Wi-Fi.';
  }
  return text.replaceFirst('Exception: ', '');
}

void notify(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _subscription;
  bool _recovering = false;
  @override
  void initState() {
    super.initState();
    _subscription = repo.client.auth.onAuthStateChange.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          if (event.event == AuthChangeEvent.passwordRecovery)
            _recovering = true;
        });
      },
      onError: (Object e) {
        if (mounted) notify(context, message(e));
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recovering)
      return RecoveryPage(onDone: () => setState(() => _recovering = false));
    if (repo.client.auth.currentSession == null) {
      return AuthPage(onRecover: () => setState(() => _recovering = true));
    }
    return ProfileGate(key: ValueKey(repo.uid));
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onRecover});
  final VoidCallback onRecover;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _code = TextEditingController();
  String _mode = 'Login', _status = '';
  bool _busy = false;
  DateTime? _sentAt;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _status = message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get email => _email.text.trim().toLowerCase();
  Future<void> _submit() => _run(() async {
    if (!email.contains('@')) throw Exception('Enter your email address.');
    if (_mode == 'Verify email') {
      await repo.client.auth.verifyOTP(
        email: email,
        token: _code.text.trim(),
        type: OtpType.email,
      );
    } else {
      if (_password.text.length < 10)
        throw Exception('Use at least 10 characters for your password.');
      if (_mode == 'Register') {
        await repo.client.auth.signUp(email: email, password: _password.text);
        if (mounted)
          setState(() {
            _mode = 'Verify email';
            _status = 'Open Mailpit on your PC and enter the code.';
            _sentAt = DateTime.now();
          });
      } else {
        await repo.client.auth.signInWithPassword(
          email: email,
          password: _password.text,
        );
      }
    }
  });
  Future<void> _resend() => _run(() async {
    if (_sentAt != null && DateTime.now().difference(_sentAt!).inSeconds < 60) {
      throw Exception('Wait 60 seconds before requesting another code.');
    }
    await repo.client.auth.resend(type: OtpType.signup, email: email);
    _sentAt = DateTime.now();
    if (mounted) setState(() => _status = 'Check Mailpit for a new code.');
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              const Icon(
                Icons.flutter_dash,
                size: 80,
                color: Color(0xff087f83),
              ),
              Text(
                'Chripy',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Small thoughts. Real conversations.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 8,
                children: ['Login', 'Register', 'Verify email']
                    .map(
                      (mode) => ChoiceChip(
                        label: Text(mode),
                        selected: _mode == mode,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                _mode = mode;
                                _status = '';
                              }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              if (_mode == 'Verify email')
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Code from Mailpit',
                  ),
                )
              else
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (10+ characters)',
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Please wait…' : _mode),
              ),
              if (_mode == 'Verify email')
                TextButton(
                  onPressed: _busy ? null : _resend,
                  child: const Text('Resend code'),
                ),
              TextButton(
                onPressed: _busy ? null : widget.onRecover,
                child: const Text('Forgot password?'),
              ),
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_status),
                ),
              const SizedBox(height: 24),
              const Text(
                'Local learning app • Keep your PC and Docker running.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final _email = TextEditingController(),
      _code = TextEditingController(),
      _password = TextEditingController();
  bool _busy = false, _verified = false;
  String _status = '';
  DateTime? _sentAt;
  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _status = message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
    if (_sentAt != null && DateTime.now().difference(_sentAt!).inSeconds < 60)
      throw Exception('Wait 60 seconds before resending.');
    await repo.client.auth.resetPasswordForEmail(
      _email.text.trim().toLowerCase(),
    );
    _sentAt = DateTime.now();
    if (mounted)
      setState(
        () => _status = 'If the account exists, a recovery code is in Mailpit.',
      );
  });
  Future<void> _reset() => _run(() async {
    if (_password.text.length < 10)
      throw Exception('Use at least 10 characters.');
    if (!_verified) {
      await repo.client.auth.verifyOTP(
        email: _email.text.trim().toLowerCase(),
        token: _code.text.trim(),
        type: OtpType.recovery,
      );
      _verified = true;
    }
    await repo.client.auth.updateUser(UserAttributes(password: _password.text));
    await repo.client.auth.signOut();
    if (mounted) {
      notify(context, 'Password changed. Log in with your new password.');
      widget.onDone();
    }
  });
  Future<void> _cancel() => _run(() async {
    if (repo.client.auth.currentSession != null)
      await repo.client.auth.signOut();
    if (mounted) widget.onDone();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Request a code, read it in Mailpit on your PC, then enter it here.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              enabled: !_verified,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextButton(
              onPressed: _busy || _verified ? null : _send,
              child: const Text('Send recovery code'),
            ),
            TextField(
              controller: _code,
              enabled: !_verified,
              decoration: const InputDecoration(labelText: 'Recovery code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _reset,
              child: Text(_busy ? 'Please wait…' : 'Set new password'),
            ),
            TextButton(
              onPressed: _busy ? null : _cancel,
              child: const Text('Back to login'),
            ),
            Text(_status),
          ],
        ),
      ),
    ),
  );
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<db.DataRow?> _profile;
  @override
  void initState() {
    super.initState();
    _profile = repo.profile(repo.uid);
  }

  void reload() => setState(() => _profile = repo.profile(repo.uid));
  @override
  Widget build(BuildContext context) => FutureBuilder<db.DataRow?>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.hasError)
        return Scaffold(
          appBar: AppBar(title: const Text('Chripy')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message(snapshot.error!)),
                TextButton(onPressed: reload, child: const Text('Retry')),
                TextButton(
                  onPressed: () async {
                    try {
                      await repo.client.auth.signOut();
                    } catch (e) {
                      if (context.mounted) notify(context, message(e));
                    }
                  },
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        );
      if (snapshot.data == null) return ProfileEditor(onSaved: reload);
      return const Timeline();
    },
  );
}

class Avatar extends StatefulWidget {
  const Avatar({super.key, this.path});
  final String? path;
  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  Future<Uint8List>? _photo;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _photo = widget.path == null ? null : repo.avatar(widget.path!);
  }

  @override
  void didUpdateWidget(Avatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _photo,
    builder: (context, snapshot) => CircleAvatar(
      backgroundColor: const Color(0xffd5efea),
      backgroundImage: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
      child: snapshot.hasData ? null : const Icon(Icons.person_outline),
    ),
  );
}

String when(String date) {
  final value = DateTime.parse(date).toLocal();
  return '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class Timeline extends StatefulWidget {
  const Timeline({super.key, this.author});
  final String? author;
  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  final List<db.DataRow> _rows = [];
  db.DataRow? _profile;
  bool _busy = false, _more = true, _writing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = widget.author == null
          ? null
          : await repo.profile(widget.author!);
      final rows = await repo.posts(
        author: widget.author,
        cursor: next && _rows.isNotEmpty ? _rows.last : null,
      );
      if (!mounted) return;
      setState(() {
        if (!next) _rows.clear();
        _rows.addAll(rows);
        _more = rows.length == 20;
        _profile = profile;
      });
    } catch (e) {
      if (mounted) setState(() => _error = message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openProfile(String id) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => Timeline(author: id)));
    if (mounted) await _load();
  }

  Future<void> _compose() async {
    if (_writing) return;
    setState(() => _writing = true);
    try {
      final text = await editText(context, 'New chirp');
      if (!mounted || text == null) return;
      try {
        await repo.writePost(text);
        if (mounted) await _load();
      } catch (e) {
        if (mounted) notify(context, message(e));
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfileEditor(profile: _profile)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.author == null ? 'Chripy' : 'Profile'),
      actions: [
        if (widget.author == null)
          IconButton(
            tooltip: 'My profile',
            onPressed: () {
              final id = repo.currentUid;
              if (id != null) _openProfile(id);
            },
            icon: const Icon(Icons.account_circle_outlined),
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
        if (widget.author == null)
          IconButton(
            tooltip: 'Log out',
            onPressed: () async {
              try {
                await repo.client.auth.signOut();
              } catch (e) {
                if (context.mounted) notify(context, message(e));
              }
            },
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    floatingActionButton: widget.author == null
        ? FloatingActionButton.extended(
            onPressed: _writing ? null : _compose,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Chirp'),
          )
        : null,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: RefreshIndicator(
          onRefresh: () => _load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              if (_profile != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Avatar(path: _profile!['avatar_path']),
                        const SizedBox(height: 12),
                        Text(
                          _profile!['display_name'],
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text('@${_profile!['username']}'),
                        const SizedBox(height: 8),
                        Text(_profile!['bio']),
                        if (widget.author == repo.currentUid)
                          TextButton.icon(
                            onPressed: _editProfile,
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit profile'),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (!_busy && _rows.isEmpty && _error == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No chirps yet. Start a conversation.'),
                ),
              ..._rows.map(
                (row) => PostCard(
                  key: ValueKey(row['id']),
                  row: row,
                  onChanged: () => _load(),
                  onProfile: _openProfile,
                ),
              ),
              if (_more && _rows.isNotEmpty)
                TextButton(
                  onPressed: _busy ? null : () => _load(next: true),
                  child: const Text('Load more'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<String?> editText(
  BuildContext context,
  String title, {
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => ComposeDialog(title: title, initial: initial),
);

class ComposeDialog extends StatefulWidget {
  const ComposeDialog({super.key, required this.title, required this.initial});
  final String title, initial;
  @override
  State<ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<ComposeDialog> {
  late final TextEditingController _text;
  String? _error;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _text,
      autofocus: true,
      minLines: 3,
      maxLines: 7,
      maxLength: 280,
      decoration: InputDecoration(
        hintText: 'What is on your mind?',
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final error = validatePost(_text.text);
          if (error != null) {
            setState(() => _error = error);
            return;
          }
          Navigator.pop(context, _text.text.trim());
        },
        child: const Text('Save'),
      ),
    ],
  );
}

Future<bool> confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.row,
    required this.onChanged,
    required this.onProfile,
    this.openable = true,
  });
  final db.DataRow row;
  final Future<void> Function() onChanged;
  final Future<void> Function(String) onProfile;
  final bool openable;
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _busy = false;
  Future<void> _action(Future<void> Function() action) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await widget.onChanged();
    } catch (e) {
      if (mounted) notify(context, message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _menu(String action) async {
    if (!mounted) return;
    if (action == 'edit') {
      final text = await editText(
        context,
        'Edit chirp',
        initial: widget.row['body'],
      );
      if (text != null)
        await _action(() => repo.writePost(text, id: widget.row['id']));
    } else if (await confirmDelete(context)) {
      await _action(() => repo.deletePost(widget.row['id']));
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PostPage(id: widget.row['id'])),
    );
    if (mounted) await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.row;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(path: p['avatar_path']),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onProfile(p['author_id']),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['display_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('@${p['username']}'),
                      ],
                    ),
                  ),
                ),
                if (p['author_id'] == repo.currentUid && widget.openable)
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: _menu,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(p['body']),
            const SizedBox(height: 10),
            Text(
              when(p['created_at']),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _action(
                          () => repo.setLike(p['id'], p['liked'] != true),
                        ),
                  icon: Icon(
                    p['liked'] == true ? Icons.favorite : Icons.favorite_border,
                  ),
                  label: Text('${p['like_count']}'),
                ),
                TextButton.icon(
                  onPressed: widget.openable ? _open : null,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text('${p['comment_count']} comments'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PostPage extends StatefulWidget {
  const PostPage({super.key, required this.id});
  final String id;
  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  db.DataRow? _post;
  final List<db.DataRow> _comments = [];
  bool _busy = false, _more = true, _writing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await repo.post(widget.id);
      final comments = await repo.comments(
        widget.id,
        cursor: next && _comments.isNotEmpty ? _comments.last : null,
      );
      if (!mounted) return;
      setState(() {
        _post = p;
        if (!next) _comments.clear();
        _comments.addAll(comments);
        _more = comments.length == 20;
      });
    } catch (e) {
      if (mounted) setState(() => _error = message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _profile(String id) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => Timeline(author: id)));
    if (mounted) await _load();
  }

  Future<void> _comment() async {
    if (_writing) return;
    setState(() => _writing = true);
    try {
      final text = await editText(context, 'Reply');
      if (!mounted || text == null) return;
      try {
        await repo.comment(widget.id, text);
        if (mounted) await _load();
      } catch (e) {
        if (mounted) notify(context, message(e));
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context) || !mounted) return;
    try {
      await repo.deleteComment(id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) notify(context, message(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Conversation'),
      actions: [
        IconButton(
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: _post == null
        ? null
        : FloatingActionButton.extended(
            onPressed: _writing ? null : _comment,
            label: const Text('Reply'),
            icon: const Icon(Icons.reply),
          ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text('Post unavailable or connection failed: $_error'),
            if (_post != null)
              PostCard(
                row: _post!,
                onChanged: () => _load(),
                onProfile: _profile,
                openable: false,
              ),
            if (!_busy && _comments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No replies yet.'),
              ),
            ..._comments.map(
              (c) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(path: c['avatar_path']),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _profile(c['author_id']),
                              child: Text('@${c['username']}'),
                            ),
                          ),
                          if (c['author_id'] == repo.currentUid)
                            IconButton(
                              onPressed: () => _delete(c['id']),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                      Text(c['body']),
                      const SizedBox(height: 8),
                      Text(
                        when(c['created_at']),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_more && _comments.isNotEmpty)
              TextButton(
                onPressed: _busy ? null : () => _load(next: true),
                child: const Text('Load more replies'),
              ),
          ],
        ),
      ),
    ),
  );
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, this.profile, this.onSaved});
  final db.DataRow? profile;
  final VoidCallback? onSaved;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final TextEditingController _username, _name, _bio;
  String? _avatar;
  bool _busy = false;
  String _status = '';
  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.profile?['username'] ?? '');
    _name = TextEditingController(text: widget.profile?['display_name'] ?? '');
    _bio = TextEditingController(text: widget.profile?['bio'] ?? '');
    _avatar = widget.profile?['avatar_path'];
  }

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _status = message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final error =
        validateUsername(_username.text) ??
        validateDisplayName(_name.text) ??
        validateBio(_bio.text);
    if (error != null) throw Exception(error);
    await repo.saveProfile({
      'username': _username.text.trim(),
      'display_name': _name.text.trim(),
      'bio': _bio.text.trim(),
    }, create: widget.profile == null);
    if (!mounted) return;
    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.pop(context);
    }
  });
  Future<void> _photo({bool remove = false}) => _run(() async {
    String? warning;
    if (remove) {
      warning = await repo.removeAvatar(_avatar);
    } else {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (!mounted || file == null) return;
      warning = await repo.replaceAvatar(file, _avatar);
    }
    final updated = await repo.profile(repo.uid);
    if (mounted)
      setState(() {
        _avatar = updated?['avatar_path'];
        _status = warning ?? 'Profile photo saved.';
      });
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.profile == null ? 'Create your profile' : 'Edit profile',
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Avatar(path: _avatar),
            const SizedBox(height: 12),
            if (widget.profile != null)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _photo(),
                    child: const Text('Choose photo'),
                  ),
                  if (_avatar != null)
                    TextButton(
                      onPressed: _busy ? null : () => _photo(remove: true),
                      child: const Text('Remove photo'),
                    ),
                ],
              )
            else
              const Text(
                'Save your profile first; then add a photo from Edit profile.',
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              maxLength: 24,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 50,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLength: 160,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save profile'),
            ),
            Text(_status),
            if (widget.profile == null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await repo.client.auth.signOut();
                      }),
                child: const Text('Log out'),
              ),
          ],
        ),
      ),
    ),
  );
}
