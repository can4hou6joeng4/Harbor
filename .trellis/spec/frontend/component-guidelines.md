# Component Guidelines

> How components are built in this project.

---

## Overview

<!--
Document your project's component conventions here.

Questions to answer:
- What component patterns do you use?
- How are props defined?
- How do you handle composition?
- What accessibility standards apply?
-->

(To be filled by the team)

---

## Component Structure

<!-- Standard structure of a component file -->

(To be filled by the team)

---

## Props Conventions

<!-- How props should be defined and typed -->

(To be filled by the team)

---

## Styling Patterns

<!-- How styles are applied (CSS modules, styled-components, Tailwind, etc.) -->

(To be filled by the team)

---

## Accessibility

<!-- A11y requirements and patterns -->

(To be filled by the team)

---

## Common Mistakes

<!-- Component-related mistakes your team has made -->

## Scenario: macOS single-key shortcuts and destructive item actions

### 1. Scope / Trigger

- Trigger: adding global or window-level single-key shortcuts in the macOS SwiftUI target.
- Trigger: adding destructive item actions such as delete from list rows, toolbars, menus, or keyboard shortcuts.
- Use a narrow AppKit bridge only for the keyDown capability gap; SwiftUI and `ReaderStore` remain the source of truth.

### 2. Signatures

- AppKit bridge: `KeyboardShortcutMonitor(store: ReaderStore)` installed from the root SwiftUI view.
- Store shortcut actions: `selectNextVisibleItem()`, `selectPreviousVisibleItem()`, `toggleFavoriteOfSelectedItem()`, `requestDeleteSelectedItem()`.
- Destructive action flow: `requestDeleteItem(_:)` -> root `confirmationDialog` -> `confirmPendingDelete()` -> `deleteItem(_:)`.

### 3. Contracts

- Single-key shortcuts must have no command/control/option/shift modifiers.
- Shortcuts must be ignored while editable text input is focused, while a modal/sheet/popover is open, or while a delete confirmation is pending.
- `j` selects the next visible item; `k` selects the previous visible item; boundaries do not wrap.
- `f` toggles favorite for the selected item through store APIs.
- Delete/backspace requests deletion for the selected item, but deletion only executes after confirmation.
- SwiftUI views must not call `ReaderRepository` directly; deletion persists through `ReaderStore.deleteItem(_:)`.
- AppKit event monitors must unregister when their host view leaves the window or is deallocated.

### 4. Validation & Error Matrix

- Focused editable `NSTextView`/`NSTextField`/`NSSearchField` -> pass key event through unchanged.
- Modal, sheet, popover, or pending delete confirmation -> pass key event through unchanged.
- `j`/`k` at the visible-list boundary -> selection stays unchanged.
- Delete with no selected item -> no confirmation request.
- Repository delete failure -> show a user-facing delete failure toast.
- Deleting the selected item -> choose next visible item first, then previous, then `nil` for an empty list.

### 5. Good/Base/Bad Cases

- Good: list context menu and detail toolbar menu both call `requestDeleteItem(_:)`; one root confirmation dialog owns the destructive confirmation.
- Good: keyboard bridge translates keyDown into store actions only after focus/modal checks.
- Base: row click and keyboard navigation share `ReaderStore` selection semantics.
- Bad: deleting directly from a row or toolbar button without confirmation.
- Bad: using SwiftUI `onKeyPress` while the deployment target is macOS 13.
- Bad: leaving an `NSEvent.addLocalMonitorForEvents` token installed after the representable leaves its window.

### 6. Tests Required

- Store tests for memory removal and repository removal after `deleteItem(_:)`.
- Store tests for selected-item replacement: next visible, previous visible, and empty-list `nil`.
- Store tests for shortcut-backed actions: next, previous, favorite toggle, and boundary behavior.
- Existing persistence tests must continue to cover repository-level delete cascade for highlights, tag joins, and FTS rows.
- Manual validation is required for key focus behavior: verify `j/k/f` work in the main reader, and do not fire while search, AI input, or a modal is focused.

