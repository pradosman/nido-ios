# Calendar validation follow-up

Status: in progress. This record preserves failed evidence; it is not a completion certificate.

## Verified findings

The clean, uninstrumented calendar initially placed the selected day outside its usable viewport. In `cleanred/original505-cleanred.xcresult`, the selected day occupied y30.58–89.08 while the scroll viewport began at y62 and the navigation bar occupied y78–132. The initial-visibility assertion failed. This is a product defect independent of the diagnostic probes.

A diagnostic trial measured the initial scroll request with an observed viewport of 12 × 0 points. A positive viewport arrived later. This supports waiting for an available viewport before making the single initial request; it does not prove final layout stability.

The clean viewport-ready candidate made the selected day visible and hittable, but did not pass visual review: part of the preceding month's pinned header remained above the selected month's header. Its complete API test also failed to close the picker after selecting the fixture date.

The latter failure was an occluded test tap, not evidence of a lost unobstructed touch. The synthesized event tapped (145.17, 170.17), the center of the July 15 accessibility frame at y141.7–198.7. The pinned month/weekday band occupied approximately y140–201. The test had excluded only the navigation bar. Its visibility guard must also account for the complete month header.

The historical API failure at y245 remains separate: its captured touch was below the header. These newer findings do not establish the cause of that older event.

## Acceptance and sequence

1. Add a stable identifier to the complete header and strengthen the existing API history test, retaining its initial selected-day and pagination assertions.
2. Capture a failing assertion for the residual previous header before changing the layout. Its relevant boundary is the bottom of the navigation bar, not its top: normal content may render behind the translucent bar.
3. Preserve native pinned month headers, as required by the existing scrolling test. Align the actual full header rather than an external marker; retain the rings, spacing and one initial scroll request after viewport availability.
4. Require the complete focused API case, initial/preselection screenshots and reopening to pass before applying the production change to the repository.
5. Freeze the accepted source and complete all 186 planned native executions, plus core tests, runner contracts and Release verification. Preserve earlier failed results.

An explored normal-month layout was rejected before application because it removed the existing sticky-header behavior. Its scratch artifacts are not part of the accepted implementation.

The full-header diagnostic run measured the previous header at y72.33–142 and the current header at y143–212.67, with navigation-bar bottom y132. The previous header therefore intrudes ten points into usable content. The first added assertion used the navigation bar's top (y78), which was unnecessarily strict; the corrected contract must use its bottom (y132). The measurements still violate that corrected boundary.

The corrected `header-usable-red` run failed exactly that boundary (142 > 132), with no additional failures. The selected day remained visible and hittable. The strengthened pre-tap guard subsequently scrolled to an unobstructed fixture date, closed the picker and loaded the entry beyond the first 500 records. This separates the visual alignment defect from the earlier occluded test tap.

The clean full-header-target candidate passed the entire original API case: 1/1, no skips or runner retries. Its previous header ends at y128, above the usable boundary y132. The current month header occupies y142–211.67; the selected day occupies y358.92–417.42 and is hittable. Before selecting the old fixture date, its cell occupies y333.67–390.67, well below its header at y132–201.67. The picker closes and the beyond-500 entry loads.

Root and an independent reviewer inspected the initial screenshot. Previous-month content remains blurred behind the native translucent navigation bar, which is allowed; no previous-header band remains in usable calendar content. This approval is scoped to that distinction. The unchanged sticky-header and reopening tests, and the full validation gate, remain required.

The two existing follow-up tests then exposed a remaining range-dependent failure. Reopening/cancellation passed, but `testCalendarMonthHeadingStaysPinnedWhileScrollingAcrossMonths` failed before reaching its pinning assertions: its empty, one-year calendar did not expose the selected month's grid on opening. The short-history API green is therefore insufficient. The candidate is not approved for final delivery or the full gate until this existing contract passes.

Changing the Reader target to the Section's known `Date` identity reproduced the same annual-range failure. That alternative was also rejected. Both failed runs show March 2026 although the selected date is October 18, 2026.

