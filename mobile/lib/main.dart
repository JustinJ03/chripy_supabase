// Import Future, timeout errors, and subscriptions for asynchronous work.
import 'dart:async';
// Import platform detection and Flutter foundation types, including Uint8List.
import 'package:flutter/foundation.dart';
// Import Material widgets, themes, navigation, and layout widgets such as Row.
import 'package:flutter/material.dart';
// Import the photo-library picker and its XFile result type.
import 'package:image_picker/image_picker.dart';
// Import Supabase initialization, authentication, database, and storage APIs.
import 'package:supabase_flutter/supabase_flutter.dart';
// Import database types under db so db.DataRow cannot collide with Material DataRow.
import 'repository.dart' as db;
// Import the secure native-session adapter passed to Supabase Auth.
import 'session_store.dart';
// Import shared input checks that match the database character limits.
import 'validation.dart';

// Create a lightweight repository wrapper around the initialized Supabase singleton.
db.Repository get repo => db.Repository(Supabase.instance.client);

// Initialize the backend before attaching the Flutter application.
Future<void> main() async {
  // Initialize Flutter before plugins and asynchronous app startup are used.
  WidgetsFlutterBinding.ensureInitialized();
  // Read the backend URL compiled from the dart-define configuration file.
  const url = String.fromEnvironment('SUPABASE_URL');
  // Read the compiled client key from the same configuration file.
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  // Hold a startup error, or null when initialization succeeds.
  String? problem;
  // Show setup help when either required build-time setting is missing.
  if (url.isEmpty || key.isEmpty) {
    // Store the user-facing startup failure to display instead of the login screen.
    problem =
        // Supply this literal message, label, or formatted value to the surrounding expression.
        'Missing Supabase settings. Follow README.md and run with '
        // Supply this literal message, label, or formatted value to the surrounding expression.
        '--dart-define-from-file=config.local.json.';
    // Use the alternative branch when the preceding condition did not match.
  } else {
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Initialize the SDK with these server/auth options before any client access.
      await Supabase.initialize(
        // Use this Supabase server address; the phone build must use a reachable LAN address.
        url: url,
        // Pass a client publishable/anon key; privileged server keys never belong here.
        publishableKey: key,
        // Configure session storage and authentication behavior.
        authOptions: FlutterAuthClientOptions(
          // Web preview deliberately does not retain credentials after reload.
          // Choose the session persistence adapter for this platform or test.
          localStorage: kIsWeb
              // Use an empty session store so a full browser reload does not retain login state.
              ? const EmptyLocalStorage()
              // Use secure storage with a URL-specific session key on native platforms.
              : SessionStore('chripy.session.$url'),
        ),
      );
      // Catch the failure and translate it into feedback for this operation.
    } catch (_) {
      // Store the user-facing startup failure to display instead of the login screen.
      problem =
          // Supply this literal message, label, or formatted value to the surrounding expression.
          'Could not initialize Supabase. Check your configuration and restart.';
    }
  }
  // Attach the app to Flutter after deciding whether startup succeeded.
  runApp(ChripyApp(problem: problem));
}

// The root widget supplies the app theme and chooses setup help or authentication.
class ChripyApp extends StatelessWidget {
  // Construct this ChripyApp and accept its immutable inputs/callbacks.
  const ChripyApp({super.key, this.problem});
  // Store this widget's immutable identifier, optional path, or startup message.
  final String? problem;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) => MaterialApp(
    // Set the screen, dialog, or application title.
    title: 'Chripy',
    // Hide Flutter's debug banner in the preview.
    debugShowCheckedModeBanner: false,
    // Define the visual defaults inherited by all app screens.
    theme: ThemeData(
      // Use Material 3 component styling.
      useMaterial3: true,
      // Generate matching theme colors from Chripy's teal seed.
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f83)),
      // Use the pale app background behind screen content.
      scaffoldBackgroundColor: const Color(0xfff7faf9),
      // Apply a shared appearance to form inputs.
      inputDecorationTheme: const InputDecorationTheme(
        // Draw an outline around the input.
        border: OutlineInputBorder(),
      ),
    ),
    // Choose the first screen displayed by this MaterialApp.
    home: problem == null
        // Continue into authentication when startup completed without a problem.
        ? const AuthGate()
        // Choose this value for the corresponding true/false branch of the condition above.
        : Scaffold(
            // Build the screen's top navigation and action bar.
            appBar: AppBar(title: const Text('Chripy setup')),
            // Supply the main screen content below the app bar.
            body: Padding(
              // Reserve space around the nested content.
              padding: const EdgeInsets.all(24),
              // Supply the single widget or expression displayed inside this parent.
              child: Text(problem!),
            ),
          ),
  );
}

// Translate SDK and network failures into messages suitable for the UI.
String message(Object e) {
  // Preserve the authentication SDK's user-facing error message.
  if (e is AuthException) return e.message;
  // Handle structured database errors returned through PostgREST.
  if (e is PostgrestException) {
    // Translate PostgreSQL's uniqueness violation into a readable duplicate-record message.
    if (e.code == '23505') return 'That username or record already exists.';
    // Recognize a database CHECK constraint failure.
    if (e.code == '23514')
      // Return this result/message to the caller instead of continuing the operation.
      return 'Check the text length, username and photo path.';
    // Recognize a database permissions failure.
    if (e.code == '42501')
      // Return this result/message to the caller instead of continuing the operation.
      return 'Permission denied. Check your account and database policies.';
    // Use the SDK message when no more specific translation applies.
    return e.message;
  }
  // Preserve storage API feedback for avatar failures.
  if (e is StorageException) return e.message;
  // Handle an asynchronous timeout separately from other errors.
  if (e is TimeoutException)
    // Return this result/message to the caller instead of continuing the operation.
    return 'Request timed out. Check your PC and Wi-Fi.';
  // Convert other error types to text for the fallback message.
  final text = e.toString();
  // Recognize common native/browser HTTP connection failures.
  if (text.contains('SocketException') || text.contains('ClientException')) {
    // Return this result/message to the caller instead of continuing the operation.
    return 'Cannot reach Supabase. Check Docker, your PC address and Wi-Fi.';
  }
  // Remove the generic exception prefix from the fallback message.
  return text.replaceFirst('Exception: ', '');
}

// Show a brief feedback message using the nearest ScaffoldMessenger.
void notify(BuildContext context, String text) =>
    // Place the message in a SnackBar associated with the active scaffold.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

// Choose the login, recovery, or signed-in flow as the session changes.
class AuthGate extends StatefulWidget {
  // Construct this AuthGate and accept its immutable inputs/callbacks.
  const AuthGate({super.key});
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<AuthGate> createState() => _AuthGateState();
}

// Track authentication events and keep password recovery visible until it finishes.
class _AuthGateState extends State<AuthGate> {
  // Retain the auth listener so it can be canceled when the gate is disposed.
  StreamSubscription<AuthState>? _subscription;
  // Remember whether the recovery screen must remain active.
  bool _recovering = false;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Initialize state once when Flutter inserts this widget into the tree.
  void initState() {
    // Run the parent State initialization before starting this widget's work.
    super.initState();
    // Listen for sign-in, sign-out, recovery, and session updates.
    _subscription = repo.client.auth.onAuthStateChange.listen(
      // Handle the next auth event and rebuild the gate as needed.
      (event) {
        // Stop if this State has already been removed from the widget tree.
        if (!mounted) return;
        // Update local state and ask Flutter to rebuild this widget.
        setState(() {
          // Recognize that verification created a password-recovery session.
          if (event.event == AuthChangeEvent.passwordRecovery)
            // Keep recovery visible instead of immediately opening the signed-in feed.
            _recovering = true;
        });
      },
      // Handle auth-stream errors instead of letting them escape asynchronously.
      onError: (Object e) {
        // Show the translated error only if this screen is still present.
        if (mounted) notify(context, message(e));
      },
    );
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Release controllers and listeners when Flutter removes this State permanently.
  void dispose() {
    // Stop auth notifications before the gate's State is destroyed.
    _subscription?.cancel();
    // Complete the parent State cleanup after releasing owned resources.
    super.dispose();
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) {
    // Give the recovery flow priority over ordinary login routing.
    if (_recovering)
      // Leave recovery only when its success/cancel callback completes.
      return RecoveryPage(onDone: () => setState(() => _recovering = false));
    // Show authentication when no user session is available.
    if (repo.client.auth.currentSession == null) {
      // Open the auth form and wire its Forgot password action to recovery.
      return AuthPage(onRecover: () => setState(() => _recovering = true));
    }
    // Load a fresh profile gate for each signed-in user ID.
    return ProfileGate(key: ValueKey(repo.uid));
  }
}

// Present the login, registration, and email-code verification forms.
class AuthPage extends StatefulWidget {
  // Construct this AuthPage and accept its immutable inputs/callbacks.
  const AuthPage({super.key, required this.onRecover});
  // Keep the parent callback used to finish or switch this flow.
  final VoidCallback onRecover;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<AuthPage> createState() => _AuthPageState();
}

// Own auth-form input, request progress, status messages, and resend timing.
class _AuthPageState extends State<AuthPage> {
  // Own the text entered in this field so handlers can read it and dispose it later.
  final _email = TextEditingController(),
          // Own the text entered in this field so handlers can read it and dispose it later.
          _password =
          TextEditingController(),
          // Own the text entered in this field so handlers can read it and dispose it later.
          _code =
          TextEditingController();
  // Start in login mode with no feedback message.
  String _mode = 'Login', _status = '';
  // Track whether an asynchronous operation should disable repeated actions.
  bool _busy = false;
  // Remember the last code-request time for the resend cooldown.
  DateTime? _sentAt;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Release controllers and listeners when Flutter removes this State permanently.
  void dispose() {
    // Release this text controller and its listeners to avoid retaining the closed form.
    _email.dispose();
    // Release this text controller and its listeners to avoid retaining the closed form.
    _password.dispose();
    // Release this text controller and its listeners to avoid retaining the closed form.
    _code.dispose();
    // Complete the parent State cleanup after releasing owned resources.
    super.dispose();
  }

