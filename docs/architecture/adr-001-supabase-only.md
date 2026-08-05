# ADR-001: Supabase Is the Authoritative Production Backend

- Status: Accepted
- Date: 2026-08-05
- Implementation status: Not yet implemented

## Context

Historical documents mix Firebase, Firestore, Firebase Cloud Messaging, and
Supabase. The prototype also silently falls back to in-memory data when
Supabase is unavailable, which makes production failures look successful.

## Decision

Supabase is the only authoritative production backend. Production uses
versioned PostgreSQL migrations, RLS, Storage policies, and transactional
functions/RPCs. Service-role credentials never ship in the mobile app.

Runtime environment is explicit: demo, staging, or production. Demo uses a
separate fixture adapter and cannot be selected in a release. Production
configuration failure is visible and recoverable, never replaced by fixtures.

Firebase/Firestore/FCM references are historical and will be superseded unless
a specific future service is separately approved.

## Consequences

- Phase 2 must build a reproducible Supabase staging schema before live data.
- Backend authorization derives actor and role from the authenticated context.
- Complex moderation/account/content operations use transactional RPCs.
- RLS and storage authorization receive direct tests in CI.
- Push is deferred and does not justify retaining FCM now.

## Not authorized by this ADR

This ADR does not authorize creating/applying migrations or modifying a live
Supabase project during Phase 0 or Phase 1.
