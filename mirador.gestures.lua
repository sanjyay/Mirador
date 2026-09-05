-- Mirador Gesture Configuration for Hyprland (Lua)
--
-- 3-Finger Swipe Up   -> Summon Mirador (open in Normal mode, idempotent)
-- 3-Finger Swipe Down -> Dismiss Mirador (cleanly releases screencopy buffers, safe no-op when closed)
--
-- To use this standalone snippet, you can load it in ~/.config/hypr/input.lua:
--   dofile((os.getenv("HOME") .. "/Projects/omarchy_plugins/mirador/mirador.gestures.lua"))
--
-- Or include the lines below directly in ~/.config/hypr/input.lua:

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
