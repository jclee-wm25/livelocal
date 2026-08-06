# ADR-003: Fail-Closed Mobile Release Boundaries

- Status: Accepted
- Date: 2026-08-05
- Implementation status: Foundation implemented; external release inputs pending

## Context

LiveLocal must support Android and iOS without embedding backend secrets,
silently selecting fixtures, signing production artifacts with debug keys, or
inventing publisher-owned identifiers and legal URLs.

## Decision

- Every build selects demo, staging, or production at compile time.
- Demo is rejected in release. Backend initialization failures stay visible.
- Staging/production require HTTPS except non-release loopback development.
- The app rejects Supabase secret/service-role credentials.
- Mobile auth callbacks use exactly `io.livelocal.app://auth/callback` until an
  approved identifier/domain migration changes all platform/backend records.
- Android release builds require a private release signing configuration and
  never fall back to the debug key.
- iOS and Android source projects are versioned; store identifiers, signing,
  accounts, branded assets, and legal URLs are external release inputs.
- CI verifies both platforms and replays the database, but CI success does not
  authorize deployment or store submission.

## Consequences

- A release attempt intentionally fails until signing is provided.
- Placeholder `com.example` identifiers remain a visible blocker rather than
  falsely claiming publisher domain ownership.
- Local Supabase can use loopback transport only in non-release builds.
- Production telemetry remains absent until its data collection and retention
  are approved.
- Store privacy/legal declarations must be reconciled against the final
  dependency archive and deployed backend.
