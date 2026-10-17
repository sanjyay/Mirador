.pragma library
function rows(presentation) {
  if (presentation === "spread") return [
    {key:"Arrows / H J K L / Tab",action:"Select a window"},
    {key:"Enter / click",action:"Open the selected window"},
    {key:"Z",action:"Enlarge the selected window"},
    {key:"V / Escape",action:"Return to workspace previews"},
    {key:"/",action:"Search open windows"},
    {key:"F1 / F2",action:"Help or Settings"}
  ]
  var result = [
    {key:"Enter", action:"Open the selected workspace or window"},
    {key:"Escape", action:"Cancel and close the overview"},
    {key:"F1", action:"Open or close shortcut help"},
    {key:"F2", action:"Open Settings"},
    {key:"/", action:"Search open windows by application or title"},
    {key:"Z", action:"Enlarge the selected window without changing its size"},
    {key:"V", action:"Spread the selected workspace windows"},
    {key:"← ↑ ↓ → / H J K L", action:presentation === "carousel" ? "Select a window in the highlighted workspace" : "Navigate workspace previews"},
    {key:"Tab / Shift + Tab", action:"Select the next or previous workspace"},
    {key:"+ / =", action:"Create a workspace"}
  ]
  if (presentation === "carousel") {
    result.push({key:"Super + arrows", action:"Select a window in the highlighted workspace"})
    result.push({key:"Super + W", action:"Request closing the selected window"})
    result.push({key:"Super + Shift + 1–0", action:"Move the selected window to a workspace"})
  } else if (presentation === "full") {
    result.push({key:"Mouse drag", action:"Move a window to another workspace or an insertion slot"})
    result.push({key:"Space / pinch", action:"Toggle focused workspace mode"})
  }
  return result
}
function footer(presentation, focused, dragging) {
  if (presentation === "spread") return "Arrows Select window · Enter Open · V / Esc Return · / Search · F1 Help"
  if (dragging) return "Drop on a workspace to move · Release outside to cancel · F1 Help"
  if (presentation === "carousel") return "Tab Cycle · Super + arrows Select window · Enter Open · Esc Cancel · F1 Help"
  if (presentation === "compact") return "Tab Cycle · Enter Open · Esc Cancel · F1 Help"
  return "Arrows Navigate · Enter Open · Space " + (focused ? "Show all" : "Focus workspace") + " · / Search · F1 Help · F2 Settings"
}
