# Architecture & Protocol Guide — Mirador

This document details the architectural layout, Wayland protocol interactions, Quickshell bindings, coordinate systems, and data pipelines in Mirador.

---

## 1. System Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Wayland Compositor (Hyprland)                   │
│                                                                        │
│  • Workspaces & Windows (toplevel handles, addresses, geometry)        │
│  • hyprland-toplevel-export-v1 (DMA-BUF screencopy frames)             │
│  • wlr-layer-shell-unstable-v1 (overlay surface, exclusive focus)      │
│  • IPC Socket (/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock)   │
└───────────────────▲────────────────────────────────▲───────────────────┘
                    │                                │
                    │ Hyprland Signals               │ Screencopy & Layer Shell
                    │                                │
┌───────────────────▼────────────────────────────────▼───────────────────┐
│                          Quickshell Runtime                            │
│                                                                        │
│  • Quickshell.Hyprland (monitors, workspaces, toplevels, dispatch)     │
│  • Quickshell.Wayland._Screencopy (ScreencopyView, WlBufferQSGNode)    │
│  • WlrLayershell (Layer.Overlay, exclusive keyboard grab, namespace)   │
└───────────────────▲────────────────────────────────▲───────────────────┘
                    │                                │
                    │ QML Bindings                   │ QSG Render Nodes
                    │                                │
┌───────────────────▼────────────────────────────────▼───────────────────┐
│                               Mirador                                  │
│                                                                        │
│  • WorkspaceOverview.qml: Fullscreen overlay panel, grid layout, input │
│  • WorkspaceCard.qml: Per-workspace card surface, badge, dimming       │
│  • WindowPreview.qml: ScreencopyView viewport, group tab bar, title    │
│  • InsertionWorkspaceCard.qml: Dynamic drop target for workspace creation│
│  • WindowGeometry.js: Multi-monitor scaling, projection, 2D cycle, snap │
│  • WindowModel.js: Hyprland group resolution, deduplication, tabs      │
│  • DemoInputOverlay.qml: Key/mouse HUD for recording & demonstrations   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Breakdown

### 1. `WorkspaceOverview.qml` (Entry Point)
* Declares `PanelWindow` anchored to all 4 edges of the target screen.
* Sets `WlrLayershell.namespace: "omarchy-workspace-overview"`.
* Sets `WlrLayershell.layer: WlrLayer.Overlay` and `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`.
* Owns `gridGeometry` via `WindowGeometry.overviewGridGeometry(...)`. Normal full overview uses the target monitor's usable desktop aspect ratio, including reserved areas and QScreen's logical/rotated dimensions. Missing monitor data falls back to screen proportions, then 16:9.
* Normal grid bounds snap inward to the display's physical pixels. Cards retain equal preview sizes (within one physical pixel after rounding), balanced rows, independently centered incomplete rows, and a compact fixed gap. Selection never changes their geometry. Focused and compact layouts retain their own sizing; carousel shares the safe viewport and desktop proportions.
* Manages workspace selection (`selectedCardIndex`), explicit carousel window selection (`selectedWindowAddress`), keyboard shortcuts, and drag-and-drop state. Close and workspace-move bindings resolve this address instead of relying on compositor focus while the exclusive overlay is open.
* Defers release-to-commit for 250 ms so asynchronously launched Hyprland bindings can consume the explicit carousel window selection before the overlay clears it.
* Retains the selected address for a two-second, single-use handoff when release wins the race. A late workspace-move IPC resolves that address directly and never falls back to the compositor's stale active window.
* Treats `Super+Shift+number` as an addressed move chord in carousel mode, preventing the number key from simultaneously navigating the carousel to the destination workspace and erasing the source selection.
* Overrides both key-symbol and physical-keycode forms of Omarchy's workspace-move bindings; the stock bindings use `code:10` through `code:19`, so overriding symbols alone leaves a destructive duplicate action.
* In cycle mode, the carousel selection is authoritative. Compositor workspace events are treated as echoes and cannot bounce selection back to the previously focused workspace while an addressed action is in flight.
* Renders existing workspaces using `workspaceModel` and dynamic creation slots using `insertionModel`.

### 2. `WorkspaceCard.qml`
* Represents a visual workspace on the monitor.
* Manages card styling:
  * Active workspace: fully opaque (`cardOpacity: 1.0`), border `Color.accent`.
  * Inactive workspaces: slightly dimmed (`cardOpacity: 0.90`), border `Color.menu.border`.
  * Workspace badge: top-left number badge (`1`, `2`, ..., `0` for 10). In normal full overview, an opaque badge overlays the preview instead of reserving a header strip.
