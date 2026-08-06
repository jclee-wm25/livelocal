# LiveLocal

LiveLocal is a Flutter app for discovering Malaysian local places, creator-led
restaurants, neighbourhood guides, reviews, saves, and itineraries. The
repository now contains a production-oriented mobile foundation, but it has
not been deployed to a production Supabase project or submitted to either app
store.

Current status: **pre-deployment engineering candidate, not a release
candidate**. Flutter analysis, tests, and the Android debug build pass locally.
The iOS project and CI build job exist. SQL migrations and pgTAP RLS tests are
versioned, but could not be executed in the current environment because it has
no Supabase CLI or Docker runtime. See
[implementation status](docs/product/implementation-status.md) and
[release readiness](docs/release/release-readiness.md).

## Implemented product loops

- Guest browsing of approved spots, restaurants, guides, ratings, and reviews.
- Email/password registration, verification/resend, login, logout, password
  reset, session restoration, and protected-action return.
- Tourist-only public signup and server-owned influencer/admin roles.
- Profile/avatar management, 14-day deletion request/recovery, suspension,
  ban, appeal, and support states.
- Revision-based spot and restaurant submission with duplicate hints,
  required photo-rights confirmation, validated images/social URLs,
  owner edit/withdraw/discard flows, moderation reasons, version checks, and
  audit.
- Influencer applications and atomic role grant after admin approval.
- Server-time discount lifecycle with owner and approved-listing restrictions.
- One editable review per user and target, transactional aggregate updates,
  reports, personal hide, private user blocking, and moderation.
- Private saves, manual or optional device location, persisted itineraries,
  and reorderable route suggestions.
- Admin-curated guide revisions, private in-app notifications, statistics,
  account controls, appeals, moderation queues, and audit history.
- Explicit demo/staging/production bootstrap with no release demo fallback.

These capabilities are production-backed only after the migrations are
replayed and verified on an approved non-production Supabase project. The app
does not contain a service-role key and must never be given one.

## Architecture

The active architecture is hybrid feature-first:

```text
lib/
  app/theme/                  shared design tokens and Material theme
  core/                       configuration, errors, routing, validation
  features/<domain>/
    domain/                   models and repository contracts
    data/                     explicit demo and Supabase adapters
    presentation/             Provider state and feature UI
  shared/presentation/        reusable loading, empty, error, retry states
  screens/                    presentation compatibility during migration
  controllers/                compatibility exports for moved controllers
```

Production data flows from UI to Provider controllers, narrow repository
contracts, Supabase adapters, and server-owned RPC/RLS operations. Privileged
identity, ownership, moderation actors, roles, account status, and aggregate
values are never accepted from the Flutter client.

The former god repository and unsafe unreferenced direct-write services were
removed after their feature adapters and replacement tests were in place.
Remaining presentation/model compatibility code is tracked in the
implementation status.

## Environments

Every run must select an environment. Missing configuration fails closed.

### Explicit local demo

```sh
flutter pub get
flutter run --dart-define=APP_ENV=demo
```

Demo mode is visibly labelled, uses nonpersistent synthetic fixtures, and is
rejected in release builds. It does not simulate unavailable backend security
features such as private user blocks.

### Local or staging Supabase

Copy `config/dart_defines.example.json` to an ignored local file and replace
the placeholders with an approved project URL and publishable/anonymous key:

```sh
flutter run --dart-define-from-file=config/dart_defines.local.json
```

Required defines:

- `APP_ENV`: `staging` or `production`;
- `SUPABASE_URL`: HTTPS, except loopback HTTP in non-release builds;
- `SUPABASE_PUBLISHABLE_KEY`: never a secret/service-role key;
- `AUTH_REDIRECT_URL`: `io.livelocal.app://auth/callback`;
- `SUPPORT_EMAIL`: centralized support contact.

There is no automatic fallback to demo data after a backend failure.

## Local Supabase

With the Supabase CLI and Docker available:

```sh
supabase start
supabase db reset
supabase test db
```

`db reset` destroys the linked local database. Do not run it against a linked
production project. Migration details and operational jobs are documented in
[supabase/README.md](supabase/README.md).

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --dart-define=APP_ENV=demo
flutter build apk --debug --dart-define=APP_ENV=demo
```

CI repeats those checks, compiles iOS without signing on macOS, replays the
database from empty state, and runs all pgTAP/RLS tests. The workflow targets
the repository's `master` branch.

## Release boundaries

Release signing, final bundle identifiers, branded icons, Apple/Google
accounts, production Supabase/SMTP, legal Terms and Privacy URLs, a web account
deletion resource, store privacy declarations, production telemetry choice,
and scheduled deletion/retention jobs require product-owner or external
configuration. None are fabricated in this repository.

Push notifications, social login, review photos, payment/redemption tracking,
full offline writes, public guide submissions, and web/desktop releases remain
deferred. See [deferred features](docs/product/deferred-features.md).

## Product source of truth

- [Approved behaviour specification](docs/product/product-behaviour-spec.md)
- [Revised FR01–FR64 mapping](docs/product/revised-requirements.md)
- [Current implementation status](docs/product/implementation-status.md)
- [Risks and migration notes](docs/product/risks-and-migration-notes.md)
- [Release readiness](docs/release/release-readiness.md)

All rights reserved.
