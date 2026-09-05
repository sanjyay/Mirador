# Testing & Verification Guide — Mirador

This document outlines the testing architecture, automated suites, verification commands, and testing guidelines for contributors and AI agents working on Mirador.

---

## 1. Test Suite Architecture

Mirador utilizes Qt Quick Test (`qmltestrunner`) for fast, deterministic, and headless unit and integration testing. All test files reside in the [`tests/`](../tests/) directory.

| Test File | Target Under Test | Scope & Coverage |
| :--- | :--- | :--- |
| [`tests/tst_windowgeometry.qml`](../tests/tst_windowgeometry.qml) | [`WindowGeometry.js`](../WindowGeometry.js) | Monitor aspect ratio calculations, grid layout distribution (`overviewGridGeometry`), canvas insets (`insetGeometry`), client window projection (`previewGeometry`), fallback tiling (`fallbackGeometry`), 2D cyclic wrap-around navigation (`cyclicCardMove`), and physical pixel snapping (`snapToDevicePixels`). |
| [`tests/tst_windowmodel.qml`](../tests/tst_windowmodel.qml) | [`WindowModel.js`](../WindowModel.js) | Hyprland window group resolution, tab member grouping, address normalization, deduplication, active tab selection, and floating window handling. |
| [`tests/tst_windowpreview_security.qml`](../tests/tst_windowpreview_security.qml) | [`WindowPreview.qml`](../WindowPreview.qml) | Security and resource lifecycle checks: ensuring `captureSource` is explicitly nullified when Mirador is hidden (prevents Hyprland DPMS/hotplug crashes) and enforcing `Text.PlainText` on window titles to neutralize XSS/QML injection. |
| [`tests/tst_workspaceoverview_integration.qml`](../tests/tst_workspaceoverview_integration.qml) | [`WorkspaceOverview.qml`](../WorkspaceOverview.qml), [`WorkspaceCard.qml`](../WorkspaceCard.qml) | Integration checks: contextual next workspace ID calculations, insertion zone layout interleaving, keyboard focus exclusiveness, cyclic navigation integration, active card highlighting, and workspace dimming (0.90 inactive). |
| [`tests/tst_demo_overlay.qml`](../tests/tst_demo_overlay.qml) | [`DemoInputOverlay.qml`](../DemoInputOverlay.qml) | Demo recording HUD: key event formatting, mouse click visualizations, timer dismissals, and payload parsing. |

---

## 2. Running Automated Tests

### Run All Tests
Execute all test files in sequence:

```bash
for f in tests/*.qml; do
  qmltestrunner -input "$f"
done
```

### Run a Specific Test
Run an individual test suite:

```bash
qmltestrunner -input tests/tst_windowgeometry.qml
qmltestrunner -input tests/tst_windowmodel.qml
qmltestrunner -input tests/tst_windowpreview_security.qml
qmltestrunner -input tests/tst_workspaceoverview_integration.qml
qmltestrunner -input tests/tst_demo_overlay.qml
```

### Run a Specific Function in a Test
Filter by test function name:

```bash
qmltestrunner -input tests/tst_windowgeometry.qml -functions test_snapToDevicePixels
```

---

## 3. Manual Live Testing Checklist

Whenever modifying visual components, preview shaders, or navigation logic, verify the running desktop session:

### 1. Plugin Validation & Reload
```bash
# Validate plugin manifest and directory structure
omarchy plugin validate .

# Reload shell with updated code
omarchy restart shell
```

### 2. Summon & Dismiss Checks
* Open via keybinding (`Shift+Tab`), CLI (`mirador`), or gesture (3-finger swipe up).
* Confirm smooth entrance and transparent background overlay (`omarchy-workspace-overview` namespace).
* Dismiss via `Esc`, click on background canvas, or selecting an active window.

### 3. Window Preview Rendering & Sharpness
* Terminal text, browser UI, icons, and 1px borders must be crisp and aligned with physical device pixels.
* No blurry halos or fractional-scaling smearing.
* Active workspace card is fully opaque (1.0); inactive workspaces are subtly dimmed (0.90).
* Selection outline uses `Color.accent` without any fractional magnification (`scale: 1.008` is prohibited).

### 4. Keyboard Navigation (Cyclic 2D Model)
* **Left / Right**: Cycles continuously across the global visual sequence (wrapping from last to first and first to last across all rows).
* **Up / Down**: Moves between visual rows, snapping to the card whose horizontal center (`centerX`) is closest to the current workspace. Wraps between top and bottom rows.
* Insertion cards (`isInsertion: true`) are skipped during keyboard navigation.
* Arrow keys and Vim keys (`h`, `j`, `k`, `l`) produce identical navigation outcomes.

### 5. Window Drag & Drop
* Drag a window preview card:
  * Insertion placeholder cards appear between workspaces and at ends (`+ Drop to create WS N`).
  * Moving over an existing workspace card tints the target card (`validDropTarget`).
  * Dropping onto a workspace moves the window via `hyprctl dispatch movetoworkspacesilent` and leaves Mirador open.
  * Dragging outside or canceling releases the drag state cleanly.

### 6. Display Hotplug & DPMS Safety
* Hide Mirador and verify that `captureSource` on all `ScreencopyView` instances is detached (`null`).
* Simulate DPMS off/on or monitor reconnect to ensure Hyprland screencopy session does not crash.

---

## 4. Testing Guidelines for Agents

1. **Never Break Existing Test Assertions**: If modifying geometry formulas, ensure coordinate invariants and scale relationships remain valid across all outputs.
2. **Add Unit Tests for New Logic**: Any new pure-function calculation in `WindowGeometry.js` or `WindowModel.js` must be accompanied by test cases in the respective `tests/tst_*.qml` suite.
3. **Keep Tests Pure & Headless**: Do not depend on real hardware monitors or running Hyprland daemons in unit tests; mock objects (`targetMonitor`, `targetScreen`, `ipcObject`) are used for deterministic verification.
