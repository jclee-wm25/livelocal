# Current vs Target Implementation Status

Status date: 2026-08-05

This file deliberately separates the prototype from approved future behaviour.

## CURRENT IMPLEMENTATION

- Flutter/Provider prototype with discovery, detail, saved, itinerary, guide,
  profile, review, restaurant, and admin screen concepts.
- A centralized repository attempts Supabase access and otherwise uses
  process-memory seed lists.
- Application startup currently enters the home route rather than using a
  complete session gate.
- Authentication, roles, suspension, deletion, notifications, moderation,
  restaurant/discount contracts, and RLS are incomplete or unsafe.
- The database policy SQL is not a complete deployable schema/migration set.
- The pre-Phase-1 baseline does not compile or test successfully from a clean
  checkout.
- There is no iOS project. Android release configuration is not production
  ready.

## APPROVED TARGET BEHAVIOUR

- Supabase-only production backend with explicit demo/staging/production.
- Public approved browsing and protected-action authentication return flow.
- Tourist-only public signup; approved influencer applications; privately
  provisioned admins.
- Server-enforced account status, RLS, ownership, concurrency, and audit.
- Revision-based content moderation and transactional review aggregates.
- Fourteen-day deletion grace period with content-type-specific anonymization.
- Temporary suspension, permanent ban, and auditable appeal/support cases.
- Android and iOS production release after security and feature phases.

See [product-behaviour-spec.md](product-behaviour-spec.md).

## NOT YET IMPLEMENTED

The approved target items above remain planned until their corresponding phase
is implemented and verified. In particular, Phase 0/1 do not make the
following production-ready:

- Supabase schema, migrations, RLS, storage policies, or RPCs;
- authentication/session/account lifecycle;
- influencer applications;
- content revisions or safe admin moderation;
- deletion jobs, evidence retention jobs, or session revocation;
- transactional ratings;
- appeal/support case handling;
- production offline cache;
- iOS or store release configuration.

## Phase status

| Phase | Status | Meaning |
|---|---|---|
| 0: specification records | Authorized | Documentation only |
| 1: compiling baseline | Authorized | Build/config/contracts/tests only |
| 2: Supabase foundation | Not authorized | No migrations or live project changes |
| 3 and later | Not authorized | No feature/security architecture implementation |
