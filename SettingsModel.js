.pragma library
function normalized(raw) {
  var source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
  var result = {}
  Object.keys(source).forEach(function(k) {
    if (k !== "__proto__" && k !== "constructor" && k !== "prototype") result[k] = source[k]
  })
  result.cycleUI = ["full", "carousel", "compact"].indexOf(source.cycleUI) >= 0 ? source.cycleUI : "full"
  result.modifier = ["super", "alt", "ctrl"].indexOf(source.modifier) >= 0 ? source.modifier : "super"
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
