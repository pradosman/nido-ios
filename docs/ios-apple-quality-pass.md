# iOS Apple quality pass

This document is the delivery ledger for the visual, interaction, accessibility, and copy pass requested on 2026-08-28. It is intentionally kept in the repository so each change can be traced to a commit and verified again later.

**Release status (2026-10-08): not yet verified for production.** The simulator, package, and local API checks below passed, but VoiceOver, physical-iPhone behavior, deployed API and real Apple identity integration, and tinted/clear widget appearances still need direct evidence. “Implemented” in the older ledger records a code change, not release acceptance.

## Definition of done

- The app has one clear navigation layer and one clear action layer.
- Core screens remain usable in light mode, dark mode, and accessibility Dynamic Type sizes.
- Colors, surfaces, typography, symbols, motion, and feedback come from shared semantic primitives.
- Frequent capture flows minimize taps and avoid long stepper sequences.
- Status, errors, and destructive actions use distinct visual and haptic semantics.
- Charts expose readable scales and accessible summaries.
- User-facing copy is concise, concrete, and consistent in Spanish.
- The iOS app builds without signing and the Swift package tests pass, apart from any documented environment failure.

## Work ledger

| ID | Priority | Area | Acceptance criterion | Status | Commit |
| --- | --- | --- | --- | --- | --- |
| AQ-01 | Critical | Navigation | Remove the second tab-like quick-capture bar; expose capture as a native action menu. | Verified | `1426e6a` |
| AQ-02 | Critical | Dynamic Type | Primary tasks remain discoverable and text reflows at accessibility sizes without forced shrinking. | Verified | `6f58ab6` |
| AQ-03 | Critical | Dark Mode | Surfaces use semantic elevation and no hard-coded glowing white outlines. | Verified | `1426e6a` |
| AQ-04 | Critical | Notices | Notices avoid the Dynamic Island, navigation controls, and tab bar. | Verified | `1426e6a` |
| AQ-05 | Critical | Contrast | Secondary text and controls meet semantic contrast in light, dark, and increased-contrast appearances. | Verified | `1426e6a` |
| AQ-06 | High | Home hierarchy | Daily information and capture actions take precedence over decorative copy. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-07 | High | Typography | Use a small, explicit set of adaptive system text roles. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-08 | High | Titles | Remove one-line shrinking and hard-coded tracking from responsive titles. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-09 | High | Symbols | Normalize symbol weight and variants across tabs and activity categories. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-10 | High | Brand | Stop using an SF Symbol as the Nido brand mark inside the app. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-11 | High | Materials | Use materials and shadows only when they communicate elevation. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-12 | High | Profile action | Remove nested custom circle-and-glass treatment from the toolbar avatar. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-13 | High | Screen consistency | Align Home, History, Rhythms, Settings, and forms to the same spacing and surface system. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-14 | High | Semantics | Separate care-category color from error/destructive color. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-15 | Medium | Access/onboarding | Reduce top-heavy composition and prioritize the active form. | Verified | `1426e6a` |
| AQ-16 | Medium | Sheets | Use content-appropriate detents and system corner treatment. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-17 | Medium | Inputs | Replace inefficient high-range steppers with direct, repeatable controls. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-18 | Medium | Charts | Show interpretable scales and provide accessible chart summaries. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-19 | Medium | Motion | Respect Reduce Motion consistently across custom transitions. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-20 | Medium | Feedback | Use neutral, success, warning, and error feedback according to meaning. | Implemented | `refactor(ios): adapt flows and accessibility` |
| COPY-01 | High | Microcopy | Remove ornamental or generic copy and standardize concise Spanish terminology. | Implemented | `refactor(ios): adapt flows and accessibility` |

## Verification matrix

