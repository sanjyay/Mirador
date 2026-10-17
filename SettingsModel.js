.pragma library
function normalized(raw) {
  var source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
  var result = {}
  Object.keys(source).forEach(function(k) {
    if (k !== "__proto__" && k !== "constructor" && k !== "prototype") result[k] = source[k]
  })
  result.cycleUI = ["full", "carousel", "compact"].indexOf(source.cycleUI) >= 0 ? source.cycleUI : "full"
  result.modifier = ["super", "alt", "ctrl"].indexOf(source.modifier) >= 0 ? source.modifier : "super"
  result.backdropDim = typeof source.backdropDim === "number" && isFinite(source.backdropDim) ? Math.max(0, Math.min(0.85, source.backdropDim)) : 0.5
  result.backdropBlur = source.backdropBlur === true
  result.showWindowIdentity = source.showWindowIdentity === true
  result.layoutDensity = ["compact","comfortable","airy"].indexOf(source.layoutDensity) >= 0 ? source.layoutDensity : "compact"
  result.neighborEmphasis = ["quiet","normal","strong"].indexOf(source.neighborEmphasis) >= 0 ? source.neighborEmphasis : "normal"
  result.showShortcutHints = source.showShortcutHints !== false
  result.reducedMotion = source.reducedMotion === true
  return result
}
function parse(text) {
  if (typeof text !== "string" || text.length > 65536) return null
  try {
    var raw = JSON.parse(text)
    return raw && typeof raw === "object" && !Array.isArray(raw) ? normalized(raw) : null
  } catch (error) { return null }
}
function next(value, choices, direction) {
  var index = choices.indexOf(value)
  return choices[(Math.max(0, index) + (direction < 0 ? choices.length - 1 : 1)) % choices.length]
}
function spacingScale(density) {
  return density === "airy" ? 1.5 : (density === "comfortable" ? 1.25 : 1)
}
function neighborOpacity(emphasis) {
  return emphasis === "quiet" ? 0.4 : (emphasis === "strong" ? 0.75 : 0.58)
}
function motionDuration(reduced, milliseconds) {
  if (reduced) return 0
  return typeof milliseconds === "number" && isFinite(milliseconds) ? Math.max(0, milliseconds) : 0
}
