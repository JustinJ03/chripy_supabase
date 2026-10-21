# Chripy — build a Flutter social app on Windows and install it on iPhone

**Start here.** This package replaces the earlier Pocket Test sample with Chripy source code, a Supabase migration, local email templates and build scripts. It is a guided development project, not an already compiled IPA.

Prepared for Justin • 20 October 2026 • Package 1.0.0

## What you will build

A small social app with registration, email verification, login/logout, password recovery, profile onboarding, text posts, post editing/deletion, replies, likes, editable profiles and profile photos. The feed and replies are paginated. Only the owner can edit/delete their content. Deleting a post also deletes its likes and replies.

You will write Dart in VS Code on Windows. Local Supabase runs on your PC through Docker. Your iPhone connects to that backend over home Wi-Fi. Codemagic supplies the Mac/Xcode environment to compile the iOS app; Sideloadly signs and installs it.

**Scope:** local learning with test accounts. Your PC must be on with Docker/Supabase running. No following, private messages, image posts, push notifications or offline sync. Chrome is a fast UI preview, not an iPhone simulator.

**Validation:** read [docs/VALIDATION.md](docs/VALIDATION.md). The package includes checks you must run before building. No iPhone-tested claim is made.

## 1. Understand each part before installing it

| Part | What it does | Where it runs |
|---|---|---|
| Flutter/Dart | UI and client logic | Windows during development; iPhone after installation |
| Supabase Auth | Signup, password checks, email codes, sessions | Docker on Windows |
| PostgreSQL | Relational storage for profiles/posts/comments/likes | Inside local Supabase |
| Supabase Data API | Receives HTTP requests and applies database permissions | Inside local Supabase |
| Supabase Storage | Stores private avatar files | Inside local Supabase |
| Mailpit | Captures test emails for reading in a browser | Inside local Supabase |
| GitHub | Stores source for CI | Online |
| Codemagic | Compiles Flutter with macOS/Xcode | Cloud Mac |
| Sideloadly | Signs/installs the downloaded IPA | Windows + connected iPhone |

When you press **Chirp**, Flutter sends a request through the Supabase SDK. Supabase identifies your user, PostgreSQL checks its Row Level Security (RLS) rules, saves the row, and returns the result. Password handling belongs to Auth. Flutter never needs a database password or a service-role key.

You do not need Python, FastAPI, Laravel, Laragon, a separate PostgreSQL installer, or a separate Mailpit Docker container for this package.

## 2. Prepare Windows

Install these from their official sites:

1. **Git for Windows:** https://git-scm.com/downloads/win
2. **VS Code:** https://code.visualstudio.com/
3. **Flutter stable:** install the Flutter extension by Dart Code in VS Code. Open Ctrl+Shift+P → Flutter: New Project → Download SDK when prompted. Choose a writable folder such as `C:\src\flutter`, add the SDK to PATH and restart VS Code. Manual alternative: https://docs.flutter.dev/install/manual
4. **Node.js LTS:** https://nodejs.org/ . This supplies npm/npx for Supabase CLI and the included setup scripts.
5. **Docker Desktop:** https://docs.docker.com/desktop/setup/install/windows-install/ . Follow its current WSL2/virtualization requirements and use Linux containers. Start Docker Desktop and wait until its engine is running.
6. **Google Chrome:** used for the first local preview.

Windows cannot run Xcode or Apple's official iOS simulator. That is why compilation moves to Codemagic later. You do not need Android Studio or Visual Studio C++ for this browser/iPhone route.

Open a new VS Code terminal, choose **PowerShell**, and run:

```powershell
git --version
node --version
npm --version
docker version
flutter --version
flutter doctor -v
```

Expected: all commands exist, Docker reports both client and server, and Flutter detects Chrome. Ignore Android/Windows-desktop toolchain warnings only if you are not targeting those platforms. If `flutter` is unrecognized, add `C:\src\flutter\bin` to your user PATH and restart the terminal. If PowerShell blocks `npm.ps1`, use `npm.cmd` and `npx.cmd` for the corresponding commands instead of changing machine-wide execution policies.

