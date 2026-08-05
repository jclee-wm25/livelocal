# Reproducible Supabase backend

This directory is the source of truth for the LiveLocal database. None of
these files were applied to a remote project during this implementation.

## Local verification

Prerequisites: Supabase CLI and a Docker-compatible runtime.

```sh
supabase start
supabase db reset
supabase test db
```

`supabase db reset` is destructive to the currently linked database. Use a
local project ID and confirm `supabase status` before reset. Never link this
workspace to production for local replay.

## Migration order

1. `202608050001_core_identity.sql` — profiles, server-owned roles, access.
2. `202608050002_account_lifecycle.sql` — settings, audit, deletion, appeals,
   admin account access and session revocation.
3. `202608050003_spots_reviews_moderation.sql` — spot revisions, public
   projections, reviews, rating transactions, reports, storage policies.
4. `202608050004_admin_read_models.sql` — restricted admin queues/read models.
5. `202608050005_creators_restaurants_discounts.sql` — creator application,
   restaurant revisions, social allowlist, discounts and public server time.
6. `202608050006_saved_places_itineraries.sql` — private saves, location
   preferences, itinerary ordering and ownership.
7. `202608050007_guides_notifications_operations.sql` — admin guide revisions,
   in-app notifications, statistics/audit, retention and deletion finalizers.
8. `202608050008_workflow_closures.sql` — general content reports, appeals,
   guide archive, creator discount management, concurrency closures.
9. `202608050009_user_safety_blocks.sql` — private server-derived user blocks
   and viewer-specific public-content filtering.
10. `202608050010_spot_image_rights.sql` — server-required spot photo and
    owner image-rights acknowledgement before moderation submission.
11. `202608050011_owner_content_revisions.sql` — current owner submission read
    models, immutable revisions, withdrawal, draft discard, and restaurant
    image-object enforcement.
12. `202608050012_storage_cleanup_lifecycle.sql` — private object-cleanup queue,
    service-only claim/acknowledgement RPCs, retained-media anonymization,
    stricter delete policies, and two-stage account finalization.

Every application table exposed through the data API has RLS enabled. Flutter
uses only the publishable/anonymous key. Service-role execution belongs only
in a trusted server or scheduled job.

## Tests

`tests/database/` contains ten pgTAP suites. Tests create isolated identities
inside transactions and roll back. They verify guests, tourists, creators,
admins, RLS ownership, direct-write denial, role escalation denial, version
conflicts, report/appeal behavior, and user-block privacy.

The `storage-cleanup` Edge Function is the only production path for queued
physical object deletion/re-homing. It requires both a valid function
invocation JWT and the separately configured `STORAGE_CLEANUP_CRON_SECRET`.
It uses the platform-provided service-role key only inside the server runtime;
that key is never embedded in Flutter. CI type-checks the function with Deno.

CI starts a fresh local Supabase stack, replays every migration, then runs
`supabase test db`. A green Flutter test run does not substitute for this job.

## Required operations

The secured `storage-cleanup` Edge Function and evidence purge must be
scheduled and monitored after an approved deployment. The worker invokes:

- `public.claim_storage_cleanup_jobs(integer)` plus its service-only
  activation/completion/failure handshake;
- `public.finalize_due_account_deletions()`;
- `public.purge_expired_moderation_evidence()`.

See [scheduled jobs](../docs/operations/scheduled-jobs.md). Do not grant either
function to mobile roles or call it from Flutter.
