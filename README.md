# Mirador [![Built for Omarchy: Plugin](https://raw.githubusercontent.com/tcballard/omarchy-badges/75975e5b5bf75e7ede3764bcd2950046f7abfe2c/badges/v1/omarchy-plugin.svg)](https://github.com/tcballard/omarchy-badges)

An external Omarchy Shell plugin that presents a fullscreen overview of
workspaces and their windows. It supports keyboard navigation, window
activation, spatial previews that reflect each window's compositor geometry,
and dragging windows between workspaces.




https://github.com/user-attachments/assets/ea80d328-4e02-4a49-9d36-7638c6312665


## Install

Install through Omarchy:

```bash
omarchy plugin add https://github.com/sanjyay/Mirador.git
```

### Add the keyboard bindings

```lua
-- Super+Tab — carousel cycle
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")

o.bind("SUPER + TAB", "Workspace carousel next", "mirador --cycle-next")
o.bind("SUPER + SHIFT + TAB", "Workspace carousel prev", "mirador --cycle-prev")

-- Alt+Tab — full overview cycle (release Alt to select)
hl.unbind("ALT + TAB")
hl.unbind("ALT + SHIFT + TAB")
o.bind("ALT + TAB", "Workspace overview next",
  [[omarchy-shell shell summon mirador '{"step":1,"modifier":"alt","cycleUI":"full","keybindMode":"cycle"}']])
o.bind("ALT + SHIFT + TAB", "Workspace overview prev",
  [[omarchy-shell shell summon mirador '{"step":-1,"modifier":"alt","cycleUI":"full","keybindMode":"cycle"}']])

-- Required for closing the highlighted window while Mirador owns exclusive
-- keyboard focus. Outside Mirador this retains the normal close behavior.
hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close window", "mirador --close-window")

-- Inside the carousel these select a window by its rendered position.
-- Outside Mirador they retain Hyprland's normal directional focus behavior.
hl.unbind("SUPER + LEFT")
hl.unbind("SUPER + RIGHT")
hl.unbind("SUPER + UP")
hl.unbind("SUPER + DOWN")
o.bind("SUPER + LEFT", "Focus left window", "mirador --window-left")
o.bind("SUPER + RIGHT", "Focus right window", "mirador --window-right")
o.bind("SUPER + UP", "Focus upper window", "mirador --window-up")
o.bind("SUPER + DOWN", "Focus lower window", "mirador --window-down")

-- Navigate to workspaces 1-10, or move the highlighted carousel window.
-- Outside Mirador, switch workspaces or move the active window and follow it.
for workspace = 1, 10 do
  local key = workspace == 10 and "0" or tostring(workspace)
  local keycode = "code:" .. tostring(workspace + 9)
  hl.unbind("SUPER + " .. key)
  hl.unbind("SUPER + " .. keycode)
  hl.unbind("SUPER + SHIFT + " .. key)
  hl.unbind("SUPER + SHIFT + " .. keycode)
  o.bind("SUPER + " .. keycode, "Navigate Mirador to workspace " .. workspace,
    "mirador --workspace " .. workspace)
  o.bind("SUPER + SHIFT + " .. keycode, "Move selected Mirador window to workspace " .. workspace,
    "mirador --move-window-to-workspace " .. workspace)
end

-- Shift+Tab — full overview
hl.unbind("SHIFT + TAB")
o.bind("SHIFT + TAB", "Workspace full overview", "mirador --full")
```

The numeric bindings are required for reliable carousel selection and addressed
window movement: Hyprland can consume its native shortcuts before Mirador sees
them. Keycodes 10–19 match Omarchy's number-row bindings; `0` selects workspace 10.
Add this block only once. Do not also load `mirador.bindings.lua`, which defines
the same close, arrow, and numeric bindings.

Reload Hyprland and confirm that the configuration is valid:

```bash
hyprctl reload
hyprctl configerrors
```

## Optional background blur

