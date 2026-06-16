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
