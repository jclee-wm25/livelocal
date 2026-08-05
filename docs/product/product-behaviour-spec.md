# LiveLocal Product Behaviour Specification

Status: **APPROVED NORMATIVE BEHAVIOUR — implementation tracked separately**

Approved: 2026-08-05

This document records the approved product direction. It does not assert that
versioned code is deployed or store-approved. Current implementation
status is tracked in [implementation-status.md](implementation-status.md).

Normative terms `MUST`, `SHOULD`, and `MAY` describe target requirements.
Client-side visibility checks never substitute for backend authorization.

## Product boundaries

- Supabase is the only authoritative production backend.
- Android and iOS are the first production platforms.
- Provider remains initially; the target is a hybrid feature-first structure.
- Demo fixtures MUST be explicitly selected and MUST NOT be a production
  fallback.
- Production mutations require a network connection. A future read cache may
  expose stale discovery data only with a visible offline/stale indicator.
- Firebase, Firestore, FCM, payment processing, full offline writes, push
  notifications, social login, verified visits, review photos, and web/desktop
  release are outside the first MVP unless separately approved.

## Roles and account enforcement

Public registration always creates a `tourist`. An `influencer` role is granted
only through an approved influencer application. An `admin` is privately
provisioned and is never publicly selectable. The client MUST NOT assign or
mutate privileged roles.

Account enforcement state overrides role permissions:

- active: normal role permissions;
- email unverified: verification, legal, support, and logout only;
- deletion pending: deletion recovery, legal, support, and logout only;
- temporarily suspended: suspension details, appeal/support, legal/account
  information only;
- permanently banned: appeal/support access as policy permits;
- deleted: no account access.

Backend authorization and row-level security MUST enforce these restrictions.

## Guest and authentication behaviour

Guests may browse, search, and filter approved public spots, restaurants,
guides, ratings, and reviews. Authentication and verification are required for
saves, itineraries, submissions, reviews, reports, influencer applications,
restaurant/discount management, notifications, and account features.

When a guest selects a protected action, the app MUST preserve a safe return
intent, authenticate the user, revalidate authorization and target existence,
then return to the action. Mutations are not automatically submitted after
login without confirmation.

MVP authentication includes email/password registration, email verification
and resend, password reset, secure logout, session restoration/expiry, and
account-enforcement checks. Fake Google login is prohibited.

## Profile and account deletion

Users can view and edit allowlisted own profile fields and manage a validated
avatar. Role, account enforcement, moderation, ownership, and audit fields are
not user-editable. Private email/profile data MUST NOT be exposed through
public author projections.

Deletion requires recent authentication and an explicit consequences screen.
It creates a 14-day grace period, disables the account, revokes sessions, and
blocks new content. During the grace period, secure login routes only to a
deletion-recovery flow where the user may explicitly cancel deletion.

After the grace period, an idempotent privileged job MUST:

- delete the authentication identity and private profile data;
- delete saves, private notifications, preferences, avatars, device tokens,
  and unpublished content;
- delete draft, pending, rejected, and withdrawn content unless held as
  restricted evidence;
- retain approved reviews as authored by `Deleted user` with no profile link;
- retain approved spots with an anonymized submitter;
- retain valid restaurant business information as an unclaimed or
  platform-maintained listing without personal influencer attribution;
- retain valid approved guides with an anonymized creator;
- prevent reconstruction of the deleted identity from retained public data.

## Suspension, ban, and appeals

A temporary restricted suspension revokes sessions, blocks backend writes and
privileged actions, preserves approved public content, pauses active discount
codes, and shows reason, duration, support, and appeal access. A permanent ban
also blocks future normal authentication and removes promotions and
unpublished content. Approved content visibility follows an explicit
moderation decision.

An in-app appeal creates an auditable case related to the enforcement or
moderation decision. It accepts a structured reason and optional explanation,
prevents duplicate active appeals for the same decision, and exposes submitted
status and outcome from restricted states. The centralized external contact is
initially `support@livelocal.app`. UI copy MUST NOT promise a response time and
may state: "We will review your appeal as soon as reasonably possible."

## Moderation evidence retention

Restricted moderation/security evidence is retained for 180 days after case
closure. The duration MUST be configurable. Authorized admins only may access
it; personal data is minimized; automatic deletion follows expiry. A
documented legal or active-investigation hold may override normal expiry. This
policy requires legal review before production launch.

## Influencer applications

An authenticated active tourist may maintain one non-terminal application.
Required data: display name, TikTok or Instagram platform, validated HTTPS
profile URL, approximate follower count, primary category, message, and
creator/community rules agreement.

Lifecycle:

`draft -> submitted -> under_review -> approved | rejected | needs_information | withdrawn`

Approval atomically records the decision, grants the influencer role, writes
an audit record, and creates an in-app notification. Rejection and
needs-information require reasons. Historical decisions are immutable.

## Public content, ownership, and revisions