| Check | Result | Evidence |
| --- | --- | --- |
| Swift package tests | Passed | 115 tests in the full package run after the compact Today and UI-test updates; isolated scratch was used after a repository-local build database error. |
| Synthetic in-process API contracts | Passed locally | `env -u DATABASE_URL -u NIDO_REAL_POSTGRES_URL -u NODE_ENV node --test tests/nido-households.contract.test.mjs tests/nido-apple-auth.contract.test.mjs tests/apple-session-handler.test.mjs` exited 0: 18 passed, 0 failed, 0 skipped. No deployed HTTP service or real Apple identity was exercised. |
| PostgreSQL-backed API contract | Passed locally | Migrations and `tests/postgres-real.contract.test.mjs` each exited 0 against an isolated ephemeral PostgreSQL 17.10 `tmpfs` container, which was removed afterward. No retained per-test TAP count; no production database, remote credentials, or VPS was used. |
| Local HTTP smoke check | Passed locally | With disposable PostgreSQL 17.10 on `tmpfs`, migrations and `npm run build` exited 0. The local API returned `GET /api/nido/status` 200 with capability flags true, unauthenticated `GET /api/nido` 401, and `POST /api/nido/auth/apple/challenge` 201 with nonempty `challengeID`, `nonce`, and `expiresAt`. API and container stopped with no leftover ports. No Apple session/JWKS, credential-backed invitation, physical iPhone, VPS, or production HTTP was tested. |
| iPhone SE (3rd generation) UI suite | Passed with skips | Fresh isolated iOS 26.5 simulator: `/tmp/nido-au12b-full-se.xcresult`, 41 tests, 38 passed, 3 credential-dependent skips, 0 failures after `73e0e1c`. The circular timeline clears the floating action in idle and active sleep. |
| iPhone 17 Pro UI suite | Passed with skips | Fresh isolated simulator: `/tmp/nido-au12b-full-pro.xcresult`, 41 tests, 38 passed, 3 credential-dependent skips, 0 failures after `73e0e1c`. Neither suite proves real-backend behavior. |
| Snapshot suite | Passed | 2 existing simulator snapshots, including the corrected 280pt/350pt XXXL Today center from AU-4. |
| iOS Simulator build without signing | Passed | `Nido` built for the iPhone 17 Pro simulator after the compact Today and UI-test updates. |
| Modal presentations | Visually covered | All 12 presentations inspected on an isolated simulator; this is visual coverage, not automated accessibility proof. |
| Restore confirmation | Passed in simulator | UI RED found no visible Cancel; `0d198fb` made it visible. Focused GREEN dismissed the alert and retained both synthetic History entries without selecting Restore. |
| iPhone light appearance | Passed in simulator | Existing iPhone 17 Pro inspection; light appearance restored after the Live Activity dark-mode check. |
| iPhone dark appearance | Passed in simulator | Existing screen inspection and 10-hour synthetic Live Activity capture showed a legible, non-ellipsized timer after `8047918`. |
| Accessibility Dynamic Type | Passed for tested flows | Today 280pt/350pt XXXL snapshots and medication form Large/XXXL reachability (2/2 isolated temporary checks). This is not exhaustive coverage of every screen. |
| VoiceOver | Pending | No end-to-end spoken navigation and focus-order verification recorded for this pass. |
| Tinted/clear widget appearances | Pending | No CLI control for these modes was found; the Mac was locked during attempted Simulator UI inspection. No color defect is established. |
| Physical iPhone and deployed API | Pending | No physical-device run, deployed HTTP check, real Apple identity, or credential-backed VPS/server integration was performed in this pass; the local API contract checks above do not cover these boundaries. |
| Reduce Motion code audit | Passed | Custom transitions and animations are conditional on `accessibilityReduceMotion`. |
| Increased Contrast code audit | Passed | Semantic colors provide explicit high-contrast variants through `UIAccessibility.isDarkerSystemColorsEnabled`. |

## Delivery notes

- Xcode signing and shared-scheme changes that predate this pass are intentionally excluded from its commits.
- Recent independent local work units targeting `main`: compact Today timeline clearance `7e75076` and UI-test synchronization `73e0e1c`. This release ledger is a separate documentation follow-up; neither commit has been pushed or opened as a PR in this pass.
- Apple UI follow-up commits: timeline geometry `9f9fa5d`, native tabs `6200318`, Today editing `72f5564`, Today hierarchy `02ca5d1`, History targets `c403835`, compact Live Activity timer `8047918`, and restore cancellation `0d198fb`. AU-7 was read-only verification, not a source change.
- Native RDD review of `7e75076` is **not approved**: risk assessment could not classify the candidate because of untracked-inventory requirements, and committed-only STATUS timed out before native review began (`mutation_outcome: not_started`, `retry_safe: false`). Do not infer review approval from passing tests or retry blindly.
- Release checks remain: VoiceOver on core flows; tinted and clear widget rendering; physical-iPhone Live Activity, widget, notification, Keychain, and restore behavior; and credential-backed invitation/synchronization, offline/reconnection, and permission tests against the real API. Record exact results before marking the definition of done complete.
