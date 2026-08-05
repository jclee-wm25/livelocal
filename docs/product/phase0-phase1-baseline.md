# Phase 0 and Phase 1 Baseline Record

Status: **IMPLEMENTED AND VERIFIED**

Branch: `refactor/phase0-phase1-baseline`

Date: 2026-08-05

This record does not claim that authentication, Supabase, RLS, moderation, or
store release is production-ready.

## Before

- Clean tests failed because an uncommitted `.env` asset was mandatory.
- Analysis contained 51 compile-time errors among 70 findings.
- Imports, repository/model contracts, admin calls, and tests were stale.
- The repository treated an uninitialized Supabase client as permission to use
  in-memory fixture records.
- Demo login accepted any non-empty password for a known email.
- Client role mutation and role-selection UI existed.
- Several controls claimed reset, deletion, guide navigation, reporting, or
  blocking success without completing a safe backend operation.
- CI did not target `master`.

## After

- Approved product, requirement mapping, status, deferred, risk, and ADR
  documents are versioned and distinguish current from target behaviour.
- `.env` is no longer a required asset; compile-time defines are documented.
- Demo mode requires `APP_ENV=demo`, is visibly bannered, and is rejected in
  release builds.
- An unconfigured repository throws rather than returning fixture data.
- Staging/production remains deliberately unavailable until Phase 2 is
  authorized and implemented.
- Demo accounts require the shared synthetic fixture password
  `123456`; public registration always creates a tourist.
- Client role switching and unsafe role-escalation tests are removed.
- Fake/incomplete actions are removed or honestly marked unavailable.
- Suspended live-login rejection signs out the Supabase session in the
  compatibility auth service; complete enforcement remains Phase 3 work.
- Silent itinerary fallback to KL Sentral is removed.
- CI targets `master`, checks formatting, analyzes, tests, and builds an
  explicit-demo Android debug APK.

## Verification

```text
dart format --output=none --set-exit-if-changed lib test
Formatted 54 files (0 changed)

flutter analyze --no-pub
No issues found! (ran in 36.0s)

flutter test --no-pub --dart-define=APP_ENV=demo
20 tests passed

flutter build apk --debug --no-pub --dart-define=APP_ENV=demo
Built build/app/outputs/flutter-apk/app-debug.apk in 126.5s
```

The Android build emitted three upstream Java compiler warnings that source and
target value 8 are obsolete. These did not fail the build and remain a release
toolchain warning for the later platform phase.

## Temporary compatibility code

- `DiscountCodeModel.isActive` preserves the prototype suspension/display
  contract. It is marked for replacement by the approved Phase 7 discount
  lifecycle.
- `SupabaseRepository` remains centralized in Phase 1. It now requires explicit
  configuration, but narrow feature repositories are deferred to later phases.
- Client-role parameters remain in legacy admin/spot service signatures for
  demo compilation only. They are not production authorization and must be
  replaced by authenticated database RPC/RLS checks.
- Staging/production bootstrap is intentionally fail-closed rather than
  partially activating the incomplete schema.

## Explicit exclusions

- no schema or RLS migrations;
- no live Supabase initialization, deployment, data read, or data write;
- no authentication/session gate implementation;
- no influencer application;
- no deletion/retention job;
- no secure moderation workflow;
- no push notifications;
- no state-management migration;
- no broad UI redesign;
- no iOS project or production release configuration.

## Manual checklist

1. Run `flutter run --dart-define=APP_ENV=demo` and confirm the `DEMO` banner.
2. Confirm a run without `APP_ENV` shows the configuration failure screen.
3. Confirm a release build cannot select demo mode.
4. Log in to `tourist@livelocal.com` with a wrong password and confirm failure.
5. Log in with `123456` and confirm the tourist fixture account.
6. Register a demo account and confirm it is a tourist with no role picker.
7. Confirm Google login is absent and password reset is honestly unavailable.
8. Confirm account deletion states that no data was deleted.
9. Confirm guide navigation, reporting, and blocking do not claim success.
10. Deny location and confirm no silent KL Sentral itinerary is generated.
11. Browse spots, LocalEats, guides, saves, and reviews in explicit demo mode.
12. Confirm the Android debug APK installs and displays the demo marker.

## Database confirmation

No Supabase production or staging project was contacted. No database data,
schema, migration, storage policy, or RLS policy was created, changed, or
applied in Phase 0 or Phase 1.
