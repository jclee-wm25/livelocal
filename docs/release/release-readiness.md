# Mobile release readiness

Status date: 2026-08-05

LiveLocal is not ready for store submission. It has a mobile production
foundation and explicit release gates; generated projects and a debug APK are
not evidence of store readiness.

## Technical foundation present

- Android targets Flutter's API 36 baseline, rejects cleartext release
  traffic, disables app-data backup, uses an optional GPS feature declaration,
  and refuses release signing without private key configuration.
- iOS project supports the auth callback, foreground location and photo
  selection purpose strings, local-network development, and an app privacy
  manifest with no tracking claim and current app data categories.
- Demo is compile-time explicit and rejected in release.
- CI targets `master`, checks format/analyzer/tests/Android, compiles iOS on
  macOS, and replays migrations/RLS tests in local Supabase.
- In-app account deletion request, report, personal hide, user block/unblock,
  moderation, and published support contact paths exist.

Google requires new apps and updates to target Android 16/API 36 from
31 August 2026; the current Flutter baseline provides API 36, but this must be
rechecked at submission time: [Google Play target API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-GB_ALL).

## Release blockers requiring owner/external input

1. Replace `com.example.livelocal` / `com.example.liveLocal` with an approved
   identifier owned by the publisher; update Kotlin package, callback setup,
   Supabase redirect allowlist, and store records together.
2. Provide Apple and Google developer-team ownership, Android upload key/Play
   App Signing plan, iOS signing team/profiles, and protected CI secrets.
3. Replace generated Flutter launcher/launch assets with approved branded
   assets and complete device-density/store screenshot QA.
4. Provide functional HTTPS Terms, Community Rules, Privacy Policy, support,
   and account-deletion URLs under an owned domain. Placeholder or empty sites
   must not be submitted.
5. Complete legal review of the 14-day deletion and anonymized public-content
   retention policy. Apple says account-associated UGC, including reviews,
   should be deleted unless retention is legally required; confirm that the
   approved irreversible anonymization model satisfies review/legal needs:
   [Apple account deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/).
6. Provide a web account-deletion request path. Google requires both an in-app
   path and a functional web resource for apps that create accounts:
   [Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN).
7. Supply approved Terms/Community Rules and versioned acceptance. Current
   creator-rule summary is marked for legal review and is not a substitute.
8. Add an approved pre-publication objectionable-content filtering strategy.
   Reporting, private hide, account blocking, and admin action exist, but Apple
   also requires filtering, reports, blocking, and published contact details:
   [App Review Guideline 1.2](https://developer.apple.com/app-store/review/guidelines/).
9. Create an approved staging Supabase project; replay migrations and pgTAP,
   configure storage, auth redirects, email verification/reset templates and
   SMTP, then complete device integration tests before production.
10. Deploy/configure the storage-cleanup Edge Function and monitor its retry
    queue, account finalizer, unknown-bucket blocks, and evidence purge. No
    remote function, secret, or scheduler was created by this work.
11. Decide on a privacy-reviewed production crash/error reporting provider or
    an explicit no-telemetry launch plan. Raw caught exceptions are not printed
    in release.
12. Complete App Store privacy answers and Google Play Data Safety from actual
    deployed behavior, including Supabase processing, user identifiers, email,
    names, precise/coarse location, photos, UGC, support cases, and product
    interactions. The checked-in iOS manifest is a baseline, not legal advice.

Apple documents that privacy manifests record collected data and required
reason APIs: [Apple privacy manifest documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).

## Internal engineering gates still open

- extract remaining English UI copy into Flutter localization resources and
  test common screens with expanded text;
- decide and test duplicate-merge semantics before exposing an admin merge
  operation; existing selection/discard and justified-override paths remain;
- add the optional read-only discovery cache only with explicit stale state;
- complete migration replay and resolve any PostgreSQL/Supabase version drift
  before calling the backend executable.

## Platform verification still required

### Android

- release identifier/version policy;
- signed AAB and Play App Signing;
- API 36 behavior on supported min/target devices;
- auth email callback from installed release build;
- denied/limited location and photo permission flows;
- process death, session restoration, rotation, large text, keyboard, and
  network interruption;
- Play pre-launch report, content rating, Data Safety, deletion URL, privacy
  policy, support contact, screenshots, and release notes.

### iOS

- macOS CI compile result and on-device archive;
- publisher identifier, team, capabilities, signing and TestFlight;
- auth callback from verification/reset emails;
- privacy report generated from the archived dependency graph, including
  required-reason entries supplied by third-party SDKs;
- permission denial/Settings recovery, large text, VoiceOver, keyboard, scene
  restoration, and network interruption;
- App Privacy answers, age/content rating, UGC review notes, reviewer account,
  deletion flow, support/privacy URLs, screenshots, and release notes.

## Honest exclusions

Push notifications, social login, review photos, payment/redemption tracking,
full offline writes, verified visits, public guide submissions, and web/desktop
release are not part of this release candidate. Read-only offline discovery
cache is also not yet implemented.
