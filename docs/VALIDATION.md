# Validation record — 20 October 2026

## Documentation checks — 21 October 2026

- Formatted all seven handwritten Dart source/test files after adding explanatory
  comments; `flutter analyze` reported no issues and all 11 tests passed.
- Compared parsed Dart token streams with the pre-comment backup: every executable
  token is unchanged in all seven files.
- Both Node helpers passed `node --check`; stripping whole-line comments confirms
  their executable source is unchanged.
- Stripping comments confirms both SQL files and the email-template HTML are
  unchanged. No migration was applied and no database operation was needed.
- Parsed `codemagic.yaml` and compared its configuration and scripts with the
  backup, excluding the new comments: unchanged.
- Checked local file links, heading links, and balanced code fences in the new
  README and preserved tutorial.
- Dependency manifests, lockfiles, backend configuration, and generated platform
  files were not edited by this documentation update.

## Local Windows checks — 20 October 2026

- Flutter 3.47.7 stable / bundled Dart 3.13.5.
- `flutter analyze`: no issues.
- `flutter test`: all 11 tests passed, including two profile-editor regression
  tests that failed before the Unicode length validation fix, and three post-card
  tests covering missing sessions and disposal while edit/delete dialogs are open.
  The latter reproduced null-assertion and `setState()`-after-dispose errors
  before the fixes. Tests use a dummy in-memory session, without a live backend.
- `node --check scripts/setup.mjs` and `node --check scripts/configure-ios.mjs` passed.
- Chrome debug build launched on port 5173; Supabase initialization completed.
- Local Supabase startup applied migration `20261020000100`; migration history
  confirmed it is applied.
- Auth health/settings and Mailpit returned HTTP 200 using the existing local
  client configuration; email confirmation is enabled.
- Executed `supabase/tests/ownership.sql` against local PostgreSQL with
  `ON_ERROR_STOP=1`: passed and rolled back its fixtures.

Dependencies, local configuration and generated platform files were preserved.
No database reset was performed. Registration/recovery/photo-upload flows and
physical iPhone compilation, signing and installation remain unverified.
GitHub, Codemagic and device setup are being handled manually by the user.

## Checks completed in the original authoring environment

- Parsed both SQL files with a PostgreSQL parser.
- Applied the complete migration in an isolated PostgreSQL engine (PGlite), with minimal stand-ins for Supabase's Auth and Storage schemas.
- Executed the supplied ownership test: cross-user updates/deletes denied, author spoofing denied, duplicate likes rejected, counts/liked flag correct, ownership columns protected, cross-user avatar paths rejected and post deletion cascades verified.
- Checked Storage row policies against cross-user insert/delete attempts in the same isolated engine.
- Parsed all supplied Dart files with the Dart Tree-sitter grammar; no syntax errors found.
- Checked both Node setup scripts for JavaScript syntax.
- Ran setup twice against generated-file fixtures; the resulting TOML and Apple plist parsed successfully, Auth settings were applied and an unrelated bundle-identifier setting was preserved.
- Parsed configuration JSON and YAML, checked tutorial code fences and ZIP integrity.

## Checks not completed here

Flutter SDK, Xcode, Docker Desktop and an attached iPhone were unavailable. Therefore `flutter pub get`, Dart type analysis, Flutter widget tests, actual iOS compilation, native Keychain/photo-picker behaviour, Supabase Auth/Mailpit HTTP integration and physical-device installation have **not** been executed here.

A grammar parse is not Dart type checking. A PostgreSQL test with stub schemas is not a full Supabase integration test. The included local commands and CI workflow make those next gates explicit. Resolve any dependency/API/build issue reported by your installed tool versions before treating the app as working.

## Required next gates

1. Run `npm install` and `npm run setup` on Windows.
2. Resolve Flutter dependencies, format, analyze and run the included Flutter tests.
3. Start local Supabase, apply the migration and run ownership.sql in local Studio.
4. Complete account/email/storage and two-user tests in Chrome.
5. Build in Codemagic and complete the README's real-iPhone checklist.

This is a learning source package, not a production-ready social network or a prebuilt IPA.
