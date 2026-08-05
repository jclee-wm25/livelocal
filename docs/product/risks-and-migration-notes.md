# Known Risks and Migration Notes

Status: **versioned implementation; no remote migration applied**

## Current release-blocking risks

1. Migrations and pgTAP tests are versioned but unexecuted on this host.
2. No approved staging or production Supabase project has been configured.
3. Store identifiers, signing, publisher accounts, and branded assets are
   placeholders or absent.
4. Terms, Community Rules, Privacy Policy, consent versioning, and external
   account deletion URL require owner/legal input.
5. Account-associated public-content anonymization after deletion requires
   store/legal review, especially for Apple UGC deletion guidance.
6. Reports, personal hide, user blocking, and moderation exist, but an approved
   pre-publication objectionable-content filter does not.
7. Scheduled deletion and evidence-retention functions have no external runner,
   monitoring, or alert destination.
8. Production email verification/reset depends on SMTP/templates and redirect
   configuration that cannot be validated without an approved project.
9. iOS has not compiled on this Linux environment; macOS CI/on-device QA is
   required.
10. No production crash telemetry choice or operational incident plan exists.
11. Exact location can be stored privately with a saved itinerary after
   contextual permission; legal/store disclosures must match deployed use.
12. Read-only offline discovery cache is absent; network failures remain
   visible and recoverable rather than silently using fixtures.
13. English UI strings are not fully extracted into localization resources;
   expansion and locale QA remain before release.
14. Automated duplicate merging is intentionally absent because review/save/
   itinerary conflict and rollback semantics need a separately tested policy.

## Deployment and data migration principles

- Start with a new staging project and replay all migrations from empty state.
- Run every pgTAP suite before loading representative data.
- Do not point legacy prototype data directly at the new schema. Inventory,
  normalize, validate, and import through reviewed scripts with reconciliation.
- Prefer additive import, verified parallel comparison, controlled cutover,
  and rollback. Do not drop source data during first production cutover.
- Recompute ratings/counts from eligible reviews; never trust imported
  aggregate values.
- Map old roles through a private reviewed grant process. Public metadata must
  never grant influencer/admin.
- Validate ownership, content state, timestamps/time zones, duplicate listings,
  storage MIME/size, and object paths before import.
- Preserve immutable moderation history and expected-version counters.
- Test account deletion/anonymization on representative owned content before
  scheduling it against real users.

## Deletion and retention risks

- Approved reviews/spots/guides may remain only after irreversible identity
  removal under the approved policy and successful reconstruction testing.
- Retained restaurants become unclaimed/platform-maintained only while public
  business details are still valid.
- Draft/pending/rejected/withdrawn content is removed unless held as restricted
  evidence.
- Evidence retention defaults to configurable 180 days; legal holds require
  documented actor, reason, lifecycle, and release.
- Finalizer/purge jobs must be repeat-safe, observable, bounded, and recoverable
  from partial infrastructure failure.

## Compatibility removal

The old direct client services, legacy admin repository, and
`SupabaseRepository` god repository were deleted after reference checks and
replacement test success. The broad system characterization test now composes
the same narrow explicit demo adapters used by demo bootstrap.
