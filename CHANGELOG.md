# Chripy 1.0.0 tutorial package

## Documentation — 21 October 2026

- Added line-by-line explanations to handwritten Dart source/tests, Node setup
  helpers, SQL migrations/tests, email templates, and the Codemagic workflow.
- Reworked the root README into repository documentation with an overview,
  architecture diagram, quick start, configuration, testing, iPhone build steps,
  and troubleshooting.
- Preserved the longer original walkthrough in `TUTORIAL.md` and repaired
  its relative documentation links.
- Confirmed executable code and workflow behavior are unchanged. Flutter analysis
  reports no issues, all 11 tests pass, and Node syntax/documentation checks pass.

## Local fixes — 20 October 2026

- Renamed the repository's `Row` alias to `DataRow` and imported the repository
  as `db` in the UI. Material also exports `DataRow`, so the prefix is necessary
  to remove both naming collisions. All three Flutter `Row` layouts are retained.
- Removed the redundant `dart:typed_data` import from the UI.
- Validate display-name and bio lengths before saving, using Unicode code points
  to match PostgreSQL. Combined characters can fit Flutter's visible-character
  limits while exceeding the database limits.
- Guarded UI ownership checks against ended sessions and replaced the repository's
  forced null assertion with a readable login error.
- Guarded post edit/delete callbacks against disposed widgets. New-post, reply,
  comment-delete and image-picker continuations also stop if their screen closes.
- Added profile-validation and post-card lifecycle regression tests. Flutter
  analysis reports no issues and all 11 tests pass on Flutter 3.47.7 / Dart 3.13.5.

Replaces the Pocket Test learning demo with a social app using local Supabase/PostgreSQL.

- Added Flutter account, verification, recovery, onboarding, feed, comments, likes and profile screens.
- Added avatar upload/resizing and private Storage rules.
- Added PostgreSQL schema, RLS, restricted grants, count views and ownership tests.
- Added local Auth email templates for Mailpit.
- Added setup scripts that preserve the supplied Flutter code while generating platform files.
- Added Codemagic workflow and full Windows/iPhone tutorial.
- Added package-update and database-migration instructions.

The distribution contains source, not a compiled IPA. Platform files and dependency lockfiles are generated on your Windows machine, then committed to Git. Read docs/VALIDATION.md for checks actually performed.