## 3. Extract the updated package into a new folder

Extract so this file is at:

```text
C:\dev\chripy_supabase\README.md
```

Do not copy the package over your old Pocket Test project. Chripy uses a new project/bundle identity. All commands below assume that extraction location; adjust if yours differs.

```powershell
Set-Location C:\dev\chripy_supabase
code .
npm install
npm run setup
```

What setup does:

- Generates standard Flutter **iOS and web platform files** if absent.
- Preserves the supplied `mobile/lib`, `mobile/test` and `mobile/pubspec.yaml`.
- Initializes local Supabase configuration if absent.
- Enables email confirmation, sets a 10-character password minimum and configures six-digit codes with a 15-minute expiry.
- Connects the supplied confirmation/recovery email templates.
- Adds iOS photo-library and local-network usage text and a local-development HTTP exception.
- Copies the configuration example to `mobile/config.local.json` if that file does not exist.

Expected new files: `mobile/ios/Runner/Info.plist`, `mobile/web/index.html`, `supabase/config.toml`, `package-lock.json` and `mobile/config.local.json`. The setup command is intended to be rerunnable, but it will reapply its local Auth/iOS settings. Run it on initial setup, not as your everyday update command.

Then install Flutter dependencies:

```powershell
Set-Location C:\dev\chripy_supabase\mobile
flutter pub get
dart format lib test
flutter analyze
flutter test
```

`flutter pub get` creates `pubspec.lock`, recording the actual dependency versions. Commit it later. If dependency resolution says your Dart/Flutter version is too old, update stable Flutter and retry rather than deleting the package constraints blindly. The supplied package versions were checked against published documentation; resolution/compilation still needs your installed SDK.

Checkpoint: analysis and tests pass. Fix any error before starting the iPhone build.

## 4. Start local Supabase

Return to the repository root:

```powershell
Set-Location C:\dev\chripy_supabase
npx supabase start
npx supabase status
```

The first start pulls Docker images and may take several minutes. Keep the terminal output available privately: it includes local URLs and keys. Do not post secret/service-role keys in screenshots or GitHub.

Typical defaults are below, but use the actual output from your CLI:

| Service | Typical address | Used by |
|---|---|---|
| Supabase API | `http://127.0.0.1:54321` | Flutter on this PC |
| PostgreSQL | port `54322` | Database tools; not the mobile app |
| Supabase Studio | `http://127.0.0.1:54323` | You, in a PC browser |
| Mailpit | `http://127.0.0.1:54324` | You, in a PC browser |

Open Studio and Mailpit. Some CLI configuration headings retain the historical name `inbucket`; use the email-catcher URL printed by your installed CLI.

If Docker reports insufficient resources, close other heavy software or adjust Docker's resource settings. If a port is occupied, find the other application before changing the port, then update the app URL consistently.

## 5. Apply the database migration

The included file `supabase/migrations/20261020000100_chripy.sql` creates the schema, policies, feed views and private avatars bucket. New stacks may apply migrations during startup. Explicitly apply any pending local migrations:

```powershell
npx supabase migration up --local
```

Open Studio's Table Editor. You should see `profiles`, `posts`, `comments` and `likes`. Storage should contain a **private** bucket called `avatars`. The `feed` and `comment_feed` views supply author information and counts.

If you prefer SQL inspection, open the migration in VS Code and read it before execution. Do not paste/run the same migration again after it has already applied. The CLI migration history tracks applied files.

Data structure:

| Table | Purpose | Ownership |
|---|---|---|
| `auth.users` | Supabase-managed accounts | Supabase Auth |
| `profiles` | Username, display name, bio, avatar path | Same UUID as Auth user |
| `posts` | Text and author | `author_id` |
| `comments` | Reply text, post and author | `author_id` |
| `likes` | User/post pair | `user_id` |

Usernames must be unique. Posts/replies contain 1–280 trimmed characters. A composite key prevents duplicate likes. Update grants prevent changing ownership columns. Avatar paths must start with the owner's UUID. The feed views use invoker security, so their queries still obey the calling user's permissions.

