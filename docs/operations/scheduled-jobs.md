# Scheduled account and evidence jobs

Status: **implemented as SQL functions; scheduler not configured**

These jobs are privileged operations. Run them from Supabase Cron, a secured
Edge Function scheduler, or another approved backend worker. Never embed or
use the service-role key in Flutter.

## Account deletion finalizer

Call `public.finalize_due_account_deletions()` at least daily after staging
replay and destructive-data review.

The function selects due 14-day deletion requests, removes private account
data and unpublished content, anonymizes retained approved public content by
content type, detaches retained valid restaurant information, removes the auth
identity, and writes restricted audit evidence. It is designed to be
repeat-safe for completed requests.

Before enabling:

- test with representative copies of every owned content state;
- verify storage object cleanup and no identity reconstruction;
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

Scheduler creation is an external state change and must be performed only on
the explicitly approved staging/production project. Record project ID,
schedule, runner identity, timeout, retry behavior, alert destination, and the
first successful run in the deployment log.