Current Omarchy installations may have Hyprland's global blur engine disabled.
To enable Mirador blur, add the following to a user-owned Hyprland Lua config,
such as `~/.config/hypr/looknfeel.lua`:

```lua
hl.config({
  decoration = {
    blur = {
      enabled = true,
    },
  },
})

hl.layer_rule({
  name = "mirador-blur",
  match = { namespace = "^omarchy-workspace-overview$" },
  blur = true,
})
```

Mirador does not modify Hyprland configuration automatically. Do not add this
override to vendor-managed Omarchy files. Enabling the global blur engine makes
Hyprland's blur functionality available system-wide, while the anchored layer
rule matches only Mirador. Apply and validate the user override with:

```bash
hyprctl reload
hyprctl configerrors
```


## What's new

<details>
<summary><b>Version 2.3 — click to reveal all changes</b></summary>

### Carousel Cycle View (Super + Tab)
* **Horizontal workspace strip**: Pressing `Super + Tab` opens a clean horizontal carousel showing only your real open workspaces — no virtual or duplicate slots.
* **Target-first focus**: The *next* workspace (where you are heading) is immediately centered and large when you open the carousel. From workspace 2, workspace 3 is focused right away.
* **Center + side layout**: The selected workspace is rendered large in the center; adjacent workspaces are scaled down and dimmed on either side for spatial context.
* **Workspace number badge**: Each card shows its workspace number badge (1, 2, 3, S…) in the top-left, highlighted in accent colour for the focused card.
* **Selected-window cue**: Window labels stay hidden until selected; the highlighted preview receives an accent border and title so `Super+W` has an unambiguous target.
* **Spatial window navigation**: `Super+Arrow` moves the highlight between applications in the centered workspace using their rendered 2D positions.
* **Bottom indicator strip**: A compact pill row (`1 [2] 3`) at the bottom of the screen shows all workspace numbers and highlights the current selection.
* **Direct number navigation**: Press `Super + <workspace number>` (or `1`–`9`, `0` for 10, `S` for scratchpad) while in the carousel to jump directly to that workspace card. Missing numeric workspaces are created and highlighted as soon as Hyprland publishes them. The Mirador-aware numeric bindings route this through IPC so Hyprland cannot consume the key first.
* **Release to switch**: Releasing `Super` while the carousel is open switches to the highlighted workspace and closes Mirador immediately.
* **Escape to cancel**: Pressing `Escape` closes the carousel without switching.

### Shift + Tab Full Overview
* **Overview binding**: `Shift + Tab` opens the existing full workspace grid (all workspaces, normal Mirador layout) via `mirador --full`.
* **Toggle behaviour**: Press once to open; press again or `Escape` to close — Mirador stays open until explicitly dismissed.
* **All v2.2 features preserved**: Focused mode, drag-and-drop, gestures, wheel navigation, scratchpad, and keyboard controls all work exactly as before.

### Settings
* `cycleUI` field added to `settings.json` — accepts `"full"`, `"compact"`, or `"carousel"`.

</details>

## Previous releases

<details>
<summary><b>Version 2.2.1 — click to reveal all changes</b></summary>

### Opt-in Alt+Tab-Style Hold-to-Cycle Mode
* **Hold Modifier & Step**: Summon and step through workspaces by holding `Super` (or `Alt`/`Ctrl`) and pressing `Tab` (`step: 1`) or `Shift + Tab` (`step: -1`).
* **Release-to-Commit**: Releasing the modifier immediately switches to the selected workspace and dismisses Mirador.
* **Auto-Enabling Payload**: Triggering with `{"step": 1}` or `{"step": -1}` automatically activates cycle mode, or it can be permanently configured via `keybindMode: "cycle"` in `settings.json`.
* **Safe Cancellation**: Pressing `Escape` at any time cancels cycle navigation and dismisses Mirador without switching workspaces.

