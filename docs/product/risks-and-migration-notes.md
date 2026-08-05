# Known Risks and Migration Notes

Status: **PLANNING RECORD — NO MIGRATIONS HAVE BEEN CREATED OR APPLIED**

## Release-blocking current risks

1. The prototype does not begin from an authenticated/session-resolved route.
2. Demo login historically accepts a known email with any non-empty password.
3. Client role mutation and profile policies can enable privilege escalation.
4. Suspended Supabase sessions are not reliably revoked or denied by RLS.
5. Supabase initialization and documentation disagree; production/demo modes
   are not safely separated.
6. The repository centralizes unrelated domains and contains model/schema drift.
7. The SQL policy file is not a reproducible schema and omits protected data.
8. Ratings and multi-record moderation operations are not transactional.
9. Account deletion/reset/reporting contain prototype-only or unsafe behaviour.
10. Android/iOS/CI/test baselines are not release ready.

## Planned migration principles

- No destructive database migration is authorized in Phase 0 or Phase 1.
- Phase 2 must start from a staging project and reproducible versioned schema.
- Prefer additive tables/columns, backfill, verified parallel reads, then a
  controlled cutover; do not drop legacy data in the same step.
- Parent records and immutable content revisions replace in-place moderation
  overwrites.
- Role and enforcement data must be separated from user-editable profile data.
- Public views/projections must exclude email, private profiles, drafts,
  evidence, and internal moderation reasons.
- Multi-record privileged operations must use transactional server functions.
- Old timestamp/string IDs require validation and mapping to server UUIDs.
- Existing rating/count values must be reconciled from eligible reviews before
  constraints become authoritative.
- Discount table/model naming and ownership must be normalized before import.
- Upload metadata and object ownership must be inventoried to prevent orphans.

## Deletion and retention migration risks

- Approved reviews/spots/guides may remain only after irreversible identity
  removal and anonymization verification.
- A retained restaurant becomes unclaimed/platform-maintained only while its
  business information remains valid.
- Draft/pending/rejected/withdrawn content is removed after the grace period
  unless subject to evidence/legal hold.
- Evidence retention defaults to a configurable 180 days after case closure;
  legal/active-investigation holds need explicit metadata and release rules.
- Purge jobs must be idempotent, observable, and recoverable after partial
  failure.

## Phase 0/1 compatibility rule

Temporary compatibility code may exist only to reach a compiling baseline. It
must be marked with a future-phase removal note, must not create a role/auth
bypass, and must have a focused test where meaningful. A green Phase 1 build is
not evidence that Supabase, authentication, RLS, deletion, or moderation is
production-ready.
