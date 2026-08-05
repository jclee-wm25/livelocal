# Scheduled account and evidence jobs

Status: **SQL queue and Edge worker implemented; deployment/scheduler not configured**

These jobs are privileged operations. Run them from Supabase Cron, a secured
Edge Function scheduler, or another approved backend worker. Never embed or
use the service-role key in Flutter.

## Storage cleanup and account deletion finalizer

Deploy and invoke `supabase/functions/storage-cleanup` at least daily after
staging replay and destructive-data review. A shorter interval is recommended
so replaced/discarded draft media does not remain longer than necessary.
Require a valid function invocation JWT and set a high-entropy
`STORAGE_CLEANUP_CRON_SECRET`; pass it only as the `x-cleanup-secret` header
from the approved scheduler. Rotate and store it as a server secret.

The worker first calls `public.finalize_due_account_deletions()` to queue known
user-owned objects, claims cleanup jobs, performs copy/delete through the
Supabase Storage API, acknowledges verified outcomes, then calls the finalizer
again. Approved public spot/restaurant media is copied to a random
`retained/` path with platform ownership before database references change and
the user-owned source is deleted. Private and unpublished media is deleted.

The finalizer refuses to delete the auth identity while any Storage object is
still owned by the user or any per-user cleanup job is incomplete. Objects in
an unknown bucket deliberately block finalization for operator review. SQL
never deletes rows from `storage.objects`; direct metadata deletion would
orphan the underlying file.

Before enabling:

- test with representative copies of every owned content state;
- verify storage object cleanup and no identity reconstruction;
- alert on failed jobs, stale processing locks, unknown owned buckets, and due
  deletion requests that remain pending across multiple runs;
- verify retained copies have no `owner_id` and no user identifier in paths;
- confirm the approved deletion/retention policy with legal review;
- export and reconcile due-request counts;
- define operator alerting for partial or failed runs;
- document restoration limits after the grace period.

## Evidence purge

Call `public.purge_expired_moderation_evidence()` daily. The default retention
is read from `app_settings.moderation_evidence_retention_days` and initially
equals 180. Cases on a documented legal hold are excluded.

Before enabling:

- restrict setting changes and hold management to approved operators;
- alert on invalid configuration or sustained zero/abnormal purge counts;
- verify public content is not affected by restricted-evidence purge;
- document the legal-hold release process and audit ownership.

## Deployment rule

Scheduler/function deployment is an external state change and must be
performed only on the explicitly approved staging/production project. Record
project ID, function version, secret rotation owner, schedule, runner identity,
timeout, retry behavior, alert destination, and the first successful run in
the deployment log. Never place `SUPABASE_SERVICE_ROLE_KEY` or the cron secret
in Flutter, source control, logs, or client-visible configuration.
