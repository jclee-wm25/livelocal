# ADR-002: Hybrid Feature-First Architecture with Provider Initially

- Status: Accepted
- Date: 2026-08-05
- Implementation status: Implemented incrementally; compatibility remains

## Context

The prototype has a repository spanning nearly every domain, screens that
perform infrastructure work, and controllers that mix state, authorization
assumptions, and error conversion. A wholesale rewrite or state-management
migration would be high risk before behaviour and tests are stable.

## Decision

Adopt a hybrid feature-first structure incrementally:

```text
lib/
  app/
  core/
  features/
    auth/
    profile/
    spots/
    restaurants/
    discounts/
    saved_places/
    itinerary/
    guides/
    reviews/
    notifications/
    moderation/
    admin/
  shared/
```

Each feature should own presentation state, domain contracts, and a narrow data
adapter. Shared code is limited to genuine cross-feature infrastructure and UI
components. Provider remains initially. Repositories expose typed results and
errors. Supabase and demo implementations are distinct adapters.

## Incremental migration rule

- Establish characterization tests first.
- Extract one domain contract at a time.
- Keep compatibility facades only while consumers migrate.
- Mark temporary code with its removal phase and test it where meaningful.
- Do not mix the architecture extraction with the later full visual redesign.

## Consequences

- Narrow feature contracts now own production data access. The old god
  repository was removed after runtime and characterization consumers moved to
  explicit feature adapters.
- State management can be reconsidered only if concrete testability or scaling
  evidence later justifies it.
- Presentation compatibility exports and legacy model locations may remain
  until moving them produces a concrete testing or ownership benefit.
