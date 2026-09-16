-- Mirador-aware close binding for Omarchy / Hyprland.
--
-- Load this file from ~/.config/hypr/bindings.lua after Omarchy's defaults:
--   dofile("/absolute/path/to/mirador/mirador.bindings.lua")
--
-- Hyprland consumes compositor bindings before an exclusive layer-shell
-- surface receives the key event. Routing the close command through Mirador
-- lets the overlay close an explicitly addressed preview; when Mirador is not
-- open, the command delegates to Hyprland's normal active-window close.

hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close window", "mirador --close-window")

for _, direction in ipairs({ "LEFT", "RIGHT", "UP", "DOWN" }) do
  hl.unbind("SUPER + " .. direction)
end

o.bind("SUPER + LEFT", "Focus left window", "mirador --window-left")
o.bind("SUPER + RIGHT", "Focus right window", "mirador --window-right")
o.bind("SUPER + UP", "Focus upper window", "mirador --window-up")
o.bind("SUPER + DOWN", "Focus lower window", "mirador --window-down")

-- Hyprland cannot infer the highlighted carousel preview because the layer
-- surface owns exclusive keyboard focus. Route workspace moves through
-- Mirador so it can address that preview explicitly. Outside Mirador these
-- retain Omarchy's normal move-and-follow behavior.
for workspace = 1, 10 do
  local key = workspace == 10 and "0" or tostring(workspace)
  local keycode = "code:" .. tostring(workspace + 9)
  hl.unbind("SUPER + " .. key)
  hl.unbind("SUPER + " .. keycode)
  hl.unbind("SUPER + SHIFT + " .. key)
  hl.unbind("SUPER + SHIFT + " .. keycode)
  o.bind(
    "SUPER + " .. keycode,
    "Navigate Mirador to workspace " .. workspace,
    "mirador --workspace " .. workspace
  )
  o.bind(
    "SUPER + SHIFT + " .. keycode,
    "Move selected Mirador window to workspace " .. workspace,
    "mirador --move-window-to-workspace " .. workspace
  )
end
