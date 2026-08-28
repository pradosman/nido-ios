# iOS Apple quality pass

This document is the delivery ledger for the visual, interaction, accessibility, and copy pass requested on 2026-08-28. It is intentionally kept in the repository so each change can be traced to a commit and verified again later.

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
| AQ-01 | Critical | Navigation | Remove the second tab-like quick-capture bar; expose capture as a native action menu. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-02 | Critical | Dynamic Type | Primary tasks remain discoverable and text reflows at accessibility sizes without forced shrinking. | Implemented; visual verification pending | `refactor(ios): adapt flows and accessibility` |
| AQ-03 | Critical | Dark Mode | Surfaces use semantic elevation and no hard-coded glowing white outlines. | Implemented; visual verification pending | `refactor(ios): consolidate visual system and navigation` |
| AQ-04 | Critical | Notices | Notices avoid the Dynamic Island, navigation controls, and tab bar. | Implemented; visual verification pending | `refactor(ios): consolidate visual system and navigation` |
| AQ-05 | Critical | Contrast | Secondary text and controls meet semantic contrast in light, dark, and increased-contrast appearances. | Implemented; visual verification pending | `refactor(ios): consolidate visual system and navigation` |
| AQ-06 | High | Home hierarchy | Daily information and capture actions take precedence over decorative copy. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-07 | High | Typography | Use a small, explicit set of adaptive system text roles. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-08 | High | Titles | Remove one-line shrinking and hard-coded tracking from responsive titles. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-09 | High | Symbols | Normalize symbol weight and variants across tabs and activity categories. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-10 | High | Brand | Stop using an SF Symbol as the Nido brand mark inside the app. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-11 | High | Materials | Use materials and shadows only when they communicate elevation. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-12 | High | Profile action | Remove nested custom circle-and-glass treatment from the toolbar avatar. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-13 | High | Screen consistency | Align Home, History, Rhythms, Settings, and forms to the same spacing and surface system. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-14 | High | Semantics | Separate care-category color from error/destructive color. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-15 | Medium | Access/onboarding | Reduce top-heavy composition and prioritize the active form. | Implemented; visual verification pending | `refactor(ios): consolidate visual system and navigation` |
| AQ-16 | Medium | Sheets | Use content-appropriate detents and system corner treatment. | Implemented | `refactor(ios): consolidate visual system and navigation` |
| AQ-17 | Medium | Inputs | Replace inefficient high-range steppers with direct, repeatable controls. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-18 | Medium | Charts | Show interpretable scales and provide accessible chart summaries. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-19 | Medium | Motion | Respect Reduce Motion consistently across custom transitions. | Implemented | `refactor(ios): adapt flows and accessibility` |
| AQ-20 | Medium | Feedback | Use neutral, success, warning, and error feedback according to meaning. | Implemented | `refactor(ios): adapt flows and accessibility` |
| COPY-01 | High | Microcopy | Remove ornamental or generic copy and standardize concise Spanish terminology. | Implemented | `refactor(ios): adapt flows and accessibility` |

## Verification matrix

| Check | Result | Evidence |
| --- | --- | --- |
| Swift package tests | Pending | — |
| iOS Simulator build without signing | Pending | — |
| iPhone light appearance | Pending | — |
| iPhone dark appearance | Pending | — |
| Accessibility Dynamic Type | Pending | — |
| Reduce Motion code audit | Pending | — |
| Increased Contrast code audit | Pending | — |

## Delivery notes

- Xcode signing and shared-scheme changes that predate this pass are intentionally excluded from its commits.
- Each work unit updates this ledger in the same commit as the implementation it describes.