A diagnostic-only annual-range run then captured the request before a native scroll view was discoverable in the bounded presented-view subtree. At that request, the observed SwiftUI viewport was 402 × 656 and the content extent was 5777 points. The requested month was October 2026, index 12 of 14, in a range from October 2025 through November 2026. A native calendar scroll view appeared later with content height 5990 and offset 5059.33. The same native instance later had content height 9751 and offset 5150, with no dragging or deceleration. This supports layout-dependent displacement after the one-shot request; it does not demonstrate clamping or identify every internal SwiftUI step.

The selected header/body geometry observed early in that trace is last-known geometry, not its final position after lazy views change. The final video shows March. Diagnostic instrumentation is not a production fix.

The next clean variant restores declarative `scrollPosition`, with a `nil` initial position and one assignment after the viewport becomes available. It passes the annual test's opening and pinned-header assertions, and the separate reopening/cancellation test. The annual test then fails its final selection because its `isHittable`-only loop accepts an offscreen date. Root independently decoded the synthesized event: the September 18 tap is at (234.57, 71.03), above the usable calendar beginning at y132. The video frame shows September 28–30 in usable content, with September 18 hidden. No direct day-frame attachment survived this run; an estimated rectangle is not treated as measured evidence.

The next change is limited to the test's input guard: require a fully visible date below the navigation bar and complete month header before the same single tap. Its initial-position, pinned-header and final expected-date assertions remain intact. This is a test-harness correction, not evidence of a broken product action handler.

## Evidence locations

All paths below are under `/tmp/nido-interaction-boundary-2026-10-18/`:

- `cleanred/original505-cleanred.xcresult`: clean initial-visibility red.
- `reader-anchor1-observability/`: measured zero-height request diagnostic; never accepted as production evidence.
- `viewport-ready/original505-viewport-ready.xcresult`: clean candidate, initial visibility passes but complete case fails.
- `viewport-ready/attachments/C31B5C6A-1469-4180-A3FE-B418A22C09C6.png`: residual previous header.
- `viewport-ready/attachments/F3E29C56-377E-4973-A7E0-6BE8A8E6CF09.png`: fixture date hidden under pinned header before the tap.
- `header-red/original505-header-red.xcresult`: complete header geometry; first assertion was stricter than the intended usable-content boundary.
- `header-red/attachments/B53979B9-46E7-417C-8EAC-9D91CB4FE5FF.txt`: full-header and navigation-bar measurements.
- `header-usable-red/original505-header-usable-red.xcresult`: one failure of the corrected usable-content boundary; subsequent selection and pagination assertions pass.
- `header-usable-red/attachments/C19DDFCE-C269-4C5B-A07C-D5D0CBCF779F.txt`: repeated full-header geometry against the corrected boundary.
- `header-target-ready/original505-header-target-ready.xcresult`: complete focused green.
- `header-target-ready/attachments/5F99BF56-ACBA-4840-85BE-23F945B9B8A1.png`: independently reviewed initial calendar.
- `header-target-ready/attachments/B1988682-A9EF-447F-9F7C-9BE4CBC0DF57.txt`: initial geometry for the accepted candidate.
- `header-target-ready/attachments/A1453768-07BC-499A-8AB9-8879537D2CF0.txt`: unobstructed fixture-date geometry before successful selection.
- `header-target-ready/sticky-focused.xcresult`: existing reopening test passes; one-year calendar opening fails before pinning assertions.
- `section-target-ready/sticky-focused.xcresult`: known Section identity also fails the annual-range opening.
- `section-target-observability/sticky-diagnostic.xcresult`: diagnostic annual-range red, one execution and no skips.
- `section-target-observability/live-logstream.log`: ordered request, geometry and native offset/content-size evidence.
- `declarative-position/sticky-focused.xcresult`: initial annual positioning and pinning pass; final selection exposes an offscreen test tap; reopening test passes.
- `declarative-position/attachments/3E44E111-0152-493B-BAAD-50DA3753FBD2`: synthesized September 18 tap event, independently decoded by root.
- `declarative-position/pre-tap-21.35.png`: September 18 absent from usable content before the tap.
- `cleanup/deriveddata-cleanup.txt`: removal of inactive build outputs only; result bundles and evidence retained, active package checkout preserved.

This document has no executable behavior, so unit TDD does not apply. Validation consists of cross-checking its claims against result bundles, measured geometry and screenshots.