  // Run a form operation with busy-state handling and a readable error message.
  Future<void> _run(Future<void> Function() action) async {
    // Update local state and ask Flutter to rebuild this widget.
    setState(() {
      // Mark the request as running before waiting on it.
      _busy = true;
      // Clear the previous form feedback before another attempt.
      _status = '';
    });
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Wait for the caller-provided operation so its failures reach this handler.
      await action();
      // Catch the failure and translate it into feedback for this operation.
    } catch (e) {
      // Store a readable request error only while the form is still mounted.
      if (mounted) setState(() => _status = message(e));
      // Always release the busy state or temporary resources, even after an error or early return.
    } finally {
      // Re-enable controls after success or failure if the screen still exists.
      if (mounted) setState(() => _busy = false);
    }
  }

  // Normalize email input without modifying the password.
  String get email => _email.text.trim().toLowerCase();
  // Submit the selected login, signup, or verification operation.
  Future<void> _submit() => _run(() async {
    // Reject an obviously incomplete email before sending an auth request.
    if (!email.contains('@')) throw Exception('Enter your email address.');
    // Verify a signup code instead of submitting a password.
    if (_mode == 'Verify email') {
      // Exchange the entered one-time email code for the appropriate auth session.
      await repo.client.auth.verifyOTP(
        // Send the normalized address for this authentication operation.
        email: email,
        // Read the one-time code entered by the user.
        token: _code.text.trim(),
        // Select the verification flow so recovery and signup codes are handled correctly.
        type: OtpType.email,
      );
      // Use the alternative branch when the preceding condition did not match.
    } else {
      // Enforce the configured minimum password length before the API call.
      if (_password.text.length < 10)
        // Stop the operation and pass this readable validation failure to the surrounding handler.
        throw Exception('Use at least 10 characters for your password.');
      // Create an account when registration is selected.
      if (_mode == 'Register') {
        // Ask Supabase Auth to create the account and send its confirmation email.
        await repo.client.auth.signUp(email: email, password: _password.text);
        // Only touch widget state or its context while this screen still exists.
        if (mounted)
          // Update local state and ask Flutter to rebuild this widget.
          setState(() {
            // Switch the form to code entry after signup.
            _mode = 'Verify email';
            // Explain where the locally captured confirmation email can be read.
            _status = 'Open Mailpit on your PC and enter the code.';
            // Start the local resend cooldown from the successful request time.
            _sentAt = DateTime.now();
          });
        // Use the alternative branch when the preceding condition did not match.
      } else {
        // Ask Supabase Auth to verify the credentials and establish a session.
        await repo.client.auth.signInWithPassword(
          // Send the normalized address for this authentication operation.
          email: email,
          // Send the entered password to Supabase Auth for verification.
          password: _password.text,
        );
      }
    }
  });
  // Request another signup code while enforcing the local resend cooldown.
  Future<void> _resend() => _run(() async {
    // Block another email request until the one-minute cooldown has elapsed.
    if (_sentAt != null && DateTime.now().difference(_sentAt!).inSeconds < 60) {
      // Stop the operation and pass this readable validation failure to the surrounding handler.
      throw Exception('Wait 60 seconds before requesting another code.');
    }
    // Resend signup confirmation using the signup resend type.
    await repo.client.auth.resend(type: OtpType.signup, email: email);
    // Start the local resend cooldown from the successful request time.
    _sentAt = DateTime.now();
    // Confirm the resend without touching a disposed form.
    if (mounted) setState(() => _status = 'Check Mailpit for a new code.');
  });
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) => Scaffold(
    // Supply the main screen content below the app bar.
    body: SafeArea(
      // Supply the single widget or expression displayed inside this parent.
      child: Center(
        // Supply the single widget or expression displayed inside this parent.
        child: ConstrainedBox(
          // Limit content width to keep forms and feeds readable on wide screens.
          constraints: const BoxConstraints(maxWidth: 460),
          // Supply the single widget or expression displayed inside this parent.
          child: ListView(
            // Size the scrolling list to its content within the centered form.
            shrinkWrap: true,
            // Reserve space around the nested content.
            padding: const EdgeInsets.all(28),
            // List the widgets displayed by this layout, in order.
            children: [
              // Draw the selected Material icon.
              const Icon(
                // Choose Flutter's built-in bird icon for the Chripy login header.
                Icons.flutter_dash,
                // Set the icon's display size in logical pixels.
                size: 80,
                // Apply the specified color to this element.
                color: Color(0xff087f83),
              ),
              // Display this label, instruction, status, or record value.
              Text(
                // Supply this literal message, label, or formatted value to the surrounding expression.
                'Chripy',
                // Choose how text aligns inside its available width.
                textAlign: TextAlign.center,
                // Use the theme's typography or a local text-style override.
                style: Theme.of(context).textTheme.displaySmall,
              ),
              // Reserve a fixed amount of space between nearby elements.
              const SizedBox(height: 8),
              // Display this label, instruction, status, or record value.
              const Text(
                // Supply this literal message, label, or formatted value to the surrounding expression.
                'Small thoughts. Real conversations.',
                // Choose how text aligns inside its available width.
                textAlign: TextAlign.center,
              ),
              // Reserve a fixed amount of space between nearby elements.
              const SizedBox(height: 28),
              // Let controls flow onto another line on narrow screens.
              Wrap(
                // Leave horizontal space between wrapped controls.
                spacing: 8,
                // List the widgets displayed by this layout, in order.
                children: ['Login', 'Register', 'Verify email']
                    // Transform each source item into its corresponding widget.
                    .map(
                      // Build one selectable chip for each authentication mode.
                      (mode) => ChoiceChip(
                        // Provide the control's visible text.
                        label: Text(mode),
                        // Mark the chip for the currently selected auth mode.
                        selected: _mode == mode,
                        // Handle the selected chip or popup-menu action.
                        onSelected: _busy
                            // Use no widget/value or no error for this branch of the conditional expression.
                            ? null
                            // Apply the selected mode and clear prior feedback when the chip is enabled.
                            : (_) => setState(() {
                                // Remember the selected authentication mode for the next rebuild.
                                _mode = mode;
                                // Clear the previous form feedback before another attempt.
                                _status = '';
                              }),
                      ),
                    )
                    // Materialize the mapped widgets into the children list required by the layout.
                    .toList(),
              ),
              // Reserve a fixed amount of space between nearby elements.
              const SizedBox(height: 20),
              // Render an editable input connected to the controller below.
              TextField(
                // Connect this input to the controller that stores its text.
                controller: _email,
                // Request a keyboard suited to this input on mobile.
                keyboardType: TextInputType.emailAddress,
                // Disable autocorrection so email input is not changed automatically.
                autocorrect: false,
                // Supply the input's label, hint, border, or validation feedback.
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              // Reserve a fixed amount of space between nearby elements.
              const SizedBox(height: 12),
              // Show only the controls relevant to the current authentication mode.
              if (_mode == 'Verify email')
                // Render an editable input connected to the controller below.
                TextField(
                  // Connect this input to the controller that stores its text.
                  controller: _code,
                  // Request a keyboard suited to this input on mobile.
                  keyboardType: TextInputType.number,
                  // Supply the input's label, hint, border, or validation feedback.
                  decoration: const InputDecoration(
                    // Show this label next to the corresponding form field.
                    labelText: 'Code from Mailpit',
                  ),
                )
              // Use the alternative branch when the preceding condition did not match.
              else
                // Render an editable input connected to the controller below.
                TextField(
                  // Connect this input to the controller that stores its text.
                  controller: _password,
                  // Mask the password instead of displaying its characters.
                  obscureText: true,
                  // Supply the input's label, hint, border, or validation feedback.
                  decoration: const InputDecoration(
                    // Show this label next to the corresponding form field.
                    labelText: 'Password (10+ characters)',
                  ),
                ),
              // Reserve a fixed amount of space between nearby elements.
              const SizedBox(height: 16),
              // Render the primary action with a filled Material button.
              FilledButton(
                // Connect this button to its action; null disables it while appropriate.
                onPressed: _busy ? null : _submit,
                // Supply the single widget or expression displayed inside this parent.
                child: Text(_busy ? 'Please wait…' : _mode),
              ),
              // Show only the controls relevant to the current authentication mode.
              if (_mode == 'Verify email')
                // Render a secondary action as a text button.
                TextButton(
                  // Connect this button to its action; null disables it while appropriate.
                  onPressed: _busy ? null : _resend,
                  // Supply the single widget or expression displayed inside this parent.
                  child: const Text('Resend code'),
                ),
              // Render a secondary action as a text button.
              TextButton(
                // Connect this button to its action; null disables it while appropriate.
                onPressed: _busy ? null : widget.onRecover,
                // Supply the single widget or expression displayed inside this parent.
                child: const Text('Forgot password?'),
              ),
              // Reserve visible status space only when there is feedback to show.
              if (_status.isNotEmpty)
                // Add space around this group of content.
                Padding(
                  // Reserve space around the nested content.
                  padding: const EdgeInsets.only(top: 12),
                  // Supply the single widget or expression displayed inside this parent.
                  child: Text(_status),
                ),
              // Reserve a fixed amount of space between nearby elements.
              const SizedBox(height: 24),
              // Display this label, instruction, status, or record value.
              const Text(
                // Supply this literal message, label, or formatted value to the surrounding expression.
                'Local learning app • Keep your PC and Docker running.',
                // Choose how text aligns inside its available width.
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Present the email-code workflow for choosing a new password.
class RecoveryPage extends StatefulWidget {
  // Construct this RecoveryPage and accept its immutable inputs/callbacks.
  const RecoveryPage({super.key, required this.onDone});
  // Keep the parent callback used to finish or switch this flow.
  final VoidCallback onDone;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<RecoveryPage> createState() => _RecoveryPageState();
}

// Track recovery verification separately from saving the new password.
class _RecoveryPageState extends State<RecoveryPage> {
  // Own the text entered in this field so handlers can read it and dispose it later.
  final _email = TextEditingController(),
          // Own the text entered in this field so handlers can read it and dispose it later.
          _code =
          TextEditingController(),
          // Own the text entered in this field so handlers can read it and dispose it later.
          _password =
          TextEditingController();
  // Track request progress and whether recovery-code verification already succeeded.
  bool _busy = false, _verified = false;
  // Start with no status/error message beneath the form.
  String _status = '';
  // Remember the last code-request time for the resend cooldown.
  DateTime? _sentAt;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Release controllers and listeners when Flutter removes this State permanently.
  void dispose() {
    // Release this text controller and its listeners to avoid retaining the closed form.
    _email.dispose();
    // Release this text controller and its listeners to avoid retaining the closed form.
    _code.dispose();
    // Release this text controller and its listeners to avoid retaining the closed form.
    _password.dispose();
    // Complete the parent State cleanup after releasing owned resources.
    super.dispose();
  }

  // Run a form operation with busy-state handling and a readable error message.
  Future<void> _run(Future<void> Function() action) async {
    // Update local state and ask Flutter to rebuild this widget.
    setState(() {
      // Mark the request as running before waiting on it.
      _busy = true;
      // Clear the previous form feedback before another attempt.
      _status = '';
    });
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Wait for the caller-provided operation so its failures reach this handler.
      await action();
      // Catch the failure and translate it into feedback for this operation.
    } catch (e) {
      // Store a readable request error only while the form is still mounted.
      if (mounted) setState(() => _status = message(e));
      // Always release the busy state or temporary resources, even after an error or early return.
    } finally {
      // Re-enable controls after success or failure if the screen still exists.
      if (mounted) setState(() => _busy = false);
    }
  }

  // Request a recovery email without revealing whether an account exists.
  Future<void> _send() => _run(() async {
    // Apply the same one-minute cooldown to recovery-email requests.
    if (_sentAt != null && DateTime.now().difference(_sentAt!).inSeconds < 60)
      // Stop the operation and pass this readable validation failure to the surrounding handler.
      throw Exception('Wait 60 seconds before resending.');
    // Ask Auth to send a recovery code through the configured email template.
    await repo.client.auth.resetPasswordForEmail(
      // Normalize the recovery email before passing it to Supabase Auth.
      _email.text.trim().toLowerCase(),
    );
    // Start the local resend cooldown from the successful request time.
    _sentAt = DateTime.now();
    // Only touch widget state or its context while this screen still exists.
    if (mounted)
      // Notify Flutter about this state update so the displayed controls stay in sync.
      setState(
        // Set the explanatory recovery status during the state update.
        () => _status = 'If the account exists, a recovery code is in Mailpit.',
      );
  });
  // Verify recovery once, update the password, then sign out of the recovery session.
  Future<void> _reset() => _run(() async {
    // Enforce the configured minimum password length before the API call.
    if (_password.text.length < 10)
      // Stop the operation and pass this readable validation failure to the surrounding handler.
      throw Exception('Use at least 10 characters.');
    // Verify the recovery code only once, allowing password-update retries afterward.
    if (!_verified) {
      // Exchange the entered one-time email code for the appropriate auth session.
      await repo.client.auth.verifyOTP(
        // Send the normalized address for this authentication operation.
        email: _email.text.trim().toLowerCase(),
        // Read the one-time code entered by the user.
        token: _code.text.trim(),
        // Select the verification flow so recovery and signup codes are handled correctly.
        type: OtpType.recovery,
      );
      // Remember the established recovery session for a password-update retry.
      _verified = true;
    }
    // Update the password using the session established by recovery verification.
    await repo.client.auth.updateUser(UserAttributes(password: _password.text));
    // End the current auth session through Supabase.
    await repo.client.auth.signOut();
    // Only touch widget state or its context while this screen still exists.
    if (mounted) {
      // Confirm the password change and tell the user to sign in again.
      notify(context, 'Password changed. Log in with your new password.');
      // Notify the auth gate that this recovery flow has finished.
      widget.onDone();
    }
  });
  // Leave recovery and clear any session created while verifying its code.
  Future<void> _cancel() => _run(() async {
    // Sign out only when recovery has created or retained a session.
    if (repo.client.auth.currentSession != null)
      // End the current auth session through Supabase.
      await repo.client.auth.signOut();
    // Return to login only if the recovery screen still exists.
    if (mounted) widget.onDone();
  });
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) => Scaffold(
    // Build the screen's top navigation and action bar.
    appBar: AppBar(title: const Text('Reset password')),
    // Supply the main screen content below the app bar.
    body: Center(
      // Supply the single widget or expression displayed inside this parent.
      child: ConstrainedBox(
        // Limit content width to keep forms and feeds readable on wide screens.
        constraints: const BoxConstraints(maxWidth: 500),
        // Supply the single widget or expression displayed inside this parent.
        child: ListView(
          // Reserve space around the nested content.
          padding: const EdgeInsets.all(24),
          // List the widgets displayed by this layout, in order.
          children: [
            // Display this label, instruction, status, or record value.
            const Text(
              // Supply this literal message, label, or formatted value to the surrounding expression.
              'Request a code, read it in Mailpit on your PC, then enter it here.',
            ),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 16),
            // Render an editable input connected to the controller below.
            TextField(
              // Connect this input to the controller that stores its text.
              controller: _email,
              // Allow interaction only when the surrounding state permits it.
              enabled: !_verified,
              // Supply the input's label, hint, border, or validation feedback.
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            // Render a secondary action as a text button.
            TextButton(
              // Connect this button to its action; null disables it while appropriate.
              onPressed: _busy || _verified ? null : _send,
              // Supply the single widget or expression displayed inside this parent.
              child: const Text('Send recovery code'),
            ),
            // Render an editable input connected to the controller below.
            TextField(
              // Connect this input to the controller that stores its text.
              controller: _code,
              // Allow interaction only when the surrounding state permits it.
              enabled: !_verified,
              // Supply the input's label, hint, border, or validation feedback.
              decoration: const InputDecoration(labelText: 'Recovery code'),
            ),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 12),
            // Render an editable input connected to the controller below.
            TextField(
              // Connect this input to the controller that stores its text.
              controller: _password,
              // Mask the password instead of displaying its characters.
              obscureText: true,
              // Supply the input's label, hint, border, or validation feedback.
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 12),
            // Render the primary action with a filled Material button.
            FilledButton(
              // Connect this button to its action; null disables it while appropriate.
              onPressed: _busy ? null : _reset,
              // Supply the single widget or expression displayed inside this parent.
              child: Text(_busy ? 'Please wait…' : 'Set new password'),
            ),
            // Render a secondary action as a text button.
            TextButton(
              // Connect this button to its action; null disables it while appropriate.
              onPressed: _busy ? null : _cancel,
              // Supply the single widget or expression displayed inside this parent.
              child: const Text('Back to login'),
            ),
            // Display this label, instruction, status, or record value.
            Text(_status),
          ],
        ),
      ),
    ),
  );
}

// Load the signed-in profile before choosing onboarding or the timeline.
class ProfileGate extends StatefulWidget {
  // Construct this ProfileGate and accept its immutable inputs/callbacks.
  const ProfileGate({super.key});
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<ProfileGate> createState() => _ProfileGateState();
}

// Retain the profile Future so ordinary rebuilds do not restart the lookup.
class _ProfileGateState extends State<ProfileGate> {
  // Retain the one profile lookup Future used by the onboarding gate.
  late Future<db.DataRow?> _profile;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Initialize state once when Flutter inserts this widget into the tree.
  void initState() {
    // Run the parent State initialization before starting this widget's work.
    super.initState();
    // Start loading the signed-in user's profile once during gate initialization.
    _profile = repo.profile(repo.uid);
  }

  // Replace the profile Future and rebuild the gate to retry or complete onboarding.
  void reload() => setState(() => _profile = repo.profile(repo.uid));
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) => FutureBuilder<db.DataRow?>(
    // Listen to the retained asynchronous lookup without starting it again here.
    future: _profile,
    // Build widgets from the latest context and asynchronous or observable state.
    builder: (context, snapshot) {
      // Keep showing progress until the profile Future completes.
      if (snapshot.connectionState != ConnectionState.done)
        // Return this result/message to the caller instead of continuing the operation.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      // Offer retry and logout when loading the profile fails.
      if (snapshot.hasError)
        // Return this result/message to the caller instead of continuing the operation.
        return Scaffold(
          // Build the screen's top navigation and action bar.
          appBar: AppBar(title: const Text('Chripy')),
          // Supply the main screen content below the app bar.
          body: Center(
            // Supply the single widget or expression displayed inside this parent.
            child: Column(
              // Use only the vertical space needed by this column.
              mainAxisSize: MainAxisSize.min,
              // List the widgets displayed by this layout, in order.
              children: [
                // Display this label, instruction, status, or record value.
                Text(message(snapshot.error!)),
                // Render a secondary action as a text button.
                TextButton(onPressed: reload, child: const Text('Retry')),
                // Render a secondary action as a text button.
                TextButton(
                  // Connect this button to its action; null disables it while appropriate.
                  onPressed: () async {
                    // Catch failures from the asynchronous operation so the UI can report them.
                    try {
                      // End the current auth session through Supabase.
                      await repo.client.auth.signOut();
                      // Catch the failure and translate it into feedback for this operation.
                    } catch (e) {
                      // Show the failure only while this callback's widget context is still active.
                      if (context.mounted) notify(context, message(e));
                    }
                  },
                  // Supply the single widget or expression displayed inside this parent.
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        );
      // Open onboarding when no profile exists, and reload after its first save.
      if (snapshot.data == null) return ProfileEditor(onSaved: reload);
      // Open the shared feed after a profile has been found.
      return const Timeline();
    },
  );
}

// Display a private profile photo, falling back to a person icon.
class Avatar extends StatefulWidget {
  // Construct this Avatar and accept its immutable inputs/callbacks.
  const Avatar({super.key, this.path});
  // Store this widget's immutable identifier, optional path, or startup message.
  final String? path;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<Avatar> createState() => _AvatarState();
}

// Cache the download Future and replace it when the avatar path changes.
class _AvatarState extends State<Avatar> {
  // Keep the current download Future, or null when there is no avatar.
  Future<Uint8List>? _photo;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Initialize state once when Flutter inserts this widget into the tree.
  void initState() {
    // Run the parent State initialization before starting this widget's work.
    super.initState();
    // Start the initial data/photo lookup for this State.
    _load();
  }

  // Choose the avatar download Future for the current storage path.
  void _load() {
    // Download only when the profile supplies a private storage path.
    _photo = widget.path == null ? null : repo.avatar(widget.path!);
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Respond when Flutter reuses this State with an updated widget configuration.
  void didUpdateWidget(Avatar oldWidget) {
    // Let the parent lifecycle handle the widget-configuration update first.
    super.didUpdateWidget(oldWidget);
    // Replace the retained Future when a new photo path arrives from the parent.
    if (oldWidget.path != widget.path) _load();
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    // Listen to the retained asynchronous lookup without starting it again here.
    future: _photo,
    // Build widgets from the latest context and asynchronous or observable state.
    builder: (context, snapshot) => CircleAvatar(
      // Set the placeholder avatar's background color.
      backgroundColor: const Color(0xffd5efea),
      // Display downloaded bytes only when the avatar Future has data.
      backgroundImage: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
      // Supply the single widget or expression displayed inside this parent.
      child: snapshot.hasData ? null : const Icon(Icons.person_outline),
    ),
  );
}

// Format a server timestamp for display in the device's local timezone.
String when(String date) {
  // Parse the server timestamp and convert it to the device's local timezone.
  final value = DateTime.parse(date).toLocal();
  // Return this result/message to the caller instead of continuing the operation.
  return '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

// Show either the shared feed or one author's profile and posts.
class Timeline extends StatefulWidget {
  // Construct this Timeline and accept its immutable inputs/callbacks.
  const Timeline({super.key, this.author});
  // Store this widget's immutable identifier, optional path, or startup message.
  final String? author;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<Timeline> createState() => _TimelineState();
}

// Manage feed pagination, refresh, composition, and the optional profile header.
class _TimelineState extends State<Timeline> {
  // Retain the feed records already loaded for this screen.
  final List<db.DataRow> _rows = [];
  // Hold the profile header for an author-specific timeline.
  db.DataRow? _profile;
  // Track loading, possible next-page availability, and an open compose operation.
  bool _busy = false, _more = true, _writing = false;
  // Store a load error separately from the existing visible records.
  String? _error;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Initialize state once when Flutter inserts this widget into the tree.
  void initState() {
    // Run the parent State initialization before starting this widget's work.
    super.initState();
    // Start the initial data/photo lookup for this State.
    _load();
  }

  // Load the current feed/conversation page; next=true continues from the last record.
  Future<void> _load({bool next = false}) async {
    // Ignore an overlapping load while another request is still active.
    if (_busy) return;
    // Update local state and ask Flutter to rebuild this widget.
    setState(() {
      // Mark the request as running before waiting on it.
      _busy = true;
      // Clear the previous load failure before retrying.
      _error = null;
    });
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Only author-specific timelines need a profile header lookup.
      final profile = widget.author == null
          // Use no widget/value or no error for this branch of the conditional expression.
          ? null
          // Read the selected author's profile for that header.
          : await repo.profile(widget.author!);
      // Fetch the next or refreshed feed page from the repository.
      final rows = await repo.posts(
        // Limit the feed query to this author, or leave it shared when null.
        author: widget.author,
        // Continue after the last loaded record only when requesting the next page.
        cursor: next && _rows.isNotEmpty ? _rows.last : null,
      );
      // Stop if this State has already been removed from the widget tree.
      if (!mounted) return;
      // Update local state and ask Flutter to rebuild this widget.
      setState(() {
        // Replace existing feed content when refreshing the first page.
        if (!next) _rows.clear();
        // Append the retrieved page to the displayed feed records.
        _rows.addAll(rows);
        // Offer another page when this response filled the page size.
        _more = rows.length == 20;
        // Replace the optional profile header with the newly loaded record.
        _profile = profile;
      });
      // Catch the failure and translate it into feedback for this operation.
    } catch (e) {
      // Display the load failure while retaining any previously loaded content.
      if (mounted) setState(() => _error = message(e));
      // Always release the busy state or temporary resources, even after an error or early return.
    } finally {
      // Re-enable controls after success or failure if the screen still exists.
      if (mounted) setState(() => _busy = false);
    }
  }

  // Open an author's profile and refresh this feed after returning.
  Future<void> _openProfile(String id) async {
    // Push another screen and wait until navigation returns to this one.
    await Navigator.of(
      // Pass this screen's context to the navigator lookup.
      context,
      // Create the author-profile route on the navigator found above.
    ).push(MaterialPageRoute<void>(builder: (_) => Timeline(author: id)));
    // Reload data after the action/navigation only if this screen still exists.
    if (mounted) await _load();
  }

  // Open the composer and save a new post if the user submits it.
  Future<void> _compose() async {
    // Avoid opening a second composer while one is already active.
    if (_writing) return;
    // Disable repeated compose actions until this operation finishes.
    setState(() => _writing = true);
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Wait for a new-post draft or null when the dialog is canceled.
      final text = await editText(context, 'New chirp');
      // Stop after cancellation or if navigation removed the screen while editing.
      if (!mounted || text == null) return;
      // Catch failures from the asynchronous operation so the UI can report them.
      try {
        // Persist the validated draft as a new post owned by the signed-in user.
        await repo.writePost(text);
        // Reload data after the action/navigation only if this screen still exists.
        if (mounted) await _load();
        // Catch the failure and translate it into feedback for this operation.
      } catch (e) {
        // Show the translated error only if this screen is still present.
        if (mounted) notify(context, message(e));
      }
      // Always release the busy state or temporary resources, even after an error or early return.
    } finally {
      // Restore compose availability only while this State is still mounted.
      if (mounted) setState(() => _writing = false);
    }
  }

  // Open the editor with the loaded profile and refresh on return.
  Future<void> _editProfile() async {
    // Push another screen and wait until navigation returns to this one.
    await Navigator.of(context).push(
      // Build the destination route without expecting a returned value.
      MaterialPageRoute<void>(builder: (_) => ProfileEditor(profile: _profile)),
    );
    // Reload data after the action/navigation only if this screen still exists.
    if (mounted) await _load();
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) => Scaffold(
    // Build the screen's top navigation and action bar.
    appBar: AppBar(
      // Set the screen, dialog, or application title.
      title: Text(widget.author == null ? 'Chripy' : 'Profile'),
      // Place action buttons in the app bar or dialog footer.
      actions: [
        // Show this shared-feed action only outside author-specific timelines.
        if (widget.author == null)
          // Render an action using an icon and optional accessibility tooltip.
          IconButton(
            // Describe this icon button for accessibility and hover feedback.
            tooltip: 'My profile',
            // Connect this button to its action; null disables it while appropriate.
            onPressed: () {
              // Read a nullable user ID so a session ending cannot cause a null assertion.
              final id = repo.currentUid;
              // Navigate to My profile only while a user remains signed in.
              if (id != null) _openProfile(id);
            },
            // Choose the icon associated with this action.
            icon: const Icon(Icons.account_circle_outlined),
          ),
        // Render an action using an icon and optional accessibility tooltip.
        IconButton(
          // Describe this icon button for accessibility and hover feedback.
          tooltip: 'Refresh',
          // Connect this button to its action; null disables it while appropriate.
          onPressed: _busy ? null : () => _load(),
          // Choose the icon associated with this action.
          icon: const Icon(Icons.refresh),
        ),
        // Show this shared-feed action only outside author-specific timelines.
        if (widget.author == null)
          // Render an action using an icon and optional accessibility tooltip.
          IconButton(
            // Describe this icon button for accessibility and hover feedback.
            tooltip: 'Log out',
            // Connect this button to its action; null disables it while appropriate.
            onPressed: () async {
              // Catch failures from the asynchronous operation so the UI can report them.
              try {
                // End the current auth session through Supabase.
                await repo.client.auth.signOut();
                // Catch the failure and translate it into feedback for this operation.
              } catch (e) {
                // Show the failure only while this callback's widget context is still active.
                if (context.mounted) notify(context, message(e));
              }
            },
            // Choose the icon associated with this action.
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    // Choose whether this screen offers a prominent compose/reply action.
    floatingActionButton: widget.author == null
        // Choose this value for the corresponding true/false branch of the condition above.
        ? FloatingActionButton.extended(
            // Connect this button to its action; null disables it while appropriate.
            onPressed: _writing ? null : _compose,
            // Choose the icon associated with this action.
            icon: const Icon(Icons.edit_outlined),
            // Provide the control's visible text.
            label: const Text('Chirp'),
          )
        // Use no widget/value or no error for this branch of the conditional expression.
        : null,
    // Supply the main screen content below the app bar.
    body: Center(
      // Supply the single widget or expression displayed inside this parent.
      child: ConstrainedBox(
        // Limit content width to keep forms and feeds readable on wide screens.
        constraints: const BoxConstraints(maxWidth: 680),
        // Supply the single widget or expression displayed inside this parent.
        child: RefreshIndicator(
          // Reload the first page when the user pulls to refresh.
          onRefresh: () => _load(),
          // Supply the single widget or expression displayed inside this parent.
          child: ListView(
            // Allow pull-to-refresh even when the feed is shorter than the screen.
            physics: const AlwaysScrollableScrollPhysics(),
            // Reserve space around the nested content.
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            // List the widgets displayed by this layout, in order.
            children: [
              // Render the profile header only after its record has loaded.
              if (_profile != null)
                // Group one profile, post, or reply inside a Material card.
                Card(
                  // Supply the single widget or expression displayed inside this parent.
                  child: Padding(
                    // Reserve space around the nested content.
                    padding: const EdgeInsets.all(20),
                    // Supply the single widget or expression displayed inside this parent.
                    child: Column(
                      // Align the column's children to the leading edge.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // List the widgets displayed by this layout, in order.
                      children: [
                        // Load the author's private photo or display the default person icon.
                        Avatar(path: _profile!['avatar_path']),
                        // Reserve a fixed amount of space between nearby elements.
                        const SizedBox(height: 12),
                        // Display this label, instruction, status, or record value.
                        Text(
                          // Read this display value from the profile after checking that the record is present.
                          _profile!['display_name'],
                          // Use the theme's typography or a local text-style override.
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        // Display this label, instruction, status, or record value.
                        Text('@${_profile!['username']}'),
                        // Reserve a fixed amount of space between nearby elements.
                        const SizedBox(height: 8),
                        // Display this label, instruction, status, or record value.
                        Text(_profile!['bio']),
                        // Offer profile editing only when viewing the current user's own profile.
                        if (widget.author == repo.currentUid)
                          // Render a secondary action as a text button.
                          TextButton.icon(
                            // Connect this button to its action; null disables it while appropriate.
                            onPressed: _editProfile,
                            // Choose the icon associated with this action.
                            icon: const Icon(Icons.edit),
                            // Provide the control's visible text.
                            label: const Text('Edit profile'),
                          ),
                      ],
                    ),
                  ),
                ),
              // Render an error message only when the latest load failed.
              if (_error != null)
                // Add space around this group of content.
                Padding(
                  // Reserve space around the nested content.
                  padding: const EdgeInsets.all(12),
                  // Supply the single widget or expression displayed inside this parent.
                  child: Text(_error!),
                ),
              // Keep a compact progress indicator visible while data loads.
              if (_busy) const LinearProgressIndicator(),
              // Show the empty-feed message only after a successful empty response.
              if (!_busy && _rows.isEmpty && _error == null)
                // Add space around this group of content.
                const Padding(
                  // Reserve space around the nested content.
                  padding: EdgeInsets.all(32),
                  // Supply the single widget or expression displayed inside this parent.
                  child: Text('No chirps yet. Start a conversation.'),
                ),
              // Turn every loaded feed record into a keyed PostCard widget.
              ..._rows.map(
                // Build one card using this record and its parent callbacks.
                (row) => PostCard(
                  // Keep this widget's identity tied to its record instead of its list position.
                  key: ValueKey(row['id']),
                  // Pass the feed record to PostCard using its row parameter.
                  row: row,
                  // Refresh the surrounding feed or conversation after a mutation.
                  onChanged: () => _load(),
                  // Open the selected author's profile from the card.
                  onProfile: _openProfile,
                ),
              ),
              // Offer pagination only after at least one page may have more records.
              if (_more && _rows.isNotEmpty)
                // Render a secondary action as a text button.
                TextButton(
                  // Connect this button to its action; null disables it while appropriate.
                  onPressed: _busy ? null : () => _load(next: true),
                  // Supply the single widget or expression displayed inside this parent.
                  child: const Text('Load more'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Open the reusable composer; its Future returns submitted text or null on cancel.
Future<String?> editText(
  // Supply this parameter/value to the surrounding function or request.
  BuildContext context,
  // Supply this parameter/value to the surrounding function or request.
  String title, {
  // Use an empty draft unless the caller supplies text for editing.
  String initial = '',
  // Present a modal route whose return value is the submitted String.
}) => showDialog<String>(
  // Use this widget's location to find the navigator or inherited state.
  context: context,
  // Build widgets from the latest context and asynchronous or observable state.
  builder: (_) => ComposeDialog(title: title, initial: initial),
);

// Collect a new or edited post/reply and return validated, trimmed text.
class ComposeDialog extends StatefulWidget {
  // Construct this ComposeDialog and accept its immutable inputs/callbacks.
  const ComposeDialog({super.key, required this.title, required this.initial});
  // Store immutable display text and, for the composer, its initial draft.
  final String title, initial;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<ComposeDialog> createState() => _ComposeDialogState();
}

// Own the draft controller and the validation error shown inside the dialog.
class _ComposeDialogState extends State<ComposeDialog> {
  // Create the draft controller once, after the widget's initial text is available.
  late final TextEditingController _text;
  // Store a load error separately from the existing visible records.
  String? _error;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Initialize state once when Flutter inserts this widget into the tree.
  void initState() {
    // Run the parent State initialization before starting this widget's work.
    super.initState();
    // Start the composer with an empty draft or the existing post body.
    _text = TextEditingController(text: widget.initial);
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Release controllers and listeners when Flutter removes this State permanently.
  void dispose() {
    // Release this text controller and its listeners to avoid retaining the closed form.
    _text.dispose();
    // Complete the parent State cleanup after releasing owned resources.
    super.dispose();
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) => AlertDialog(
    // Set the screen, dialog, or application title.
    title: Text(widget.title),
    // Provide the main content inside this dialog.
    content: TextField(
      // Connect this input to the controller that stores its text.
      controller: _text,
      // Focus the draft field when the composer opens.
      autofocus: true,
      // Reserve a minimum number of visible lines for multiline input.
      minLines: 3,
      // Allow multiline input to expand only to this visible height.
      maxLines: 7,
      // Limit visible grapheme clusters; validators also check database code-point limits.
      maxLength: 280,
      // Supply the input's label, hint, border, or validation feedback.
      decoration: InputDecoration(
        // Show a prompt while the input is empty.
        hintText: 'What is on your mind?',
        // Display the validation message below this field, if one exists.
        errorText: _error,
      ),
    ),
    // Place action buttons in the app bar or dialog footer.
    actions: [
      // Render a secondary action as a text button.
      TextButton(
        // Connect this button to its action; null disables it while appropriate.
        onPressed: () => Navigator.pop(context),
        // Supply the single widget or expression displayed inside this parent.
        child: const Text('Cancel'),
      ),
      // Render the primary action with a filled Material button.
      FilledButton(
        // Connect this button to its action; null disables it while appropriate.
        onPressed: () {
          // Validate database code-point limits in addition to the visible input limit.
          final error = validatePost(_text.text);
          // Keep the composer open when the submitted draft is invalid.
          if (error != null) {
            // Expose the validation error underneath the draft field.
            setState(() => _error = error);
            // Stop this callback so the unsuccessful branch does not continue.
            return;
          }
          // Close the composer and return whitespace-trimmed text to its caller.
          Navigator.pop(context, _text.text.trim());
        },
        // Supply the single widget or expression displayed inside this parent.
        child: const Text('Save'),
      ),
    ],
  );
}

// Ask the user to confirm deletion and return a boolean decision.
Future<bool> confirmDelete(BuildContext context) async =>
    // Wait for the confirmation dialog to return true, false, or dismissal.
    await showDialog<bool>(
      // Use this widget's location to find the navigator or inherited state.
      context: context,
      // Build widgets from the latest context and asynchronous or observable state.
      builder: (context) => AlertDialog(
        // Set the screen, dialog, or application title.
        title: const Text('Delete this item?'),
        // Provide the main content inside this dialog.
        content: const Text('This cannot be undone.'),
        // Place action buttons in the app bar or dialog footer.
        actions: [
          // Render a secondary action as a text button.
          TextButton(
            // Connect this button to its action; null disables it while appropriate.
            onPressed: () => Navigator.pop(context, false),
            // Supply the single widget or expression displayed inside this parent.
            child: const Text('Cancel'),
          ),
          // Render the primary action with a filled Material button.
          FilledButton(
            // Connect this button to its action; null disables it while appropriate.
            onPressed: () => Navigator.pop(context, true),
            // Supply the single widget or expression displayed inside this parent.
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    // Treat dismissing the dialog without a result as a canceled deletion.
    false;

// Render one feed record with author information, likes, replies, and owner actions.
class PostCard extends StatefulWidget {
  // Construct this PostCard and accept its immutable inputs/callbacks.
  const PostCard({
    // Forward the optional widget identity key to the Flutter superclass.
    super.key,
    // Require this named input when the caller constructs the widget or invokes the adapter.
    required this.row,
    // Require this named input when the caller constructs the widget or invokes the adapter.
    required this.onChanged,
    // Require this named input when the caller constructs the widget or invokes the adapter.
    required this.onProfile,
    // Allow feed cards to open conversations unless the caller disables that behavior.
    this.openable = true,
  });
  // Keep the record supplied by the parent; db.DataRow is the map type, not a widget.
  final db.DataRow row;
  // Store the refresh callback invoked after a successful card change.
  final Future<void> Function() onChanged;
  // Store the callback that opens the profile for a selected user ID.
  final Future<void> Function(String) onProfile;
  // Remember whether this card may open its own conversation page.
  final bool openable;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<PostCard> createState() => _PostCardState();
}

// Coordinate post actions and stop delayed dialog callbacks after disposal.
class _PostCardState extends State<PostCard> {
  // Track whether an asynchronous operation should disable repeated actions.
  bool _busy = false;
  // Serialize card mutations and refresh the parent after a successful change.
  Future<void> _action(Future<void> Function() action) async {
    // Ignore delayed or repeated card actions after disposal or during another mutation.
    if (!mounted || _busy) return;
    // Disable repeat mutation taps while waiting for the card action.
    setState(() => _busy = true);
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Wait for the caller-provided operation so its failures reach this handler.
      await action();
      // Ask the parent to refresh only while this post card is still present.
      if (mounted) await widget.onChanged();
      // Catch the failure and translate it into feedback for this operation.
    } catch (e) {
      // Show the translated error only if this screen is still present.
      if (mounted) notify(context, message(e));
      // Always release the busy state or temporary resources, even after an error or early return.
    } finally {
      // Re-enable controls after success or failure if the screen still exists.
      if (mounted) setState(() => _busy = false);
    }
  }

  // Handle the owner's edit/delete selection, including its confirmation dialog.
  Future<void> _menu(String action) async {
    // Stop if this State has already been removed from the widget tree.
    if (!mounted) return;
    // Open the edit composer for an Edit selection.
    if (action == 'edit') {
      // Open the shared composer with this post's existing body for editing.
      final text = await editText(
        // Pass this screen's context to the navigator lookup.
        context,
        // Supply this literal message, label, or formatted value to the surrounding expression.
        'Edit chirp',
        // Prefill the editor with the existing body when editing a post.
        initial: widget.row['body'],
      );
      // Save only when the user submitted rather than canceled the edit dialog.
      if (text != null)
        // Update this post through the guarded mutation wrapper, then refresh its parent.
        await _action(() => repo.writePost(text, id: widget.row['id']));
      // Run deletion only after the user confirms the destructive action.
    } else if (await confirmDelete(context)) {
      // Delete this post only while its card remains mounted, then refresh the parent.
      await _action(() => repo.deletePost(widget.row['id']));
    }
  }

  // Open this post's conversation and refresh the parent after returning.
  Future<void> _open() async {
    // Push another screen and wait until navigation returns to this one.
    await Navigator.of(context).push(
      // Build the destination route without expecting a returned value.
      MaterialPageRoute<void>(builder: (_) => PostPage(id: widget.row['id'])),
    );
    // Ask the parent to refresh only while this post card is still present.
    if (mounted) await widget.onChanged();
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) {
    // Give the card's feed record a short local name for rendering.
    final p = widget.row;
    // Return this result/message to the caller instead of continuing the operation.
    return Card(
      // Supply the single widget or expression displayed inside this parent.
      child: Padding(
        // Reserve space around the nested content.
        padding: const EdgeInsets.all(16),
        // Supply the single widget or expression displayed inside this parent.
        child: Column(
          // Align the column's children to the leading edge.
          crossAxisAlignment: CrossAxisAlignment.start,
          // List the widgets displayed by this layout, in order.
          children: [
            // Lay out its children horizontally using Flutter Row, not a database record.
            Row(
              // List the widgets displayed by this layout, in order.
              children: [
                // Load the author's private photo or display the default person icon.
                Avatar(path: p['avatar_path']),
                // Reserve a fixed amount of space between nearby elements.
                const SizedBox(width: 10),
                // Give this child the remaining horizontal space to avoid crowding its neighbors.
                Expanded(
                  // Supply the single widget or expression displayed inside this parent.
                  child: InkWell(
                    // Ask the parent to open the profile belonging to this post's author.
                    onTap: () => widget.onProfile(p['author_id']),
                    // Supply the single widget or expression displayed inside this parent.
                    child: Column(
                      // Align the column's children to the leading edge.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // List the widgets displayed by this layout, in order.
                      children: [
                        // Display this label, instruction, status, or record value.
                        Text(
                          // Display the author's current display name from the feed view.
                          p['display_name'],
                          // Use the theme's typography or a local text-style override.
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        // Display this label, instruction, status, or record value.
                        Text('@${p['username']}'),
                      ],
                    ),
                  ),
                ),
                // Show owner menus only for signed-in owners on feed cards.
                if (p['author_id'] == repo.currentUid && widget.openable)
                  // Offer the owner's edit and delete actions in a popup menu.
                  PopupMenuButton<String>(
                    // Allow interaction only when the surrounding state permits it.
                    enabled: !_busy,
                    // Handle the selected chip or popup-menu action.
                    onSelected: _menu,
                    // Build the available owner menu choices when the popup opens.
                    itemBuilder: (_) => const [
                      // Add this named action to the owner menu.
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      // Add this named action to the owner menu.
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 12),
            // Display the post body while allowing the user to select and copy it.
            SelectableText(p['body']),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 10),
            // Display this label, instruction, status, or record value.
            Text(
              // Format the post timestamp for the device's local timezone.
              when(p['created_at']),
              // Use the theme's typography or a local text-style override.
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // Lay out its children horizontally using Flutter Row, not a database record.
            Row(
              // List the widgets displayed by this layout, in order.
              children: [
                // Render a secondary action as a text button.
                TextButton.icon(
                  // Connect this button to its action; null disables it while appropriate.
                  onPressed: _busy
                      // Use no widget/value or no error for this branch of the conditional expression.
                      ? null
                      // Choose this value for the corresponding true/false branch of the condition above.
                      : () => _action(
                          // Request the opposite of the currently displayed like state.
                          () => repo.setLike(p['id'], p['liked'] != true),
                        ),
                  // Choose the icon associated with this action.
                  icon: Icon(
                    // Use a filled heart for a liked post and an outline otherwise.
                    p['liked'] == true ? Icons.favorite : Icons.favorite_border,
                  ),
                  // Provide the control's visible text.
                  label: Text('${p['like_count']}'),
                ),
                // Render a secondary action as a text button.
                TextButton.icon(
                  // Connect this button to its action; null disables it while appropriate.
                  onPressed: widget.openable ? _open : null,
                  // Choose the icon associated with this action.
                  icon: const Icon(Icons.chat_bubble_outline),
                  // Provide the control's visible text.
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

// Show one post and a paginated conversation beneath it.
class PostPage extends StatefulWidget {
  // Construct this PostPage and accept its immutable inputs/callbacks.
  const PostPage({super.key, required this.id});
  // Store this widget's immutable identifier, optional path, or startup message.
  final String id;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<PostPage> createState() => _PostPageState();
}

// Load the post and replies, and handle reply creation and deletion.
class _PostPageState extends State<PostPage> {
  // Retain the loaded post record for the conversation header.
  db.DataRow? _post;
  // Keep already loaded replies so another page can be appended.
  final List<db.DataRow> _comments = [];
  // Track loading, possible next-page availability, and an open compose operation.
  bool _busy = false, _more = true, _writing = false;
  // Store a load error separately from the existing visible records.
  String? _error;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Initialize state once when Flutter inserts this widget into the tree.
  void initState() {
    // Run the parent State initialization before starting this widget's work.
    super.initState();
    // Start the initial data/photo lookup for this State.
    _load();
  }

  // Load the current feed/conversation page; next=true continues from the last record.
  Future<void> _load({bool next = false}) async {
    // Ignore an overlapping load while another request is still active.
    if (_busy) return;
    // Update local state and ask Flutter to rebuild this widget.
    setState(() {
      // Mark the request as running before waiting on it.
      _busy = true;
      // Clear the previous load failure before retrying.
      _error = null;
    });
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Read the current post and its latest like/reply counts.
      final p = await repo.post(widget.id);
      // Fetch one page of replies for the same conversation.
      final comments = await repo.comments(
        // Pass the current conversation's post ID to the reply query.
        widget.id,
        // Continue after the last loaded record only when requesting the next page.
        cursor: next && _comments.isNotEmpty ? _comments.last : null,
      );
      // Stop if this State has already been removed from the widget tree.
      if (!mounted) return;
      // Update local state and ask Flutter to rebuild this widget.
      setState(() {
        // Replace the conversation header with its newest server record.
        _post = p;
        // Discard previous reply pages when refreshing from the beginning.
        if (!next) _comments.clear();
        // Append this page of replies in server-provided order.
        _comments.addAll(comments);
        // Allow another reply page when this one reached the page-size limit.
        _more = comments.length == 20;
      });
      // Catch the failure and translate it into feedback for this operation.
    } catch (e) {
      // Display the load failure while retaining any previously loaded content.
      if (mounted) setState(() => _error = message(e));
      // Always release the busy state or temporary resources, even after an error or early return.
    } finally {
      // Re-enable controls after success or failure if the screen still exists.
      if (mounted) setState(() => _busy = false);
    }
  }

  // Open a reply author's profile and reload the conversation on return.
  Future<void> _profile(String id) async {
    // Push another screen and wait until navigation returns to this one.
    await Navigator.of(
      // Pass this screen's context to the navigator lookup.
      context,
      // Create the author-profile route on the navigator found above.
    ).push(MaterialPageRoute<void>(builder: (_) => Timeline(author: id)));
    // Reload data after the action/navigation only if this screen still exists.
    if (mounted) await _load();
  }

  // Collect reply text and save it against the current post.
  Future<void> _comment() async {
    // Avoid opening a second composer while one is already active.
    if (_writing) return;
    // Disable repeated compose actions until this operation finishes.
    setState(() => _writing = true);
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Wait for validated reply text or cancellation.
      final text = await editText(context, 'Reply');
      // Stop after cancellation or if navigation removed the screen while editing.
      if (!mounted || text == null) return;
      // Catch failures from the asynchronous operation so the UI can report them.
      try {
        // Save the reply under this post using the authenticated author.
        await repo.comment(widget.id, text);
        // Reload data after the action/navigation only if this screen still exists.
        if (mounted) await _load();
        // Catch the failure and translate it into feedback for this operation.
      } catch (e) {
        // Show the translated error only if this screen is still present.
        if (mounted) notify(context, message(e));
      }
      // Always release the busy state or temporary resources, even after an error or early return.
    } finally {
      // Restore compose availability only while this State is still mounted.
      if (mounted) setState(() => _writing = false);
    }
  }

  // Ask for confirmation before deleting the selected reply.
  Future<void> _delete(String id) async {
    // Stop on cancellation or if the screen closed during confirmation.
    if (!await confirmDelete(context) || !mounted) return;
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Request deletion of this reply; database ownership rules still apply.
      await repo.deleteComment(id);
      // Reload data after the action/navigation only if this screen still exists.
      if (mounted) await _load();
      // Catch the failure and translate it into feedback for this operation.
    } catch (e) {
      // Show the translated error only if this screen is still present.
      if (mounted) notify(context, message(e));
    }
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) => Scaffold(
    // Build the screen's top navigation and action bar.
    appBar: AppBar(
      // Set the screen, dialog, or application title.
      title: const Text('Conversation'),
      // Place action buttons in the app bar or dialog footer.
      actions: [
        // Render an action using an icon and optional accessibility tooltip.
        IconButton(
          // Connect this button to its action; null disables it while appropriate.
          onPressed: _busy ? null : () => _load(),
          // Choose the icon associated with this action.
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    // Choose whether this screen offers a prominent compose/reply action.
    floatingActionButton: _post == null
        // Use no widget/value or no error for this branch of the conditional expression.
        ? null
        // Choose this value for the corresponding true/false branch of the condition above.
        : FloatingActionButton.extended(
            // Connect this button to its action; null disables it while appropriate.
            onPressed: _writing ? null : _comment,
            // Provide the control's visible text.
            label: const Text('Reply'),
            // Choose the icon associated with this action.
            icon: const Icon(Icons.reply),
          ),
    // Supply the main screen content below the app bar.
    body: Center(
      // Supply the single widget or expression displayed inside this parent.
      child: ConstrainedBox(
        // Limit content width to keep forms and feeds readable on wide screens.
        constraints: const BoxConstraints(maxWidth: 680),
        // Supply the single widget or expression displayed inside this parent.
        child: ListView(
          // Reserve space around the nested content.
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          // List the widgets displayed by this layout, in order.
          children: [
            // Keep a compact progress indicator visible while data loads.
            if (_busy) const LinearProgressIndicator(),
            // Render an error message only when the latest load failed.
            if (_error != null)
              // Display this label, instruction, status, or record value.
              Text('Post unavailable or connection failed: $_error'),
            // Render the conversation header only after a post has loaded.
            if (_post != null)
              // Render the supplied post with shared feed-card behavior.
              PostCard(
                // Pass the feed record to PostCard using its row parameter.
                row: _post!,
                // Refresh the surrounding feed or conversation after a mutation.
                onChanged: () => _load(),
                // Open the selected author's profile from the card.
                onProfile: _profile,
                // Prevent opening the same conversation from its own header card.
                openable: false,
              ),
            // Show the no-replies placeholder after loading finishes with no replies.
            if (!_busy && _comments.isEmpty)
              // Add space around this group of content.
              const Padding(
                // Reserve space around the nested content.
                padding: EdgeInsets.all(20),
                // Supply the single widget or expression displayed inside this parent.
                child: Text('No replies yet.'),
              ),
            // Render each loaded reply as its own card.
            ..._comments.map(
              // Build a reply card from this comment-feed record.
              (c) => Card(
                // Supply the single widget or expression displayed inside this parent.
                child: Padding(
                  // Reserve space around the nested content.
                  padding: const EdgeInsets.all(16),
                  // Supply the single widget or expression displayed inside this parent.
                  child: Column(
                    // Align the column's children to the leading edge.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // List the widgets displayed by this layout, in order.
                    children: [
                      // Lay out its children horizontally using Flutter Row, not a database record.
                      Row(
                        // List the widgets displayed by this layout, in order.
                        children: [
                          // Load the author's private photo or display the default person icon.
                          Avatar(path: c['avatar_path']),
                          // Reserve a fixed amount of space between nearby elements.
                          const SizedBox(width: 8),
                          // Give this child the remaining horizontal space to avoid crowding its neighbors.
                          Expanded(
                            // Supply the single widget or expression displayed inside this parent.
                            child: InkWell(
                              // Open this reply author's profile when the username is tapped.
                              onTap: () => _profile(c['author_id']),
                              // Supply the single widget or expression displayed inside this parent.
                              child: Text('@${c['username']}'),
                            ),
                          ),
                          // Offer individual reply deletion only to its signed-in author.
                          if (c['author_id'] == repo.currentUid)
                            // Render an action using an icon and optional accessibility tooltip.
                            IconButton(
                              // Connect this button to its action; null disables it while appropriate.
                              onPressed: () => _delete(c['id']),
                              // Choose the icon associated with this action.
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                      // Display this label, instruction, status, or record value.
                      Text(c['body']),
                      // Reserve a fixed amount of space between nearby elements.
                      const SizedBox(height: 8),
                      // Display this label, instruction, status, or record value.
                      Text(
                        // Show the reply creation time in the device's local timezone.
                        when(c['created_at']),
                        // Use the theme's typography or a local text-style override.
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Offer another reply page when there may be more results.
            if (_more && _comments.isNotEmpty)
              // Render a secondary action as a text button.
              TextButton(
                // Connect this button to its action; null disables it while appropriate.
                onPressed: _busy ? null : () => _load(next: true),
                // Supply the single widget or expression displayed inside this parent.
                child: const Text('Load more replies'),
              ),
          ],
        ),
      ),
    ),
  );
}

// Create a profile or edit its text and immediately saved photo.
class ProfileEditor extends StatefulWidget {
  // Construct this ProfileEditor and accept its immutable inputs/callbacks.
  const ProfileEditor({super.key, this.profile, this.onSaved});
  // Keep the record supplied by the parent; db.DataRow is the map type, not a widget.
  final db.DataRow? profile;
  // Keep the parent callback used to finish or switch this flow.
  final VoidCallback? onSaved;
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Create the State object that owns this widget's mutable data and lifecycle.
  State<ProfileEditor> createState() => _ProfileEditorState();
}

// Own editable profile fields, the latest avatar path, and save feedback.
class _ProfileEditorState extends State<ProfileEditor> {
  // Own three profile text controllers for the lifetime of this editor.
  late final TextEditingController _username, _name, _bio;
  // Track the latest saved avatar path independently of unsaved profile text.
  String? _avatar;
  // Track whether an asynchronous operation should disable repeated actions.
  bool _busy = false;
  // Start with no status/error message beneath the form.
  String _status = '';
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Initialize state once when Flutter inserts this widget into the tree.
  void initState() {
    // Run the parent State initialization before starting this widget's work.
    super.initState();
    // Prefill the username when editing, or leave it empty for onboarding.
    _username = TextEditingController(text: widget.profile?['username'] ?? '');
    // Prefill the display name from the supplied profile if available.
    _name = TextEditingController(text: widget.profile?['display_name'] ?? '');
    // Prefill the optional biography from the supplied profile.
    _bio = TextEditingController(text: widget.profile?['bio'] ?? '');
    // Start with the existing avatar path, if the profile has one.
    _avatar = widget.profile?['avatar_path'];
  }

  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Release controllers and listeners when Flutter removes this State permanently.
  void dispose() {
    // Release this text controller and its listeners to avoid retaining the closed form.
    _username.dispose();
    // Release this text controller and its listeners to avoid retaining the closed form.
    _name.dispose();
    // Release this text controller and its listeners to avoid retaining the closed form.
    _bio.dispose();
    // Complete the parent State cleanup after releasing owned resources.
    super.dispose();
  }

  // Run a form operation with busy-state handling and a readable error message.
  Future<void> _run(Future<void> Function() action) async {
    // Update local state and ask Flutter to rebuild this widget.
    setState(() {
      // Mark the request as running before waiting on it.
      _busy = true;
      // Clear the previous form feedback before another attempt.
      _status = '';
    });
    // Catch failures from the asynchronous operation so the UI can report them.
    try {
      // Wait for the caller-provided operation so its failures reach this handler.
      await action();
      // Catch the failure and translate it into feedback for this operation.
    } catch (e) {
      // Store a readable request error only while the form is still mounted.
      if (mounted) setState(() => _status = message(e));
      // Always release the busy state or temporary resources, even after an error or early return.
    } finally {
      // Re-enable controls after success or failure if the screen still exists.
      if (mounted) setState(() => _busy = false);
    }
  }

  // Validate profile text, save it, and return to onboarding or the previous page.
  Future<void> _save() => _run(() async {
    // Select the first validation failure so invalid profile text is not sent to the database.
    final error =
        // Check the restricted username format before validating the other fields.
        validateUsername(_username.text) ??
        // Check the trimmed display-name length using database-compatible code points.
        validateDisplayName(_name.text) ??
        // Check the optional biography's database-compatible length last.
        validateBio(_bio.text);
    // Let the form's error handler display the validation failure before any save.
    if (error != null) throw Exception(error);
    // Persist the validated and trimmed profile text through the repository.
    await repo.saveProfile({
      // Save the username without leading or trailing whitespace.
      'username': _username.text.trim(),
      // Save the trimmed display name after checking its Unicode length.
      'display_name': _name.text.trim(),
      // Save a trimmed biography, including an empty string when omitted.
      'bio': _bio.text.trim(),
      // Insert during onboarding; otherwise update the existing profile.
    }, create: widget.profile == null);
    // Stop if this State has already been removed from the widget tree.
    if (!mounted) return;
    // Use the onboarding callback when the parent supplied one.
    if (widget.onSaved != null) {
      // Tell the profile gate to reload and advance to the feed.
      widget.onSaved!();
      // Use the alternative branch when the preceding condition did not match.
    } else {
      // Close this screen/dialog and return control to its caller.
      Navigator.pop(context);
    }
  });
  // Choose or remove a photo, then reload its saved path and any cleanup warning.
  Future<void> _photo({bool remove = false}) => _run(() async {
    // Keep cleanup feedback separate from a successful photo change.
    String? warning;
    // Choose profile-photo removal instead of picking a replacement.
    if (remove) {
      // Clear the profile photo and capture any old-object cleanup warning.
      warning = await repo.removeAvatar(_avatar);
      // Use the alternative branch when the preceding condition did not match.
    } else {
      // Open the platform photo picker and wait for the selection.
      final file = await ImagePicker().pickImage(
        // Choose an existing photo from the library rather than opening a camera.
        source: ImageSource.gallery,
        // Ask the picker to constrain photo width before app-side processing.
        maxWidth: 1024,
        // Ask the picker to constrain photo height before app-side processing.
        maxHeight: 1024,
        // Request a smaller picker result where the platform supports JPEG quality.
        imageQuality: 85,
        // Avoid requesting complete photo metadata that the app does not need.
        requestFullMetadata: false,
      );
      // Stop if the picker was canceled or the editor disappeared while it was open.
      if (!mounted || file == null) return;
      // Upload and save a replacement while retaining cleanup feedback.
      warning = await repo.replaceAvatar(file, _avatar);
    }
    // Reload the profile to display the actual saved photo path.
    final updated = await repo.profile(repo.uid);
    // Only touch widget state or its context while this screen still exists.
    if (mounted)
      // Update local state and ask Flutter to rebuild this widget.
      setState(() {
        // Replace the displayed avatar path with the saved value.
        _avatar = updated?['avatar_path'];
        // Show the cleanup warning if present, otherwise confirm the photo change.
        _status = warning ?? 'Profile photo saved.';
      });
  });
  // Implement the framework or storage interface method with this class's behavior.
  @override
  // Describe this screen's current widget tree; Flutter calls build when state changes.
  Widget build(BuildContext context) => Scaffold(
    // Build the screen's top navigation and action bar.
    appBar: AppBar(
      // Set the screen, dialog, or application title.
      title: Text(
        // Choose onboarding or editing language according to whether a profile already exists.
        widget.profile == null ? 'Create your profile' : 'Edit profile',
      ),
    ),
    // Supply the main screen content below the app bar.
    body: Center(
      // Supply the single widget or expression displayed inside this parent.
      child: ConstrainedBox(
        // Limit content width to keep forms and feeds readable on wide screens.
        constraints: const BoxConstraints(maxWidth: 520),
        // Supply the single widget or expression displayed inside this parent.
        child: ListView(
          // Reserve space around the nested content.
          padding: const EdgeInsets.all(24),
          // List the widgets displayed by this layout, in order.
          children: [
            // Load the author's private photo or display the default person icon.
            Avatar(path: _avatar),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 12),
            // Offer photo actions only after onboarding has saved a profile.
            if (widget.profile != null)
              // Let controls flow onto another line on narrow screens.
              Wrap(
                // Leave horizontal space between wrapped controls.
                spacing: 8,
                // List the widgets displayed by this layout, in order.
                children: [
                  // Render a secondary action as a text button.
                  TextButton(
                    // Connect this button to its action; null disables it while appropriate.
                    onPressed: _busy ? null : () => _photo(),
                    // Supply the single widget or expression displayed inside this parent.
                    child: const Text('Choose photo'),
                  ),
                  // Show Remove photo only when an avatar is currently stored.
                  if (_avatar != null)
                    // Render a secondary action as a text button.
                    TextButton(
                      // Connect this button to its action; null disables it while appropriate.
                      onPressed: _busy ? null : () => _photo(remove: true),
                      // Supply the single widget or expression displayed inside this parent.
                      child: const Text('Remove photo'),
                    ),
                ],
              )
            // Use the alternative branch when the preceding condition did not match.
            else
              // Display this label, instruction, status, or record value.
              const Text(
                // Supply this literal message, label, or formatted value to the surrounding expression.
                'Save your profile first; then add a photo from Edit profile.',
              ),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 16),
            // Render an editable input connected to the controller below.
            TextField(
              // Connect this input to the controller that stores its text.
              controller: _username,
              // Limit visible grapheme clusters; validators also check database code-point limits.
              maxLength: 24,
              // Supply the input's label, hint, border, or validation feedback.
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 12),
            // Render an editable input connected to the controller below.
            TextField(
              // Connect this input to the controller that stores its text.
              controller: _name,
              // Limit visible grapheme clusters; validators also check database code-point limits.
              maxLength: 50,
              // Supply the input's label, hint, border, or validation feedback.
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 12),
            // Render an editable input connected to the controller below.
            TextField(
              // Connect this input to the controller that stores its text.
              controller: _bio,
              // Limit visible grapheme clusters; validators also check database code-point limits.
              maxLength: 160,
              // Reserve a minimum number of visible lines for multiline input.
              minLines: 2,
              // Allow multiline input to expand only to this visible height.
              maxLines: 4,
              // Supply the input's label, hint, border, or validation feedback.
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            // Reserve a fixed amount of space between nearby elements.
            const SizedBox(height: 12),
            // Render the primary action with a filled Material button.
            FilledButton(
              // Connect this button to its action; null disables it while appropriate.
              onPressed: _busy ? null : _save,
              // Supply the single widget or expression displayed inside this parent.
              child: Text(_busy ? 'Saving…' : 'Save profile'),
            ),
            // Display this label, instruction, status, or record value.
            Text(_status),
            // Offer onboarding logout while the profile has not yet been created.
            if (widget.profile == null)
              // Render a secondary action as a text button.
              TextButton(
                // Connect this button to its action; null disables it while appropriate.
                onPressed: _busy
                    // Use no widget/value or no error for this branch of the conditional expression.
                    ? null
                    // Choose this value for the corresponding true/false branch of the condition above.
                    : () => _run(() async {
                        // End the current auth session through Supabase.
                        await repo.client.auth.signOut();
                      }),
                // Supply the single widget or expression displayed inside this parent.
                child: const Text('Log out'),
              ),
          ],
        ),
      ),
    ),
  );
}
