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
* Owns `gridGeometry` via `WindowGeometry.overviewGridGeometry(...)`.
* Manages `selectedCardIndex`, keyboard shortcuts (arrows, vim keys `h/j/k/l`, `+`, `=`, `Esc`, `Enter`), and drag-and-drop state.
* Renders existing workspaces using `workspaceModel` and dynamic creation slots using `insertionModel`.

### 2. `WorkspaceCard.qml`
* Represents a visual workspace on the monitor.
* Manages card styling:
  * Active workspace: fully opaque (`cardOpacity: 1.0`), border `Color.accent`.
  * Inactive workspaces: slightly dimmed (`cardOpacity: 0.90`), border `Color.menu.border`.
  * Workspace badge: top-left number badge (`1`, `2`, ..., `0` for 10).
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
  * `overviewGridGeometry`: Calculates optimal column/row matrix to maximize card size.
  * `cyclicCardMove`: Implements 2D cyclic keyboard navigation (global continuous horizontal cycle, spatial nearest-center vertical row movement with top/bottom wrap-around).

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