### 7. Wrong vs Correct

#### Wrong

```swift
IconButton(icon: "ellipsis", title: "更多") {
    store.deleteItem(item.id)
}
```

#### Correct

```swift
Button("删除", role: .destructive) {
    store.requestDeleteItem(item.id)
}
// Root view owns confirmationDialog and calls store.confirmPendingDelete().
```

## Scenario: SwiftUI onboarding overlays

### 1. Scope / Trigger

- Trigger: adding product onboarding, guided tours, or first-run help in the macOS SwiftUI target.
- Keep onboarding as an app-level overlay; do not introduce third-party onboarding frameworks for lightweight tours.

### 2. Signatures

- Store state: `ReaderStore.onboardingOpen`, `ReaderStore.onboardingStep`.
- Store actions: `openOnboarding()`, `advanceOnboarding()`, `retreatOnboarding()`, `skipOnboarding()`, `completeOnboarding()`.
- View anchors: `view.onboardingTarget(_:)` writes an anchor preference resolved by the root overlay.

### 3. Contracts

- First-run visibility is controlled by a local `UserDefaults` completion flag.
- Manual reopening must reset the step to the first step and close transient overlays such as command palette, add modal, subscriptions modal, settings sheet, typography popover, and pending delete confirmation.
- Guided targets must have a readable fallback when the target is unavailable due to window width or layout state.
- Guided targets that are visible must be exposed with a true transparent spotlight cutout, not by drawing only a border over a full-screen dimming layer.
- Target preferences should resolve in one named root coordinate space owned by `ContentView`; avoid mixing local anchor spaces when the overlay is rendered above multiple columns.
- For small controls in macOS titlebar-adjacent chrome, prefer a stable wrapper or a derived frame from a stable parent over anchoring directly to the `Button`; direct button preferences can resolve with titlebar/safe-area offsets that make the spotlight look misaligned.
- Onboarding copy and target geometry must describe the same visual area. If the target is a toolbar button group rather than a single icon, the copy should say "top/right toolbar area" rather than promising a pixel-perfect icon target.
- The dimming layer may intercept background clicks, but the onboarding card must have a higher z-order and keep its controls directly actionable.
- The primary onboarding control should support `.keyboardShortcut(.defaultAction)` and the skip/cancel control should support `.keyboardShortcut(.cancelAction)`.
- Views must not call capture, feed, or repository services directly from onboarding controls; route state changes through `ReaderStore`.

### 4. Validation & Error Matrix

- First launch with no completion flag -> onboarding opens at the first step.
- Complete or skip -> onboarding closes and persists completion.
- Manual reopen after completion -> onboarding opens again at the first step without clearing the completion flag.
- Target anchor unavailable -> show centered fallback highlight and explanatory copy.
- Target anchor available and intersecting the window -> do not show fallback copy; intersect the target with the overlay bounds before testing size.
- Onboarding open -> single-key reader shortcuts pass through unchanged.

### 5. Good/Base/Bad Cases

- Good: root `ContentView` resolves anchor preferences and owns the overlay z-order.
- Good: spotlight overlays use even-odd fill or equivalent masking so the target content remains readable through a transparent cutout.
- Good: core steps and persistence live in `ReaderStore`, with unit tests for step transitions and completion.
- Base: a feature-specific help entry can call `store.openOnboarding()`.
- Bad: each child view renders its own independent onboarding popover.
- Bad: a full-screen translucent rectangle with only a border around the target; this still visually covers the target.
- Bad: onboarding leaves command palette or destructive confirmation active underneath.

### 6. Tests Required

- Store test for first-run open state and first step.
- Store test for step progression through all steps and persisted completion.
- Store test for manual reopen resetting step and closing transient overlays.
- Manual validation for target placement at minimum and wide window widths.
- Manual validation for every onboarding step: target area is transparent, fallback copy appears only when the target is genuinely missing/offscreen, and default/cancel keyboard actions still work.
- Manual validation should include titlebar-adjacent toolbar targets, because their SwiftUI preference frames can differ from the visible icon position on macOS.