### Adaptive Normal Overview
* **Equal-Sized Peer Workspaces**: Workspace cards dynamically scale to maximize preview area based on the active workspace count and available screen space, without any dominant cards, side rails, or size distortion.
* **Horizontally Centered Rows**: Incomplete rows are automatically centered, making efficient use of display space and avoiding wasted rigid grid cells:
  ```text
  [ 1 ] [ 2 ]

     [ 3 ]
  ```
* **Rock-Solid Layout Stability**: Workspace card geometry remains fixed and stable during keyboard or mouse navigation—cards never resize, jump, or reflow when the selection moves.

### Focused Overview Mode
* **Deep Workspace Inspection**: Press `Space` or pinch to enter Focused mode, where the selected workspace expands into a primary view occupying ~74% of the usable screen width.
* **Vertical Scrollable Rail**: Secondary workspaces stack neatly in a single column along the right edge.
* **Smooth Rail Scrolling**: Scroll through secondary workspaces using the mouse wheel or touchpad with edge clamping and auto-scroll keeping the active selection in view.
* **Direct Launcher Flag**: Open directly into focused view via `mirador --focused`.

### Natural Gestures & Wheel Navigation
* **Touchpad Gestures**:
  * 3-finger swipe up to summon Mirador; 3-finger swipe down to dismiss.
  * 2-finger pinch in / out to smoothly toggle between Normal and Focused modes.
* **Endless Mouse-Wheel Cycling (Normal Mode)**:
  * `Wheel Down`: advances to the next workspace in global visual read order (`1 → 2 → 3 → 1...`).
  * `Wheel Up`: cycles to the previous workspace in global visual read order (`1 → 3 → 2 → 1...`).
  * Endlessly wraps around edges without getting stuck at row boundaries.
* **Focused-Mode Wheel Navigation**: Wheel scrolling traverses spatial rows or smoothly scrolls the secondary rail.

### Bar-Aware Safe Viewport
* Dynamically detects the Omarchy Bar's geometry on any edge—top, bottom, left, or right.
* Computes an authoritative safe rectangle before laying out cards, ensuring workspace previews expand as large as possible while never rendering under, behind, or overlapping the bar.

### Dedicated Scratchpad Section
* Stashed applications in `special:scratchpad` appear in the overview with a distinct `"S"` badge whenever the scratchpad holds windows, and automatically disappear when empty.
* Parked windows display live spatial previews and can be activated or dragged to and from normal numeric workspaces without disrupting workspace numbering.

### Razor-Sharp Preview Fidelity
* Computes preview boundaries aligned directly to physical device pixels (`WindowGeometry.snapToDevicePixels`).
* Completely eliminates fractional scaling matrices and transform blur for razor-sharp terminal fonts, text, and window borders across standard and HiDPI displays.

</details>

<details>
<summary><b>Version 2.2.0 — click to reveal all changes</b></summary>

### Adaptive Normal Overview
* **Equal-Sized Peer Workspaces**: Workspace cards dynamically scale to maximize preview area based on the active workspace count and available screen space, without any dominant cards, side rails, or size distortion.
* **Horizontally Centered Rows**: Incomplete rows are automatically centered, making efficient use of display space and avoiding wasted rigid grid cells:
  ```text
  [ 1 ] [ 2 ]

     [ 3 ]
  ```
* **Rock-Solid Layout Stability**: Workspace card geometry remains fixed and stable during keyboard or mouse navigation—cards never resize, jump, or reflow when the selection moves.

### Focused Overview Mode
* **Deep Workspace Inspection**: Press `Space` or pinch to enter Focused mode, where the selected workspace expands into a primary view occupying ~74% of the usable screen width.
* **Vertical Scrollable Rail**: Secondary workspaces stack neatly in a single column along the right edge.
* **Smooth Rail Scrolling**: Scroll through secondary workspaces using the mouse wheel or touchpad with edge clamping and auto-scroll keeping the active selection in view.
* **Direct Launcher Flag**: Open directly into focused view via `mirador --focused`.

### Natural Gestures & Wheel Navigation
* **Touchpad Gestures**:
  * 3-finger swipe up to summon Mirador; 3-finger swipe down to dismiss.
  * 2-finger pinch in / out to smoothly toggle between Normal and Focused modes.