### Check ownership before trusting the UI

Open `supabase/tests/ownership.sql`, copy it into **local** Studio's SQL editor and run it. It creates temporary Alice/Bob fixtures inside a transaction, exercises permissions and rolls everything back. Successful execution produces no `FAIL` exception. The test checks cross-user editing/deletion, author spoofing, duplicate likes, counters, immutable ownership, avatar path ownership, cascades and signed-out access. It is not a complete Storage API or Auth-email test; those follow below.

**Do not use `supabase db reset` as a routine restart.** It rebuilds the database and deletes local test data. Use it only when you intentionally want a clean disposable database and understand what will be lost.

## 6. Connect Flutter on Windows

Open `mobile/config.local.json`. Replace the placeholder with the **publishable** key printed by `supabase status`; if that local CLI exposes a legacy **anon** key instead, use that. Never use the secret/service_role key.

```json
{
  "SUPABASE_URL": "http://127.0.0.1:54321",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_LOCAL_PUBLISHABLE_OR_ANON_KEY"
}
```

This file is ignored by Git. These client settings are not privileged secrets, but keeping environments separate prevents accidentally pointing builds at the wrong server. A compiled app's publishable key is inspectable; RLS provides access control.

From the mobile folder:

```powershell
Set-Location C:\dev\chripy_supabase\mobile
flutter run -d chrome --web-port=5173 --dart-define-from-file=config.local.json
```

Expected: the Chripy login screen. If you see the setup error screen, check the filename/JSON and restart the run command. Dart-define values are compiled into the app; hot reload cannot change them.

The browser preview intentionally does not persist the login across a full page reload. Native iPhone sessions use a custom Supabase storage adapter backed by Keychain. Do not assume browser and iPhone storage behave identically.

## 7. Register and verify the first user

1. Select **Register**.
2. Enter `alice@example.com` and a test password with at least 10 characters. Use test-only passwords.
3. Press Register. Chripy switches to **Verify email**.
4. On your PC, open Mailpit and select the confirmation email for Alice.
5. Copy the six-digit code into Chripy and verify it within 15 minutes.
6. Create a profile: username `alice`, display name `Alice`, a short bio.
7. Save. You should see the empty feed.

Mailpit intercepts the email; no message is sent to a real mailbox. The code verification uses `OtpType.email`. Resending signup confirmation uses the SDK's signup resend type. Recovery uses a separate recovery type.

If the code expires, select Verify email and resend. Wait at least 60 seconds between requests. If registration fails and you cannot tell whether an account already exists, try login/verification/recovery instead of continually creating duplicates.

### Password recovery

1. Log out and press **Forgot password?**.
2. Enter Alice's email and press **Send recovery code**.
3. Open the latest recovery message in Mailpit.
4. Enter the code and a new password, then press **Set new password**.
5. Log in with the new password.

The code establishes a recovery session; only then does the app call the password-update API. The recovery screen stays active while that happens. If you cancel recovery, it signs out before returning to login. On shared devices, always log out when finished.

## 8. Test posts, comments and likes with two users

While signed in as Alice:

1. Press **Chirp**, type a short post and Save.
2. Open its menu to Edit, then check the new text.
3. Tap the heart, then tap again to remove your like.
4. Open the comments button, press Reply and add a reply.
5. Open My profile; your post should appear there.

Log out and register/verify `bob@example.com` with username `bob`. As Bob, read Alice's post, like it and reply. Bob should not see Alice's edit/delete menu. The SQL permission test—not just hidden buttons—checks unauthorized mutations.

Log back in as Alice. You can edit/delete your post, but you cannot directly delete Bob's individual reply. If you delete the whole post, its replies and likes are deleted with it. Test only with disposable content.

The app uses pull-to-refresh/manual refresh, not Realtime subscriptions. Feed/replies load 20 records at a time; **Load more** retrieves another page. If another account changes content, refresh to see it.

## 9. Edit a profile and upload a photo

