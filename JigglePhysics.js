.pragma library

// Development-only tuning. Translations are logical pixels, published at the
// destination screen's device pixel ratio. Scale and rotation stay neutral.
var tuning = {
  stiffness: 800, damping: 0.6,
  cardImpact: 30.72, cardLimit: 43.008,
  cardRipple: 9.216, departure: 0.6, geometry: 0.35,
  hoverRipple: 3.9936, approach: 48,
  velocityLimit: 1198.08, restPosition: 0.1, restVelocity: 1,
  geometryThreshold: 8, quietMs: 60, maximumBatchMs: 120,
  intentMs: 500, neighbourLimit: 4, carouselNeighbourLimit: 2,
  cardRadius: 1.5, rippleCutoff: 2,
  frameMs: 16
}

function address(value) {
  return String(value || "").toLowerCase().replace(/^0x/, "")
}
function clamp(value, limit) { return Math.max(-limit, Math.min(limit, value)) }
function valid(r) {
  return r && address(r.address) !== "" && r.workspace !== undefined && r.workspace !== null
    && isFinite(r.x) && isFinite(r.y) && isFinite(r.width) && isFinite(r.height)
    && r.width > 0 && r.height > 0
}
function copy(r) {
  return { address: address(r.address), workspace: String(r.workspace),
    x: r.x, y: r.y, width: r.width, height: r.height,
    grouped: !!r.grouped }
}
function detector() { return { known: {}, hints: {}, topologyUntil: {}, initialized: false } }
function hint(state, kind, id, now) {
  id = address(id)
  if (!id) return
  if (kind === "move" && state.hints[id] && state.hints[id].kind === "open") return
  state.hints[id] = { kind: kind, time: now }
}
function baseline(state, rows) {
  state.known = {}
  state.hints = {}
  state.topologyUntil = {}
  state.initialized = true
  for (var i = 0; i < rows.length; i++) {
    if (valid(rows[i])) state.known[address(rows[i].address)] = copy(rows[i])
  }
}
function geometryChanged(a, b) {
  return Math.max(Math.abs(a.x + a.width / 2 - b.x - b.width / 2),
    Math.abs(a.y + a.height / 2 - b.y - b.height / 2),
    Math.abs(a.width - b.width), Math.abs(a.height - b.height)) >= tuning.geometryThreshold
}
// Missing/incomplete metadata is not a close. Explicit close evidence wins
// over a stale roster; new unannounced records silently complete the baseline.
function diff(state, rows, now, allowGeometry) {
  if (!state.initialized) { baseline(state, rows); return [] }
  var events = [], seen = {}, topology = {}
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    if (!valid(r)) continue
    var id = address(r.address), old = state.known[id], h = state.hints[id]
    seen[id] = true
    if (h && h.kind === "close") continue
    var next = copy(r)
    if (!old) {
      state.known[id] = next
      if (h && h.kind === "open" && now - h.time <= tuning.intentMs) {
        events.push({ kind: "open", before: null, after: next })
        topology[next.workspace] = true
        delete state.hints[id]
      }
    } else if (old.workspace !== next.workspace) {
      events.push({ kind: "move", before: old, after: next })
      topology[old.workspace] = topology[next.workspace] = true
      state.known[id] = next
      delete state.hints[id]
    }
  }
  for (var key in state.hints) {
    var evidence = state.hints[key], previous = state.known[key]
    if (evidence.kind === "close" && previous) {
      events.push({ kind: "close", before: previous, after: null })
      topology[previous.workspace] = true
      delete state.known[key]
    }
    // Keep close tombstones until the stale roster disappears.
    if ((!seen[key] && evidence.kind === "close") || now - evidence.time > tuning.intentMs)
      delete state.hints[key]
  }
  for (var workspace in topology) state.topologyUntil[workspace] = now + tuning.maximumBatchMs
  for (var j = 0; j < rows.length; j++) {
    var current = rows[j], canonical = address(current.address)
    var accepted = state.known[canonical]
    if (!valid(current) || !accepted || accepted.workspace !== String(current.workspace)) continue
    if (now < (state.topologyUntil[accepted.workspace] || 0) || !allowGeometry || current.grouped) {
      // Hyprland can report several intermediate tiling rectangles after a
      // topology event. Keep absorbing that settling motion until it is quiet,
      // rather than replaying one landing as a stream of geometry impacts.
      if (now < (state.topologyUntil[accepted.workspace] || 0)
          && (current.x !== accepted.x || current.y !== accepted.y
            || current.width !== accepted.width || current.height !== accepted.height))
        state.topologyUntil[accepted.workspace] = now + tuning.maximumBatchMs
      var rebased = copy(current)
      state.known[canonical] = rebased
    } else if (geometryChanged(accepted, current)) {
      var updated = copy(current)
      events.push({ kind: "geometry", before: accepted, after: updated })
      state.known[canonical] = updated
    }
  }
  return events
}
function vector(dx, dy) {
  var distance = Math.sqrt(dx * dx + dy * dy)
  return distance > 0.001 ? { x: dx / distance, y: dy / distance, distance: distance }
    : { x: 0, y: -1, distance: 0 }
}
function falloff(distance, radius) {
  radius = Math.max(1, radius)
  if (distance > radius * tuning.rippleCutoff) return 0
  var d = distance / radius
  return 1 / (1 + d * d)
}
function neighbours(origin, cards, count) {
  var result = []
  for (var i = 0; i < cards.length; i++) {
    var c = cards[i]
    if (c.key === origin.key || c.insertion) continue
    var v = vector(c.x + c.width / 2 - origin.x - origin.width / 2,
      c.y + c.height / 2 - origin.y - origin.height / 2)
    var weight = falloff(v.distance, Math.max(origin.width, origin.height) * tuning.cardRadius)
    if (weight > 0) result.push({ card: c, vector: v, weight: weight })
  }
  result.sort(function(a, b) { return a.vector.distance - b.vector.distance })
  // Immediate neighbours: keep the closest card in each visual direction.
  // A second card behind that neighbour never joins the ripple merely because
  // a numeric neighbour budget remains. Carousel centers share the same row.
  var adjacent = [], directions = {}
  for (var j = 0; j < result.length; j++) {
    var n = result[j], v = n.vector
    var direction = Math.abs(v.x) >= Math.abs(v.y)
      ? (v.x < 0 ? "left" : "right") : (v.y < 0 ? "above" : "below")
    if (directions[direction]) continue
    directions[direction] = true
    adjacent.push(n)
    if (adjacent.length >= count) break
  }
  return adjacent
}
// AndroidX Material 3 Expressive fast spatial spring (unit mass):
// https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/ExpressiveMotionTokens.kt
// Cards make short local excursions, rather than full-screen transitions.
function axis() { return { position: 0, velocity: 0, target: 0, pulse: 0 } }
function impulse(a, pixels) {
  // Retarget, preserving position AND velocity. Bursts merge into a bounded
  // excursion instead of injecting another sharp acceleration/velocity kick.
  a.pulse = clamp(a.pulse + pixels, tuning.cardLimit * 0.8)
}
function integrate(a, dt, goal) {
  var w = Math.sqrt(tuning.stiffness), damping = tuning.damping * w
  var wd = w * Math.sqrt(1 - tuning.damping * tuning.damping)
  var x = a.position - goal, v = a.velocity
  var decay = Math.exp(-damping * dt), s = Math.sin(wd * dt), c = Math.cos(wd * dt)
  a.position = goal + decay * (x * c + (v + damping * x) * s / wd)
  a.velocity = decay * (v * c - (damping * v + w * w * x) * s / wd)
}
function step(a, dt, limit) {
  var goal = clamp(a.target + a.pulse, limit * 0.8)
  // Release on reaching the excursion target. Solve the crossing time so the
  // return preserves momentum and is independent of the timer/frame rate.
  if (a.pulse !== 0) {
    var w = Math.sqrt(tuning.stiffness), d = tuning.damping * w
    var wd = w * Math.sqrt(1 - tuning.damping * tuning.damping)
    var x = a.position - goal, coefficient = (a.velocity + d * x) / wd
    var crossing = Math.atan2(-x, coefficient)
    if (crossing <= 0) crossing += Math.PI
    crossing /= wd
    if (Math.abs(x) < tuning.restPosition || crossing <= dt) {
      crossing = Math.abs(x) < tuning.restPosition ? 0 : crossing
      integrate(a, crossing, goal)
      a.pulse = 0
      integrate(a, dt - crossing, a.target)
    } else integrate(a, dt, goal)
  } else integrate(a, dt, goal)
  a.velocity = clamp(a.velocity, tuning.velocityLimit)
  if (Math.abs(a.position) > limit) {
    a.position = clamp(a.position, limit)
    if (a.position * a.velocity > 0) a.velocity = 0
  }
  if (a.pulse === 0 && Math.abs(a.position - a.target) < tuning.restPosition
      && Math.abs(a.velocity) < tuning.restVelocity) {
    a.position = a.target
    a.velocity = 0
    return false
  }
  return true
}