* **Endless Mouse-Wheel Cycling (Normal Mode)**:
  * `Wheel Down`: advances to the next workspace in global visual read order (`1 → 2 → 3 → 1...`).
  * `Wheel Up`: cycles to the previous workspace in global visual read order (`1 → 3 → 2 → 1...`).
  * Endlessly wraps around edges without getting stuck at row boundaries.
* **Focused-Mode Wheel Navigation**: Wheel scrolling traverses spatial rows or smoothly scrolls the secondary rail.

### Bar-Aware Safe Viewport
* Dynamically detects the Omarchy Bar's geometry on any edge—top, bottom, left, or right.
* Computes an authoritative safe rectangle before laying out cards, ensuring workspace previews expand as large as possible while never rendering under, behind, or overlapping the bar.

### Dedicated Scratchpad Section
* Stashed applications in `special:scratchpad` appear in the overview with a distinct `"S"` badge whenever the scratchpad holds windows, and automatically disappear when empty.
* Parked windows display live spatial previews and can be activated or dragged to and from normal numeric workspaces without disrupting workspace numbering.

### Razor-Sharp Preview Fidelity
* Computes preview boundaries aligned directly to physical device pixels (`WindowGeometry.snapToDevicePixels`).
* Completely eliminates fractional scaling matrices and transform blur for razor-sharp terminal fonts, text, and window borders across standard and HiDPI displays.

</details>

<details>
<summary><b>Version 2.1.1 — click to reveal all changes</b></summary>

* **Cyclic & Wrap-Around Keyboard Navigation**: Smooth continuous navigation across workspaces using arrow keys or Vim bindings (`h`, `j`, `k`, `l`):
  * **Horizontal Continuous Global Cycling (`Left`/`h`, `Right`/`l`)**: Navigates cards in visual reading order across all rows without getting trapped at row boundaries, wrapping seamlessly from the last workspace back to the first, and vice versa.
  * **Vertical Spatial Row Navigation & Wrapping (`Up`/`k`, `Down`/`j`)**: Moves directly between visual rows, jumping to the card in the target row whose horizontal center is geometrically closest to the current card. Moving Up from the top row wraps around to the bottom row, and moving Down from the bottom row wraps to the top row.
* **Focused Workspace Dimming Contrast**: Inactive workspaces are subtly dimmed (0.90 opacity) while the active workspace stays fully opaque (1.0) with an accent border, keeping all window previews clear and readable while instantly identifying which workspace is currently active.

</details>

<details>
<summary><b>Version 2.1.0 — click to reveal all changes</b></summary>

* **First-Class Drag-to-Create Insertion Cards**: Temporary workspace insertion targets now render as full-sized workspace cards (`InsertionWorkspaceCard`) with matching KDE badges, centered `+` icons, and `"Drop to create WS N"` cues. The overview grid dynamically reflows during drag to give insertion targets proper card presence.
* **Seamless Single-Pull Drag & Drop**: Persistent delegate architecture ensures that window previews and drag sessions remain uninterrupted when the layout expands, allowing windows to be moved to existing or new workspaces on the very first pull.
* **KDE-Style Workspace Number Badges**: Streamlined card headers with clean, prominent number badges (`[1]`, `[2]`, ... `[0]`) in the top-left corner, removing visual clutter and maximizing window preview area.
* **Fast Keyboard Navigation & Activation**: Move card selection smoothly using arrow keys or Vim bindings (`h`, `j`, `k`, `l`) and press `Enter`/`Return` to immediately jump to that workspace and dismiss the overview. Press `+` or `=` to create the next contextual workspace.
* **Crisp, Content-Independent Card Borders**: Dedicated topmost border overlay (`z: 100`) with integer pixel-aligned layout ensures complete, uniform 4-sided borders around all inactive workspaces regardless of dark terminal backgrounds or child preview contents.

</details>

<details>
<summary><b>Version 2 — click to reveal all changes</b></summary>