1. Open **My profile → Edit profile**.
2. Change display name/bio or choose an available lowercase username.
3. Press **Choose photo** and select JPEG/PNG from the photo library.
4. The app resizes the image and uploads a JPEG to your own folder in the private avatars bucket.
5. Save profile text separately if you changed it; photo actions are saved immediately.
6. Refresh the feed to see the updated author/photo.

The stored avatar limit is 2 MB. If an HEIC selection cannot be decoded, export/select a JPEG instead; the app reports that error. Image-picker handling can differ on a physical iPhone, so test it there too. The app downloads avatars with the signed-in user's authorization; it does not publish permanent public photo URLs.

Replacing a photo saves the new path before removing the old object. A cleanup failure is shown as a warning because the new photo may already be saved. You can inspect leftover files in local Studio Storage. A production app would add scheduled orphan cleanup and stricter server-side content validation.

## 10. Learn by changing the supplied code

| File | Read/change this to learn |
|---|---|
| `mobile/lib/main.dart` | Screens, navigation, async actions and loading/errors |
| `mobile/lib/repository.dart` | Supabase queries, cursor pagination, mutations and avatar handling |
| `mobile/lib/session_store.dart` | Native session persistence adapter |
| `mobile/lib/validation.dart` | Reusable text and username validation |
| `supabase/migrations/…sql` | Tables, foreign keys, RLS, grants and private storage |
| `supabase/templates/*.html` | Test confirmation/recovery email content |
| `scripts/setup.mjs` | How platform generation and configuration fit together |
| `codemagic.yaml` | CI analysis, tests, release compilation and IPA packaging |

Try these exercises in order:

1. Change the login subtitle in main.dart. Save and hot reload using VS Code's Flutter controls.
2. Change the theme seed color, then resize Chrome to a phone width.
3. Change a validation error message and run `flutter test`.
4. Read `writePost`: identify the table, submitted columns and server-enforced ownership rule.
5. Add an optional profile field using a new migration, then update the editor/repository. Keep database and client rules consistent.

Before each significant change, make a Git commit. You can compare the diff and restore your code without resetting the database.

## 11. Make local Supabase reachable from the iPhone

Connect the iPhone and Windows PC to the same trusted home Wi-Fi. Disable guest-network/client isolation for this test if your router separates devices. The PC must remain awake.

Run:

```powershell
ipconfig
```

Find the Wi-Fi adapter's IPv4 address, for example `192.168.1.50`. Do not choose Docker/WSL virtual-adapter addresses. The iPhone's API URL would then be:

```text
http://192.168.1.50:54321
```

`127.0.0.1`/`localhost` on an iPhone refers to that iPhone, not the PC.

### Confirm Docker port publishing

From the PC:

```powershell
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

Find the Supabase gateway/API service. Port 54321 needs a reachable host binding. `0.0.0.0:54321` normally accepts LAN connections; `127.0.0.1:54321` is loopback-only. Do not open PostgreSQL/Studio/Mailpit to the phone. Docker/CLI versions can differ, so inspect the actual binding rather than assuming it.

### Restrict Windows Firewall to your private network

Set your trusted home connection's Windows network profile to **Private**. In an administrator PowerShell, if the API is bound to the LAN, create a narrowly scoped rule:

```powershell
New-NetFirewallRule -DisplayName "Chripy Supabase LAN" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 54321 -Profile Private -RemoteAddress LocalSubnet
```

Do not disable Windows Firewall or add router port forwarding. Inspect existing Docker firewall rules as well; this new rule does not cancel a broader rule created elsewhere.

If the gateway is loopback-only, you can use an explicit Windows port proxy as a development fallback. Replace the address below with your actual Wi-Fi address and keep the firewall rule above:

```powershell
netsh interface portproxy add v4tov4 listenaddress=192.168.1.50 listenport=54321 connectaddress=127.0.0.1 connectport=54321
netsh interface portproxy show all
```

Use that only when needed; do not add it on top of an already-working all-interface binding. The IP Helper service must be running for Windows portproxy. If the address changes, remove/recreate the proxy. Cleanup when no longer needed:

```powershell
netsh interface portproxy delete v4tov4 listenaddress=192.168.1.50 listenport=54321
Remove-NetFirewallRule -DisplayName "Chripy Supabase LAN"
```

From iPhone Safari, visit `http://YOUR_PC_IP:54321/auth/v1/health`. A gateway response such as a missing API key still proves that traffic reached the server; a timeout indicates a network/firewall/binding problem. Complete the actual app login to verify authentication. Do not put privileged keys into a browser URL.

