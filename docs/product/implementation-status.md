# Current vs Target Implementation Status

Status date: 2026-08-05

This is an implementation record, not a claim that versioned SQL has been
deployed or that store/legal obligations are complete.

## CURRENT IMPLEMENTATION

### Verified locally

- Flutter 3.44.8 / Dart 3.12.2 dependency baseline.
- Explicit demo, staging, and production configuration. Demo is impossible in
  release; staging/production fail closed without HTTPS backend values.
- Session gate, authentication lifecycle, account state screens, profile,
  avatar, deletion request/recovery, and appeals.
- Feature repository/controller/UI loops for spots, reviews, reports,
  influencer applications, restaurants, discounts, saves, itineraries,
  guides, notifications, and admin operations.
- Trustworthy Local Guide theme and shared loading/empty/error/retry states.
- Android debug build, 48x48 interaction theme test, and text-scaling test.
- iOS source project, deep-link scheme, foreground location/photo purpose
  strings, and privacy manifest.
- 50 passing Flutter unit/widget/characterization tests and zero analyzer
  issues at the latest checkpoint.

### Versioned, not executed in this environment

- Twelve ordered Supabase migrations covering identity, roles, account access,
  deletion/appeal policy, spots, reviews, moderation, creators, restaurants,
  discounts, saves, itineraries, guides, notifications, audit, operations, and
  private user blocking, owner content revisions and withdrawal, and a
  Storage-API-backed cleanup/re-homing lifecycle.
- Every exposed application table enables RLS. Sensitive multi-record changes
  use identity-derived RPCs and expected-state/version checks.
- Ten pgTAP suites cover RLS permission matrices, role escalation denial,
  object ownership, moderation concurrency, account lifecycle, aggregate
  behavior, operational closures, private user blocking, and owner revision
  continuity, cleanup privilege boundaries, and account-finalization blocking.
- A fail-closed server-only Edge Function claims object-cleanup jobs, uses the
  supported Storage API, and acknowledges physical deletion before auth-user
  removal. It is versioned and Deno-checked in CI but not deployed here.

The current machine has no Supabase CLI or Docker runtime, so migration replay
and pgTAP execution are pending CI or an approved local/staging environment.

### Deliberate compatibility

- Provider remains; no state-management migration was performed.
- Some presentation files remain in `screens/` and model compatibility files
  remain in `models/`. Active business/data contracts are feature-owned.
- The former `SupabaseRepository` god repository and unreferenced legacy
  services were removed after active runtime dependencies moved to narrow
  feature adapters. The broad system characterization test now composes those
  explicit demo adapters directly.

## APPROVED TARGET BEHAVIOUR

The normative target remains
[product-behaviour-spec.md](product-behaviour-spec.md). The feature code and
migrations implement the approved first-MVP loops, subject to database replay,
staging integration, operational configuration, and the release blockers
below.

## NOT YET IMPLEMENTED OR EXTERNALLY BLOCKED

- No migration or storage policy has been applied to any remote Supabase
  project by this work.
- No production domain, Supabase project, SMTP sender, Apple/Google developer
  account, app identifier, signing key, or branded store asset is configured.
- Automated deletion/retained-media cleanup and the 180-day evidence purge
  exist, but the Edge Function, secrets, external scheduler, and monitoring
  are not configured on any project.
- Legal Terms, Community Rules, Privacy Policy, consent/version records, and a
  Google-compatible web deletion request page are not supplied.
- Pre-publication objectionable-content filtering is not implemented. Reports,
  personal hide, user blocking, and admin moderation are implemented.
- Production crash/error telemetry is intentionally not selected. Release
  builds do not print raw caught exceptions.
- iOS compilation is delegated to macOS CI and has not been run on this Linux
  host. Signing/on-device tests remain external.
- Read-only offline discovery cache is not implemented. Network mutations fail
  honestly; full offline writes remain deferred.
- English UI copy has not yet been extracted fully into Flutter localization
  resources. Full Bahasa Malaysia support remains deferred, but resource
  extraction and expansion testing are still required before release.
- Duplicate detection supports selecting the existing listing or a justified
  override. A destructive admin merge tool is not implemented and requires
  explicit review-conflict, save, itinerary, audit, and rollback rules.
- Store privacy questionnaires and the iOS privacy manifest require a final
  audit against the deployed backend and exact dependency archive.

## Delivery checkpoints

| Area | Repository state | Remaining gate |
|---|---|---|
| Flutter baseline | Verified | keep CI green |
| Auth/account UI | Implemented | staging email/deep-link integration |
| Database/RLS | Versioned | local replay, pgTAP, staging review |
| Product loops | Implemented | end-to-end staging/device QA |
| Android | Debug verified, API 36 via Flutter | identifier, icon, signing, release QA |
| iOS | Project and CI job added | macOS result, identifier, icon, signing |
| Store/legal | Documented only | owner/legal/external inputs required |

Historical Phase 0/1 evidence remains in
[phase0-phase1-baseline.md](phase0-phase1-baseline.md) and should be read as a
dated baseline, not current product status.