* Normal-grid preview canvases use a symmetric inset of at least 4 logical pixels (theme-scaled), large enough for the active border, snapped on the destination display. Small viewports reduce chrome and gaps to keep the geometry bounded. Workspaces from differently shaped monitors are fitted uniformly inside the common canvas.
* Hosts `spatialPreview` item where child `WindowPreview` instances are positioned.
* Calculates physical device pixel ratio (`dpr`) from `targetMonitor.scale` or `targetScreen.devicePixelRatio`.
* Positions child window previews using `WindowGeometry.snapToDevicePixels(displayGeometry.*, dpr)`.
* Enforces scale 1.0 (no transform nodes or fractional scale animations) to preserve pixel sharpness.

### 3. `WindowPreview.qml`
* Renders the live screencopy preview of a window or window group.
* Houses `ScreencopyView` with `anchors.fill: parent`:
  * `captureSource`: bound to `root.liveCaptureEnabled ? root.waylandToplevel : null`.
  * **Critical Lifecycle Invariant**: When Mirador is dismissed or hidden, `liveCaptureEnabled` becomes `false`, immediately releasing `captureSource` to `null`. This prevents dangling DMA-BUF handles from crashing Hyprland during DPMS sleep or monitor hotplug events.
* Handles Hyprland window groups (tabbed windows) by rendering an interactive group tab bar.
* Renders window title pills with `Text.PlainText` to neutralize any formatting or injection issues.

### 4. `InsertionWorkspaceCard.qml`
* Transient drop zone card created only during window drag operations.
* Positioned in calculated empty slots (before, between, or after existing workspaces).
* Provides clear visual cues (`+` icon, `Drop to create WS N`) and handles window moves to newly generated workspace IDs.

### 5. `WindowGeometry.js`
* Pure JS geometry engine:
  * `logicalMonitorGeometry`: Computes compositor-space coordinates.
  * `usableMonitorGeometry`: Accounts for top/bottom status bar reservations (e.g. Omarchy peekbar).
  * `workspaceTransform`: Computes uniform scale factor and centering offsets.
  * `previewGeometry`: Projects Hyprland client rectangles into the card preview canvas.
  * `snapToDevicePixels`: Quantizes logical values to physical device pixel boundaries.
  * `workspaceAspectRatio`: Resolves the target desktop proportions without imposing a fixed card shape.
  * `snapRectToDevicePixels`: Snaps rectangle edges together; supports inward snapping for safe bounds.
  * `overviewGridGeometry`: Maximizes common preview area across row counts, without enumerating equivalent row permutations. Its optional seventh argument is the symmetric preview inset; the returned `previewInset`, `previewWidth`, `previewHeight`, and `spacing` describe the effective canvas/chrome. Existing five-argument (spacing) and six-argument (maximum width, spacing) calls retain zero-inset sizing.
  * `cyclicCardMove`: Implements 2D cyclic keyboard navigation (global continuous horizontal cycle, spatial nearest-center vertical row movement with top/bottom wrap-around).

### Carousel presentation (`CarouselCycleView.qml`)
* Sizes the main preview within the target display's usable rectangle while keeping at least 80% of each adjacent card visible when multiple workspaces exist. On a landscape monitor this puts the center card near 46% of the available width. A single workspace uses the larger available area without neighbor or indicator reservations.
* Workspace badges overlay the preview. Source workspaces retain uniform projection even when their monitor differs from the destination display.
* `carouselGeometry` calculates the available canvas; `carouselSlotGeometry` interpolates real card dimensions during scrolling. Cards, canvases, and windows snap to the destination display's physical pixels without texture scaling transforms.
* The indicator strip scrolls horizontally when needed and keeps the selected workspace visible. Navigation, activation, cancellation, and stable preview delegate identity retain their existing behavior.

### 6. `WindowModel.js`
* Hyprland group and client resolver:
  * Resolves clustered window geometries into unified group representations.
  * Groups windows sharing identical compositor positions and active group flags.
  * Normalizes window addresses (`0x...` hex strings).

---

## 3. Wayland & Compositor Protocols

1. **`hyprland-toplevel-export-v1`**:
   Hyprland protocol used by Quickshell to capture DMA-BUF framebuffers of individual toplevel windows. Each buffer is imported into OpenGL/Vulkan via EGL and bound to a `QSGTexture`.

2. **`wlr-layer-shell-unstable-v1`**:
   Used by `PanelWindow` to display Mirador directly over all normal windows on the `Overlay` layer without altering Hyprland tiling state or triggering window resize events.

3. **Compositor Blur Integration**:
   Mirador sets `WlrLayershell.namespace: "omarchy-workspace-overview"`. Users configure Hyprland layer rules targeting this namespace to enable background blur:
   ```ini
   layerrule = blur, omarchy-workspace-overview
   layerrule = ignorealpha 0.85, omarchy-workspace-overview
   ```