## 12. Configure and build the iPhone app

The setup script already added these keys to `mobile/ios/Runner/Info.plist`:

- `NSLocalNetworkUsageDescription` — explain the home-PC connection.
- `NSPhotoLibraryUsageDescription` — explain choosing a profile photo.
- `NSAppTransportSecurity` with `NSAllowsArbitraryLoads=true` — permit HTTP for this local development build.

That last setting is deliberately broad and **not a production configuration**. Use test credentials on your trusted Wi-Fi. When switching to a hosted HTTPS backend, remove the HTTP exception and retest. Do not add NSAllowsLocalNetworking alongside it without checking Apple's version-specific interaction; that can change which rule applies.

No camera permission is requested because the app uses the photo library only. No multicast entitlement is required because you enter/use a known server address rather than discovering devices.

### Push the generated project to GitHub

Create an empty private GitHub repository named `chripy` with no initial README. From the project root:

```powershell
Set-Location C:\dev\chripy_supabase
git init
git add .
git commit -m "Add Chripy Flutter app and local Supabase"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/chripy.git
git push -u origin main
```

Replace YOUR_USERNAME and authenticate through the browser/Git credential flow. If requested, configure your Git name/email first. Inspect `git status` and the staged files before committing. Include generated `mobile/ios`, `mobile/web`, `mobile/pubspec.lock`, `package-lock.json` and `supabase/config.toml`; exclude config.local.json, signing keys, node_modules and build artifacts.

### Set up Codemagic

1. Sign in at https://codemagic.io/ and connect the GitHub repository.
2. Add the app and select the repository's YAML configuration.
3. Create an environment-variable group named **chripy** in the appropriate app/team settings.
4. Add `SUPABASE_URL` = `http://YOUR_PC_WIFI_IP:54321`.
5. Add `SUPABASE_PUBLISHABLE_KEY` = your **local client publishable/anon key**.
6. Ensure the workflow has access to that group. Never put a secret/service_role key here for client use.
7. Choose branch main and workflow **Chripy - local Supabase iPhone build**.
8. Review available Mac minutes/pricing, then start the build.

The workflow checks platform files, resolves the committed lockfile, analyzes/tests Dart, compiles an unsigned physical-device release, and packages `chripy-unsigned.ipa`. Download it from build artifacts after success.

The cloud build machine does not have to connect to your PC to compile. It embeds the address for the installed phone to use later. CI tests must not depend on your home server being reachable.

If the Mac machine type is unavailable on your plan, use a supported macOS instance. After the first successful build, pin the working Flutter/Xcode versions from its logs rather than relying indefinitely on `stable`/`latest`.

## 13. Install with Sideloadly

1. Download from https://sideloadly.io/ and follow its current Windows Apple-driver/iTunes/iCloud prerequisites. Use the installer versions it specifies.
2. Unlock your iPhone, attach a USB data cable and accept **Trust This Computer**.
3. Open Sideloadly, select the device and drag in `chripy-unsigned.ipa`.
4. Enter your Apple account, start installation and complete authentication locally.
5. If prompted, trust the developer under Settings → General → VPN & Device Management.
6. Enable Developer Mode under Settings → Privacy & Security when required, restart and confirm.
7. Open Chripy and allow **Local Network** access. Keep the phone on home Wi-Fi.

Sideloadly signs the unsigned build; an unsigned IPA cannot simply be opened from Safari to install it. This does not publish to the App Store. Free-account signing normally needs renewal after seven days and is subject to personal-app limits. Keep the same bundle identity/signing account when reinstalling an update.

If the app launches but cannot load, check its compiled server URL, your PC's current IP, Docker status, Local Network permission, firewall and Wi-Fi isolation. Changing a Codemagic variable requires another build; it does not change an IPA already installed.

