# Revised Requirements and FR01-FR64 Mapping

Status: **APPROVED REQUIREMENTS — implementation varies by release gate**

The original requirements remain historical source material in
[`LiveLocal.md`](../../LiveLocal.md). This document supersedes their product
interpretation without claiming implementation completion.

## Revised requirement catalogue

| Domain | Revised target requirements |
|---|---|
| Environment | `SYS-01` Supabase-only production; `SYS-02` explicit demo/staging/production; `SYS-03` no production demo fallback; `SYS-04` honest typed UI states |
| Access | `ACS-01` public approved browsing; `ACS-02` authentication for personal/UGC actions; `ACS-03` protected-intent restoration; `ACS-04` server-enforced account status |
| Authentication | `AUT-01` tourist-only registration; `AUT-02` email verification/resend; `AUT-03` secure email/password login; `AUT-04` session restoration/expiry/logout; `AUT-05` password reset; `AUT-06` no client role mutation |
| Account | `ACC-01` allowlisted profile editing; `ACC-02` validated avatar; `ACC-03` 14-day deletion/recovery; `ACC-04` type-specific purge/anonymization; `ACC-05` temporary suspension/permanent ban; `ACC-06` appeal/support cases |
| Influencer | `INF-01` application fields; `INF-02` immutable lifecycle/history; `INF-03` atomic approval/role grant; `INF-04` revision/resubmission |
| Spots | `SPT-01` approved paginated discovery; `SPT-02` search/filter/detail; `SPT-03` owned drafts/revisions; `SPT-04` validated media; `SPT-05` duplicate handling; `SPT-06` audited concurrent moderation |
| Restaurants | `EAT-01` approved creator listings; `EAT-02` filters/detail/recent review ordering; `EAT-03` owner-only revisions; `EAT-04` admin approval; `EAT-05` validated TikTok/Instagram links; `EAT-06` duplicate handling |
| Discounts | `DSC-01` owner/approved-restaurant scope; `DSC-02` lifecycle and server-time validity; `DSC-03` visible terms/disclaimer; `DSC-04` no MVP payment/redemption tracking |
| Saves/itinerary | `SAV-01` unique private saves; `SAV-02` consolidated recoverable list; `ITI-01` persistent suggested itinerary; `ITI-02` optional/manual location; `ITI-03` no optimality/silent-fallback claim |
| Guides | `GDE-01` approved public guide browsing; `GDE-02` complete ordered guide detail; `GDE-03` admin-only MVP authorship; `GDE-04` revision/audit history |
| Reviews | `REV-01` public eligible reviews; `REV-02` one editable text review per user/target; `REV-03` transactional aggregates; `REV-04` restricted edit history; `REV-05` review photos deferred |
| Moderation | `MOD-01` pending case, no one-report global hide; `MOD-02` personal hide/block; `MOD-03` duplicate/rate limits; `MOD-04` audited decisions/evidence; `MOD-05` 180-day configurable retention; `MOD-06` transactional content action |
| Notifications/admin | `NOT-01` private in-app history/read state; `NOT-02` typed/idempotent events; `ADM-01` backend authorization; `ADM-02` reason/version/audit; `ADM-03` self/last-admin safeguards; `ADM-04` future permission separation |
| Store compliance | `CMP-01` functional Terms/Community Rules/Privacy/support URLs; `CMP-02` versioned UGC-rules acceptance and objectionable-content filtering; `CMP-03` in-app and web account-deletion request paths; `CMP-04` accurate privacy/data-safety disclosures |

## Original FR mapping

