# AGENTS.md — Mirador

This document contains operational instructions, architectural invariants, design principles, and development workflows for AI agents and human developers working on **Mirador**.

---

## 1. Project Mission & Core Principles

> **Core Principle: Mirador is a fast, visually crisp, non-destructive workspace overview for Omarchy on Hyprland.**

* **Crispness & Visual Fidelity**: Previews must remain as sharp as possible. Previews must never be subjected to fractional scaling transforms (`scale: 1.008` is prohibited), and preview boundaries must align to physical device pixels (`WindowGeometry.snapToDevicePixels`).
* **Non-Destructive Compositor State**: Mirador is an overlay (`WlrLayer.Overlay`). It must never alter Hyprland tiling layout, modify window dimensions, or steal persistent window focus while active.
* **Security & Safety Invariant**: Window titles must always be rendered with plain text (`Text.PlainText`). Screencopy capture sources (`captureSource`) must be released to `null` immediately when Mirador is dismissed or hidden to prevent compositor crashes on monitor disconnect or DPMS sleep.
* **Pure Geometry Driven**: Navigation and layout operate on rendered 2D geometry (`x`, `y`, `width`, `height`, `centerX`), never on arbitrary workspace IDs.

---

## 2. Documentation Index

To maintain modularity and prevent file bloat, detailed reference specifications are organized in dedicated documents:

| Document | Purpose |
| :--- | :--- |
| [`docs/architecture.md`](docs/architecture.md) | **System Architecture & Protocol**: Component breakdown, Wayland layer-shell protocol mechanics, Hyprland screencopy bindings, and data flow. |
| [`docs/testing.md`](docs/testing.md) | **Testing & Quality Assurance**: Automated test execution (`qmltestrunner`), test suite coverage map, live testing checklist, and regression matrix. |

---

## 3. Repository Structure

```text
mirador/
├── AGENTS.md                  # This document (executive guidelines & invariants)
├── manifest.json              # Omarchy plugin manifest (schemaVersion: 1)
├── WorkspaceOverview.qml      # Main overlay entry point, grid layout & keyboard catcher
├── WorkspaceCard.qml          # Per-workspace card surface, badge, dimming & preview host
├── WindowPreview.qml          # Window screencopy view, group tab bar & title pill
├── InsertionWorkspaceCard.qml # Drag-and-drop workspace insertion placeholder
├── WindowGeometry.js          # Pure JS: multi-monitor scaling, 2D cyclic move, pixel snapping
├── WindowModel.js             # Pure JS: Hyprland group resolution, address normalization
├── DemoInputOverlay.qml       # Session-scoped demo recording HUD
├── bin/
│   └── mirador                # CLI launcher script (toggle, --demo, --version)
├── docs/
│   ├── architecture.md        # Deep architecture & Wayland protocol specifications
│   └── testing.md             # Automated & manual test procedures
└── tests/
    ├── tst_windowgeometry.qml # Geometry & cyclic navigation unit tests
    ├── tst_windowmodel.qml    # Window group & deduplication unit tests
    ├── tst_windowpreview_security.qml # Security & capture release tests
    ├── tst_workspaceoverview_integration.qml # Integration & UI tests
    └── tst_demo_overlay.qml   # Demo overlay unit tests
```

---

## 4. Operational Invariants & Rules of Engagement

1. **Inspect Before Changing**:
   Before modifying any file, inspect the existing implementation and run the test suite. Do not assume or guess Quickshell or Hyprland APIs.

2. **Run Tests After Every Change**:
   Execute `for f in tests/*.qml; do qmltestrunner -input "$f"; done`. All 51+ unit tests must pass cleanly before any commit.

3. **Preserve Rendering Sharpness**:
   * Never re-introduce `scale: 1.008` or any fractional transformation matrices on `WorkspaceCard.qml` or `WindowPreview.qml`.
   * Always pass computed preview geometries through `WindowGeometry.snapToDevicePixels(val, dpr)`.
   * Keep `ScreencopyView` anchored cleanly (`anchors.fill: parent`) without redundant nested JavaScript aspect-ratio recalculations.

4. **Preserve Resource Release on Dismiss**:
   * `WindowPreview.qml` must ensure `captureSource` is `null` when `liveCaptureEnabled` is false.
   * Failure to release `captureSource` on hidden views leads to fatal Hyprland SIGSEGV crashes during monitor hotplug and DPMS power-cycling.

5. **Maintain 2D Cyclic Navigation Model**:
   * **Left / Right**: Cycles continuously across the global visual sequence (1 → 2 → ... → N → 1).
   * **Up / Down**: Moves between visual rows, selecting the card whose `centerX` is closest to the current workspace, wrapping between top and bottom rows.
   * Insertion cards (`isInsertion: true`) must always be skipped during keyboard navigation.

6. **Preserve Security Sanitization**:
   * Window titles must use `textFormat: Text.PlainText`. Never switch to `Text.StyledText` or `Text.RichText`.

7. **Git & Branch Discipline**:
   * Never push directly to `main`.
   * Never merge pull requests unless explicitly instructed by the user.
   * Use clean conventional commit messages (`feat(...)`, `fix(...)`, `docs(...)`, `test(...)`).

---

## 5. Development & Verification Commands

```bash
# 1. Run all unit tests
for f in tests/*.qml; do qmltestrunner -input "$f"; done

# 2. Validate plugin structure
omarchy plugin validate .

# 3. Test live in desktop shell
omarchy restart shell

# 4. Summon / Toggle via IPC
omarchy-shell shell toggle mirador '{}'
omarchy-shell shell summon mirador '{"demo":true}'
omarchy-shell shell hide mirador
```