## 14. Physical-device acceptance checklist

- [ ] Register/verify an account using Mailpit on the PC.
- [ ] Login/logout and reopen the app to check native session restoration.
- [ ] Create, edit and delete a post.
- [ ] Add/delete your own comment.
- [ ] Like/unlike; repeated taps do not create duplicate likes.
- [ ] Sign in as another user and verify ownership restrictions.
- [ ] Edit profile text and choose/replace/remove a JPEG/PNG avatar.
- [ ] Reset a password through Mailpit.
- [ ] Test a wrong/expired code and a duplicate username.
- [ ] Disconnect USB; app still launches and works on Wi-Fi.
- [ ] Stop Supabase; the app shows an error rather than reporting a successful save.
- [ ] Restart services and refresh; existing saved content remains.
- [ ] Rotate the phone/use the keyboard; content remains reachable by scrolling.

Chrome and SQL tests do not replace these device checks.

## 15. Daily development and app updates

Start Docker Desktop, then:

```powershell
Set-Location C:\dev\chripy_supabase
npx supabase start
Set-Location mobile
flutter run -d chrome --web-port=5173 --dart-define-from-file=config.local.json
```

When finished, stop Flutter with `q`, then:

```powershell
Set-Location C:\dev\chripy_supabase
npx supabase stop
```

A normal stop/start preserves local data. Do not add `--no-backup`, delete Docker volumes or use db reset if you want to retain it. Local development storage is not a disaster-recovery backup; use disposable test data and export anything valuable before infrastructure changes.

For an app update:

1. Edit the Dart files and preview locally.
2. Run formatting, analysis and tests.
3. Increase `version` in `mobile/pubspec.yaml`, for example from `1.0.0+1` to `1.0.1+2`.
4. Commit and push.
5. Build in Codemagic again.
6. Install the new IPA with the same identity using Sideloadly. You normally do not need to uninstall the app first.

Code changes do not migrate database data unless you also apply a migration. Reinstalling the app does not recreate the backend.

## 16. Update Dart packages correctly

These commands run inside `mobile`:

```powershell
flutter pub outdated
flutter pub upgrade
dart format lib test
flutter analyze
flutter test
```

| Command/file | Meaning |
|---|---|
| `pubspec.yaml` | Dependency constraints you accept |
| `pubspec.lock` | Exact versions resolved for this app |
| `flutter pub get` | Install according to the existing constraints/lockfile |
| `flutter pub outdated` | Show what is behind and what constraints allow |
| `flutter pub upgrade` | Resolve newer versions within allowed constraints |
| `flutter pub add package_name` | Add a package and resolve dependencies |
| `flutter pub upgrade --major-versions` | May change constraints across breaking releases; review first |

For a deliberate major update, make a branch and read that package's changelog/migration guide before changing constraints. Then run the checks and the iPhone acceptance tests. Secure-storage, image-picker and auth changes need a real-device test. Do not delete lockfiles or update every tool just because a build fails.

Commit both pubspec.yaml (if changed) and pubspec.lock. The Codemagic workflow uses `--enforce-lockfile`; if it fails, resolve and commit a consistent lockfile on Windows. Do not suppress the failure to make CI appear green.

To update Flutter itself:

```powershell
flutter channel stable
flutter upgrade
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

Record `flutter --version`, align Codemagic's selected Flutter version, and rebuild. Flutter SDK upgrades are separate from package upgrades. Use `flutter clean` only for a concrete stale-build problem; it does not fix incompatible dependency constraints.

## 17. Update Supabase CLI and database safely

At the repository root:

```powershell
npm outdated
```

Before upgrading the local stack, stop work, review CLI release notes and preserve any local data you need. With this tutorial, using disposable test accounts is simplest. Keep schema and templates in Git regardless.

```powershell
npx supabase stop
npm update supabase
npx supabase --version
npx supabase start
npx supabase status
```

This updates within package.json's constraints. For a deliberately selected newer major release, use `npm install --save-dev supabase@VERSION` after reading its migration instructions. Commit package.json/package-lock.json and retest Auth, Storage and database access. An updated CLI may change container versions or config requirements; do not assume old local volumes are a backup.

### Add a database field without wiping data

For example, add an optional `location` field:

```powershell
npx supabase migration new add_profile_location
```

Edit the newly created SQL file:

```sql
alter table public.profiles
  add column location text not null default ''
  check (char_length(location) <= 80);