| Original | Revised | Disposition |
|---|---|---|
| FR01 | AUT-01 | Rewritten: every public signup is tourist |
| FR02 | AUT-03 | Retained and secured |
| FR03 | AUT-01, CMP-02 | Expanded validation and UGC-rules consent |
| FR04 | AUT-03 | Retained; passwordless demo matching prohibited in release |
| FR05 | AUT-02, AUT-04 | Expanded lifecycle |
| FR06 | AUT-03, SYS-04 | Rewritten error behaviour |
| FR07 | ACC-01 | Retained |
| FR08 | ACC-01 | Allowlisted own fields only |
| FR09 | ACC-02 | Retained with storage validation |
| FR10 | ACC-03, ACC-04, CMP-03 | Expanded deletion policy and store web path |
| FR11 | ACC-05, ADM-01 | Expanded server enforcement |
| FR12 | INF-01–INF-04 | Replaced role picker with application workflow |
| FR13 | SPT-01, SPT-02 | "Authentic" rewritten as approved/provenanced |
| FR14 | SPT-01 | Retained |
| FR15 | SPT-02 | Retained |
| FR16 | SPT-02 | Retained |
| FR17 | SPT-02 | Retained |
| FR18 | SPT-02 | Expanded state/city/category/price filtering |
| FR19 | SPT-02, REV-01 | Expanded |
| FR20 | SPT-03 | Revision-based submission |
| FR21 | SPT-04 | Server-validated image |
| FR22 | SPT-06 | Backend/audited approval |
| FR23 | SPT-06 | Mandatory reason/version conflict handling |
| FR24 | EAT-01 | Clarified approval and creator attribution |
| FR25 | EAT-02 | Retained |
| FR26 | EAT-02 | Retained |
| FR27 | EAT-02 | Retained |
| FR28 | EAT-02 | Retained |
| FR29 | EAT-01, EAT-02 | Safe creator projection |
| FR30 | EAT-02 | Expanded filtering |
| FR31 | EAT-02 | Rewritten to "Recently reviewed" until trend scoring exists |
| FR32 | EAT-03, EAT-04 | Owner-only, approval required |
| FR33 | EAT-03 | Validated media |
| FR34 | EAT-05 | TikTok/Instagram HTTPS allowlist |
| FR35 | EAT-05 | External-link disclosure/report/removal |
| FR36 | DSC-01 | Owner/restaurant scope |
| FR37 | DSC-02, DSC-03 | Expanded terms/start/expiry |
| FR38 | DSC-02 | Server-time validity |
| FR39 | SAV-01 | Retained and secured |
| FR40 | SAV-02 | One consolidated list |
| FR41 | SAV-02 | Idempotent removal/recovery |
| FR42 | ITI-02 | Optional/manual proximity context |
| FR43 | ITI-01, ITI-03 | Suggested route; no optimality guarantee |
| FR44 | ITI-01 | Persistent itinerary target |
| FR45 | GDE-01 | Retained |
| FR46 | GDE-01 | Retained |
| FR47 | GDE-02 | Clarified ordered content |
| FR48 | GDE-03, GDE-04 | Admin-curated revision workflow |
| FR49 | GDE-04 | Reasoned/audited rejection |
| FR50 | NOT-02 | Approval events retained; trend alerts deferred |
| FR51 | — | Deferred with push/proximity strategy |
| FR52 | ACS-01 | Expanded to guests |
| FR53 | REV-02 | Retained, range constrained |
| FR54 | REV-03 | Transactional server aggregate |
| FR55 | REV-01 | Retained |
| FR56 | REV-02 | One editable review per target |
| FR57 | MOD-01–MOD-04, CMP-02 | Rewritten pending-case and user-safety flow |
| FR58 | ADM-01, ADM-02 | Authoritative statistics/administration target |
| FR59 | MOD-04 | Audited moderation queue |
| FR60 | MOD-06 | Transactional removal/aggregate update |
| FR61 | REV-05 | Deferred; not implemented in first MVP |
| FR62 | NOT-01 | Retained |
| FR63 | — | Removed; use awaited success/error UI |
| FR64 | NOT-02, ADM-02 | In-app admin queue/event; push not implied |

## Removed or superseded claims

- Firebase/Firestore/FCM as current production architecture.
- Automatic seed fallback and "100% offline stability".
- Fake Google login, password-reset, account-deletion, or guide-start success.
- Public role selection/client role mutation.
- "Trending" based only on reversed insertion order.
- Discount codes as guaranteed vouchers/payment instruments.

## New implicit store requirements

`CMP-01`–`CMP-04` do not map cleanly to a single original FR. They are required
because LiveLocal creates accounts, collects personal data, and hosts public
UGC. Their technical foundations are partly implemented, but legal documents,
consent versioning, pre-publication filtering, a deletion website, and final
store disclosures remain release blockers.