### 🚀 Key Changes in Version 2.0

* **Spatial Window Previews**: Window previews now preserve their approximate compositor position, size, and stacking order inside each workspace card. Tiled layouts remain recognizable at a glance, and floating windows overlap tiled windows naturally.
* **Conditional Live Window Previews**: Active window previews stream in real time while Mirador is open so typing in terminals, playing videos, and web scrolling update immediately. Live capture shuts down cleanly when Mirador is closed to preserve system and GPU resources without polling.
* **Edge-to-Edge Preview-First Cards**: Window previews now use more than 97% of a default workspace card. Redundant inner frames, wide gutters, reserved header space, and full-width title footers are gone.
* **Overlay Workspace Numbers**: Compact numeric badge pills sit above the preview in the top-left without consuming preview width or height.
* **Floating Window Titles**: Compact, translucent title pills float over the bottom of each preview, size to their content, and elide long titles without changing spatial geometry or interaction hitboxes.
* **Focused Workspace Indicator**: The active workspace is framed with a bright accent border, while inactive cards use dim, subtle outlines to keep visual focus clear.
* **Bar Reserved Area Awareness**: Dynamically detects the Omarchy Bar's position (top, bottom, left, right), size, and visibility (`shell.bar`), positioning cards within the safe usable area so they never overlap the bar.
* **Always-Centered Adaptive Grid**: Evaluates valid row and column arrangements so the complete workspace grid stays centered on landscape, portrait, ultrawide, scaled, and constrained displays—including six-card layouts.
* **Event-Driven Reactivity**: Listens directly to Hyprland compositor events (`window*`, `workspace*`, `fullscreen`, `changefloatingmode`, `monitor*`) for instant, lag-free UI synchronization without polling.
* **Grouped Window Previews**: Hyprland grouped/tabbed windows render as a single spatial container with tab indicators for all group members and live capture for the active member.
* **Optional Compositor Blur**: Exposes a transparent layer-shell surface under `omarchy-workspace-overview`, which Hyprland can blur when configured by the user.
* **Preserved Interaction Model**: Workspace/window clicks, keyboard navigation, active and selected workspace styling, and drag-and-drop movement continue to use the real spatial preview geometry.
* **Reliable Overlay Lifecycle**: Mirador remains loaded as a lightweight shell overlay so repeated open/close cycles map instantly.
* **Expanded Automated Tests**: The test suite covers tiling, floating windows, multi-monitor scaling, clamping, fallback geometry, tiny cards, 1–10 workspace layouts, bar insets, and exact grid centering.

---

#### Fullscreen Workspace Overview
![Mirador version 2 fullscreen workspace overview](screenshots/mirador-v2-workspace-overview.png)

#### Spatial Window Previews
![Mirador version 2 showing spatial window previews](screenshots/mirador-v2-spatial-previews.png)

</details>


## Launching the overview

The overview can be opened with `Shift+Tab` or a three-finger swipe up on the
touchpad. A three-finger swipe down closes it. Pressing `Space` or performing a
two-finger pinch on the touchpad toggles between Normal and Focused overview modes.

Add the keyboard binding to `~/.config/hypr/bindings.lua`:

```lua
o.bind(
  "SHIFT + TAB",
  "Workspace overview",
  "omarchy-shell shell toggle mirador '{}'"
)
```

### Carousel and full overview bindings