grant insert(location), update(location) on public.profiles to authenticated;
```

Apply it locally:

```powershell
npx supabase migration up --local
```

Then add the field to the Flutter profile editor and save map. Existing profile RLS still limits updates to the owner, but column grants must allow the new field. Rerun permission tests and commit the migration. Do not edit an already-applied initial migration to represent a new change; add a new migration.

## 18. Troubleshooting

| Symptom | What to check |
|---|---|
| npm/flutter not found | PATH and new terminal; use npm.cmd if script policy blocks npm.ps1 |
| Docker unavailable | Docker Desktop started; Linux containers; WSL2/virtualization |
| `relation does not exist` | Apply included local migration; check selected project |
| Permission denied during normal write | Correct client key, authenticated user, profile exists, grants/policies applied |
| No verification email | Local confirmations/templates enabled; correct Mailpit instance; resend cooldown |
| Email verification skipped | Check `auth.email.enable_confirmations=true`, restart Supabase after config change |
| Photo fails | JPEG/PNG, file limit, private bucket policies, photo-library permission |
| Browser works, iPhone fails | LAN URL versus localhost; firewall, port binding, Local Network permission |
| HTTP blocked on iPhone | Confirm development Info.plist settings made it into the generated project/build |
| CI says missing iOS files | Run setup and commit generated mobile/ios |
| CI lockfile error | Run flutter pub get locally, inspect and commit pubspec.lock |
| App quits or will not launch | Release/device build, valid signing, trust and Developer Mode |
| App stops opening after a week | Renew personal signing through Sideloadly |
| Data gone after reset | Reset/volume deletion is destructive; restore your backup or recreate test data |
| PC gets a different Wi-Fi IP | Reserve DHCP address or update build variable and rebuild; adjust proxy if used |
| Keychain error after identity change | Keep the signing identity/bundle ID consistent; test plugin configuration before release |

## 19. Optional later: hosted Supabase

Hosted Supabase means the backend lives online and your PC no longer needs to stay on. Create a separate cloud project, apply migrations, configure private storage and real SMTP, then use its HTTPS URL and publishable key. Remove the local HTTP exception before distribution.

Local accounts, database rows and avatar files do not automatically move to the hosted project. Recreate test accounts or plan a proper migration. Hosted Auth cannot send to a Mailpit service available only inside your home LAN. Its built-in mail sender has restricted recipients/rates; use a real SMTP provider for repeated multi-user testing.

TestFlight is a separate later distribution route with Apple membership/signing requirements. Keep the first goal small: two users interacting on a real iPhone against your local backend.

## 20. Official references

- Flutter setup: https://docs.flutter.dev/install/quick
- Flutter packages: https://docs.flutter.dev/packages-and-plugins/using-packages
- Supabase Flutter SDK: https://pub.dev/packages/supabase_flutter
- Supabase local setup: https://supabase.com/docs/guides/local-development/cli/getting-started
- CLI configuration/templates: https://supabase.com/docs/guides/local-development/cli/config
- Local email testing: https://supabase.com/docs/guides/local-development/cli/testing-and-linting
- OTP verification: https://supabase.com/docs/reference/dart/auth-verifyotp
- RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Storage access: https://supabase.com/docs/guides/storage/security/access-control
- Hosted SMTP: https://supabase.com/docs/guides/auth/auth-smtp
- Secure session storage: https://pub.dev/packages/flutter_secure_storage
- Photo picker: https://pub.dev/packages/image_picker
- Docker Windows requirements: https://docs.docker.com/desktop/setup/install/windows-install/
- Codemagic Flutter: https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/
- Sideloadly installation/renewal: https://sideloadly.io/faq.html
- Apple local network privacy: https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- Windows portproxy: https://learn.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-interface-portproxy
