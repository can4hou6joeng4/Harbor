# 优化新手引导聚焦对齐与说明

## Goal

Improve the first-run onboarding overlay so each step highlights the exact UI area being discussed and uses concise, task-oriented Chinese copy. The current screenshots show broad or edge-clipped highlight boxes and explanations that do not clearly tell the user what to do next.

## What I Already Know

- The current overlay uses root-level anchor preferences in `OnboardingOverlay.swift`, which is the right architecture for a multi-column SwiftUI window.
- Step 2 currently targets the full sidebar toolbar instead of the add button, making the highlight feel misaligned.
- Step 3 currently targets the entire RSS section, while the copy references the section title and plus button.
- Step 5 has competing `aiSettings` anchors: the sidebar settings button and the entire AI assistant panel. The preference reducer chooses the larger panel, causing a broad clipped highlight at the window edge.
- The previous task already made the scrim use a true transparent spotlight cutout. This task should preserve that behavior.

## Requirements

- Narrow onboarding targets so each step frames the smallest useful UI region:
  - Step 1: the left library sidebar remains a broad navigation-area highlight.
  - Step 2: the add-content plus button is highlighted, not the whole toolbar.
  - Step 3: the RSS section header, including title and plus button, is highlighted rather than the full RSS list.
  - Step 4: the reader area highlight should remain readable and avoid feeling attached to the toolbar edge.
  - Step 5: the AI assistant step should highlight a stable AI panel control/header area instead of an edge-clipped full panel.
- Use per-step spotlight padding and corner radius where needed so button-sized targets and panel/header targets both look intentional.
- Rewrite onboarding messages as short, operation-oriented guidance in Chinese.
- Keep the existing 5-step onboarding flow, `ReaderStore` state machine, keyboard shortcuts, and first-run/manual reopen behavior unchanged.
- Do not introduce a third-party onboarding library.

## Acceptance Criteria

- [ ] Each onboarding step shows a transparent spotlight cutout and amber border aligned to the intended target area.
- [ ] Step 2 frames the plus add button closely.
- [ ] Step 3 frames the RSS header/action area closely.
- [ ] Step 5 no longer frames the whole right AI panel to the window edges.
- [ ] Copy for all five steps is clearer, shorter, and describes the concrete action/location.
- [ ] Existing onboarding store tests continue to pass.
- [ ] `swift build`, `swift test`, and app verification run successfully.
- [ ] Actual app screenshots are reviewed for the onboarding sequence before completion.

## Definition of Done

- Tests and relevant build checks pass, or any inability to run them is recorded.
- Manual visual validation covers all five onboarding steps in the running app.
- No unrelated files or private/sensitive content are included in commits.
- Task is committed, archived, journaled, and pushed if the final diff is clean.

## Technical Approach

- Keep the root `ContentView` overlay preference design and avoid local popovers.
- Add target placement refinements in the existing onboarding components rather than changing `ReaderStore`.
- Let `SidebarSection` expose an optional header-level onboarding target so the RSS step can bind to the header row.
- Derive the add-content spotlight from the stable sidebar frame so macOS titlebar chrome offsets do not make the small plus target look misaligned.
- Move the AI onboarding target to the AI panel header/tab region and remove the broad full-panel anchor.
- Add per-step overlay presentation settings to `ReaderOnboardingStep` for padding and corner radius.

## Decision (ADR-lite)

**Context**: The screenshot issues come from target anchors being too broad or competing, not from the state machine.

**Decision**: Preserve the current overlay architecture and refine target anchors plus per-step spotlight styling.

**Consequences**: The fix stays localized to SwiftUI views. Future onboarding steps should attach anchors to the smallest stable visual element matching the copy, not to an entire column by default.

## Out of Scope

- Changing the number or order of onboarding steps.
- Redesigning the onboarding card visuals beyond target alignment and copy.
- Adding analytics, persistence changes, or a new onboarding framework.
- Changing RSS subscription modal behavior.

## Technical Notes

- Relevant files:
  - `Sources/ReaderMacApp/Views/OnboardingOverlay.swift`
  - `Sources/ReaderMacApp/Views/SidebarView.swift`
  - `Sources/ReaderMacApp/Views/AIAssistantView.swift`
  - `Sources/ReaderMacApp/Views/ReaderDetailView.swift`
- Relevant specs:
  - `.trellis/spec/frontend/component-guidelines.md`, scenario "SwiftUI onboarding overlays"
  - `.trellis/spec/guides/index.md`
