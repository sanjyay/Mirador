# Mirador

An external Omarchy Shell plugin that presents a fullscreen overview of
workspaces and their windows. It supports keyboard navigation, window
activation, spatial previews that reflect each window's compositor geometry,
and dragging windows between workspaces.
![Mirador Preview](preview.png)

## What's new in version 2

<details>
<summary><b>Click to expand Version 2.0 Changelog</b></summary>

### 🚀 Key Changes in Version 2.0

* **Spatial Window Previews**: Window previews now preserve their approximate compositor position, size, and stacking order inside each workspace card. Tiled layouts remain recognizable at a glance, and floating windows overlap tiled windows naturally.
* **Preview-First Card Design**: Replaced bulky header text with a compact numeric badge pill in the corner, maximizing preview surface area.
* **Focused Workspace Indicator**: The active workspace is framed with a bright accent border, while inactive cards use dim, subtle outlines to keep visual focus clear.
* **Bar Reserved Area Awareness**: Dynamically detects the Omarchy Bar's position (top, bottom, left, right), size, and visibility (`shell.bar`), positioning cards within the safe usable area so they never overlap the bar.
* **Event-Driven Reactivity**: Listens directly to Hyprland compositor events (`window*`, `workspace*`, `fullscreen`, `changefloatingmode`, `monitor*`) for instant, lag-free UI synchronization without polling.
* **Clean Compositor Blur**: Uses native layer-shell blur (`omarchy-workspace-overview`) with a neutral transparent backdrop for maximum clarity.
* **Automated Unit Tests**: Added a test suite (`tests/tst_windowgeometry.qml`) covering tiling layouts, floating windows, multi-monitor scaling, clamping, and fallback geometry.

---

#### Fullscreen Workspace Overview
![Mirador version 2 fullscreen workspace overview](screenshots/mirador-v2-workspace-overview.png)

#### Spatial Window Previews
![Mirador version 2 showing spatial window previews](screenshots/mirador-v2-spatial-previews.png)

</details>

## Demo


https://github.com/user-attachments/assets/9b103f22-26b8-4e23-a17b-73527a0806c3




## Install

Install through Omarchy:

```bash
omarchy plugin add https://github.com/sanjyay/Mirador.git
```

Alternatively, install it manually by cloning this repository into your
Omarchy plugins directory:

```bash
mkdir -p ~/.config/omarchy/plugins
git clone https://github.com/sanjyay/Mirador.git \
  ~/.config/omarchy/plugins/mirador
omarchy-shell shell rescanPlugins
```

## Launching the overview

The overview can be opened with `Shift+Tab` or a three-finger swipe up on the
touchpad. A three-finger swipe down closes it.

Add the keyboard binding to `~/.config/hypr/bindings.lua`:

```lua
o.bind(
  "SHIFT + TAB",
  "Workspace overview",
  "omarchy-shell shell toggle mirador '{}'"
)
```

Add the touchpad gestures to `~/.config/hypr/input.lua`:

```lua
hl.gesture({
  fingers = 3,
  direction = "up",
  action = function()
    hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell summon mirador '{}'"))
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

You can also open the overview directly from a terminal with:

```bash
omarchy-shell shell summon mirador '{}'
```

The plugin depends only on APIs and shared UI components provided by the
Omarchy Shell. It does not require `hyprexpo`, `hyprpm`, or client polling.

## License

Mirador is available under the [MIT License](LICENSE).