Spots, restaurants, and guides use stable parent records and immutable
revisions:

- draft: owner-editable and deletable;
- pending: withdrawable; an edit creates a revised draft;
- approved: material edits create a new revision requiring approval while the
  prior approved revision remains public;
- rejected: editable and resubmittable as a new revision;
- archived: read-only unless an authorized moderation action restores it.

Admins moderate but never silently become the content owner. Every decision
records actor, reason where required, timestamp, prior state/version, and audit
history. Conflicting decisions MUST fail rather than overwrite one another.

Only approved revisions are public. Discovery is list-first, works without
location permission, and supports deterministic pagination, search, filters,
and distinct loading, empty, error, and retry states. An optional map must not
block list discovery.

## Spots

Active users may submit spot drafts with identity, category, state/city,
address/location, description, best visiting time, recommendations, rights
confirmation, and at least one server-validated image. Probable duplicates use
normalized name, address, and proximity. Users select the existing listing,
request an admin merge, or provide a justified override; probable matches are
not automatically hard-blocked.

## Restaurants, external links, and discount codes

Only approved influencers can submit and manage their own restaurant listings.
All new listings and material edits require admin approval. Restaurant social
links are restricted to validated HTTPS TikTok and Instagram hosts. Deceptive
hosts and schemes are rejected, and broken links have an auditable report and
removal flow.

For MVP, discount codes are promotional information. They require description,
terms, start, expiry, owner, and an approved owned restaurant. Lifecycle:

`draft -> scheduled -> active -> paused | expired | revoked`

Validity uses server time. Expired, paused, revoked, suspended-owner, or
unpublished-restaurant codes are not public. The UI states that merchant
acceptance is not guaranteed. LiveLocal does not process payment or track
redemption in MVP.

## Saves, itineraries, and location

Active users may privately save an approved spot or restaurant once. Saved
content is presented in a consolidated filterable list, removal is idempotent
with recovery/undo, and unavailable targets are explained rather than hidden.

Location permission is optional and contextual. Users may deny it, select
state/city and starting point manually, and change location later. The app MUST
NOT silently substitute KL Sentral or another location.

MVP itineraries persist selected saves and ordered stops. Route ordering is
described as a suggestion, exposes unresolved locations, supports reordering,
and does not claim optimal road routing.

## Guides

MVP guides are admin-curated only. Admins create/manage drafts; approved guides
are public; revisions and audit history remain mandatory. The data model keeps
a creator/owner field for possible future influencer/community submissions.
No public or influencer guide-submission UI is in MVP.

## Reviews and reports

An active tourist or influencer may write one text review per approved spot or
restaurant. Rating is an integer from 1 to 5. The author may edit or delete the
review; updates record `updated_at` and restricted edit history where needed.
Public rating/count updates are transactional and exclude removed reviews.
Review photos are deferred.

A report creates a pending moderation case. It does not globally hide content
solely because one user reported it. The reporter may personally hide the
content. Duplicate active reports from the same reporter/target are prevented,
reporting is rate limited, and moderators may uphold, dismiss, or escalate.
Actions and evidence are auditable. Removing/restoring a review updates rating
aggregates in the same transaction and notifies the author.

Users may block an account from its published review, spot, or restaurant
content. The backend derives the author from the public target; the client does
not supply an arbitrary account ID. A block is private, does not notify the
blocked account, hides that account's current and future public content for the
blocker, and can be reviewed or undone in account settings.

Before production UGC submission is enabled, approved Terms and Community
Rules MUST define objectionable content and users MUST accept the current
version. A reasonable pre-publication filtering strategy, report path, user
blocking, published support contact, and timely moderation operation are store
release requirements. Legal text and response promises are not invented by the
application.

## Notifications and administration

MVP notifications are private, paginated, in-app records with typed events,
read state, safe destinations, and idempotent creation. Push is deferred. An
action's immediate success state is not duplicated as a notification.

The initial privileged role is `admin`, with permission boundaries that allow
future moderator/super-admin separation. Admin mutations derive the actor from
the backend session, require a reason where consequential, use expected
state/version, and create an audit record in the same transaction. An admin
cannot suspend themselves or delete/demote the last active admin.

## Reliability and honest UI

Network-backed behaviour distinguishes loading, refreshing, empty success,
validation, unauthenticated, unauthorized/enforced, offline/timeout, server
failure, conflict, and success. Production MUST NOT silently substitute demo
data, report success before completion, convert failures into successful empty
results, or show raw backend exceptions.

## Visual direction

The approved direction is **Trustworthy Local Guide**: strong local
photography, restrained deep-green accents, warm neutral surfaces, clear
localization-ready typography, an 8-point spacing system, accessible contrast
and touch targets, limited motion, and standard platform navigation. Creator
styling is confined to LocalEats content. Gradients, glass effects, oversized
cards, autoplay, and decorative animation are used sparingly or not at all.