Use the complete [installation binding block](#add-the-keyboard-bindings) above
for Super+Tab, Alt+Tab, window selection/closing, and numeric workspace actions.
Do not add a second copy here.

### Changing the keyboard binding

Edit the key combination in the first argument of `o.bind` in
`~/.config/hypr/bindings.lua`. For example, to use `Super+Tab` instead:

```lua
o.bind(
  "SUPER + TAB",
  "Workspace overview",
  "omarchy-shell shell toggle mirador '{}'"
)
```

If the replacement shortcut already has an Omarchy binding, unbind it first.
`Super+Tab`, for example, normally switches to the next workspace:

```lua
hl.unbind("SUPER + TAB")
o.bind(
  "SUPER + TAB",
  "Workspace overview",
  "omarchy-shell shell toggle mirador '{}'"
)
```

To inspect existing shortcuts before choosing one, run:

```bash
omarchy menu keybindings --print
```

Add the touchpad gestures to `~/.config/hypr/input.lua`:

```lua
hl.gesture({
  fingers = 3,
  direction = "up",
  action = function()
    hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell summon mirador '{\"cycleUI\":\"full\",\"keybindMode\":\"normal\"}'"))
  end,
})

hl.gesture({
  fingers = 3,
  direction = "down",
  action = function()
    hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell hide mirador"))
  end,
})
```

Hyprland reloads these files automatically. You can also apply and validate the
configuration manually:

```bash
hyprctl reload
hyprctl configerrors
```

## Keyboard navigation and controls

| Key / Action | Description |
| :--- | :--- |
| `Tab` / `Shift+Tab` | Step forward / backward in carousel cycle mode (hold Super, release to commit) |
| `Super+Arrow keys` | In carousel mode, move the highlighted window within the selected workspace; otherwise use normal Hyprland directional focus |
| `Super+1…9` (`0` for 10) | Navigate the carousel directly; otherwise switch to that desktop workspace normally |
| `Super+Shift+1…9` (`0` for 10) | Move the highlighted carousel window to that workspace; otherwise move the active desktop window and follow it |
| `Left` / `h`, `Right` / `l` | Continuous global cycling across workspaces in visual reading order (wraps around) |
| `Up` / `k`, `Down` / `j` | Move selection between visual rows to closest card by center, wrapping top/bottom |
| `Space` | Toggle between Normal and Focused overview modes (or 2-finger pinch) |
| `Enter` / `Return` | Activate the selected workspace (or scratchpad) and dismiss Mirador |
| `Mouse Wheel` | Endless visual cycle in Normal mode; spatial row move / rail scroll in Focused mode |
| `+` / `=` | Create next contextual workspace |
| `Escape` | Dismiss Mirador (cancels cycle without activation) |
| `Click workspace card` | Switch to workspace (in Focused mode, clicking a rail card promotes it to primary) |
| `Click window preview` | Focus window and dismiss overview |
| `Drag window preview` | Move window to target workspace, scratchpad, or drop onto insertion card |

## CLI and demo recording mode

Mirador includes a `mirador` CLI command:

```bash
mirador              # Toggle Mirador overview (Normal mode)
mirador --full       # Toggle Mirador full workspace overview
mirador --cycle-next # Step forward in carousel cycle mode (Super+Tab)
mirador --cycle-prev # Step backward in carousel cycle mode (Super+Shift+Tab)
mirador --focused    # Open directly in Focused overview mode
mirador --cycle      # Open in cycle mode (step forward)
mirador --compact    # Open in compact cycle mode (experimental)
mirador --carousel   # Open in continuous carousel cycle mode (experimental)
mirador --workspace 5 # Navigate carousel/switch desktop to workspace 5
mirador --move-window-to-workspace 5 # Move selected/active window to workspace 5
mirador --demo       # Open Mirador with on-screen input overlay for demo recordings
mirador --help       # Show command-line help
mirador --version    # Show version information (2.3)
```

### Demo recording mode

Running `mirador --demo` opens Mirador in a session-scoped demo mode that renders a clean on-screen input HUD at the bottom of the overview.

* Shows key combinations (e.g. `←`, `ENTER`, `CTRL + →`, `ESC`) and semantic interactions (e.g. `SWITCH → WS 3`, `DRAG WINDOW`, `MOVE → WS 4`, `NEW WS 2`).
* The overlay is non-interactive, session-only, and displays only interactions received directly by Mirador.
* Normal Mirador invocations (`mirador` or keyboard shortcuts) do not display the demo overlay, and demo state automatically resets when the overview is dismissed.

## License

Mirador is available under the [MIT License](LICENSE).
