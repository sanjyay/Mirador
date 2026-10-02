import QtQuick 2.15
import "JigglePhysics.js" as Physics

Item {
  id: root
  property Item scene: null
  enabled: false
  property real dpr: 1
  property string presentation: "full"
  property var snapshotProvider: null
  property var state: Physics.detector()
  property var bodies: ({})
  property var activeBodies: []
  property var pendingSnapshot: []
  property bool allowGeometry: true
  property bool primed: false
  property real suppressGeometryUntil: 0
  property var drag: null
  property var dropIntent: null
  property var firmWorkspaces: ({})
  property real lastTick: 0
  readonly property bool running: animation.running
  signal semanticEvent(var event)

  function reset(rows) {
    quiet.stop(); deadline.stop(); animation.stop(); intentExpiry.stop()
    activeBodies = []
    primed = false
    for (var key in bodies) {
      var b = bodies[key]
      b.x = Physics.axis(); b.y = Physics.axis(); b.awake = false
      publish(b)
    }
    drag = null; dropIntent = null
    suppressGeometryUntil = Date.now() + Physics.tuning.maximumBatchMs
    state = Physics.detector()
    Physics.baseline(state, rows || [])
  }
  onEnabledChanged: reset(enabled && snapshotProvider ? snapshotProvider() : [])
  onPresentationChanged: reset(enabled && snapshotProvider ? snapshotProvider() : [])
  function navigation() { suppressGeometryUntil = Date.now() + Physics.tuning.maximumBatchMs }
  function observe() {
    if (!enabled) return
    quiet.restart()
    if (!deadline.running) deadline.start()
  }
  function evidence(kind, id) {
    if (!enabled) return
    Physics.hint(state, kind, id, Date.now())
    observe()
  }
  function flush() {
    quiet.stop(); deadline.stop()
    if (!enabled) return
    var rows = snapshotProvider ? snapshotProvider() : pendingSnapshot
    var events = Physics.diff(state, rows, Date.now(), allowGeometry && primed && Date.now() >= suppressGeometryUntil)
    primed = true
    // All topology endpoints stay firm, including simultaneous closes/moves.
    // Another event in this batch must not bounce an affected workspace.
    firmWorkspaces = {}
    for (var j = 0; j < events.length; j++) {
      if (events[j].after && events[j].kind !== "geometry")
        firmWorkspaces[events[j].after.workspace] = true
      if (events[j].kind !== "geometry" && events[j].before)
        firmWorkspaces[events[j].before.workspace] = true
    }
    for (var i = 0; i < events.length; i++) {
      semanticEvent(events[i])
      react(events[i])
    }
    firmWorkspaces = {}
    if (dropIntent && Date.now() - dropIntent.time > Physics.tuning.intentMs) dropIntent = null
  }
  function attach(surface) {
    // A key can be reattached after model/delegate reconstruction. It does not
    // produce an event and retains velocity from an already confirmed impact.
    for (var oldKey in bodies) {
      if (bodies[oldKey].surface === surface && oldKey !== surface.bodyKey) {
        bodies[oldKey].surface = null
        bodies[oldKey].detachedAt = Date.now()
      }
    }
    var b = bodies[surface.bodyKey]
    if (!b) {
      b = { key: surface.bodyKey, surface: surface, x: Physics.axis(), y: Physics.axis(), awake: false, bounds: null }
      bodies[surface.bodyKey] = b
    }
    b.surface = surface
    publish(b)
  }
  function detach(surface) {
    var b = bodies[surface.bodyKey]
    if (b && b.surface === surface) {
      b.bounds = surface.bounds()
      b.detachedAt = Date.now()
      b.surface = null
    }
  }
  function usable(b) { return b.surface && b.surface.kind !== "window"
    && b.surface.active && b.surface.presentation === presentation }
  function publish(b) {
    if (!b.surface) return
    b.surface.offsetX = usable(b) ? Math.round(b.x.position * dpr) / dpr : 0
    b.surface.offsetY = usable(b) ? Math.round(b.y.position * dpr) / dpr : 0
  }
  function wake(b) {
    if (!b.awake) { b.awake = true; activeBodies.push(b) }
    if (!animation.running) { lastTick = Date.now(); animation.start() }
  }
  function kick(b, x, y) {
    if (!b || !usable(b)) return
    Physics.impulse(b.x, x); Physics.impulse(b.y, y); wake(b)
  }
  function advance(dt) {
    for (var i = activeBodies.length - 1; i >= 0; i--) {
      var b = activeBodies[i]
      if (!usable(b)) {
        b.x = Physics.axis(); b.y = Physics.axis()
        b.awake = false; activeBodies.splice(i, 1); publish(b); continue
      }
      var limit = Physics.tuning.cardLimit
      var movingX = Physics.step(b.x, dt, limit), movingY = Physics.step(b.y, dt, limit)
      publish(b)
      if (!movingX && !movingY) { b.awake = false; activeBodies.splice(i, 1) }
    }
    if (!activeBodies.length) animation.stop()
  }
  function cards() {
    var list = []
    for (var key in bodies) {
      var b = bodies[key]
      if (usable(b)) {
        b.bounds = b.surface.bounds()
        list.push(b.bounds)
      } else if (!b.surface && Date.now() - b.detachedAt > Physics.tuning.intentMs) {
        delete bodies[key]
      }
    }
    return list
  }
  function ripple(card, list, amount, target) {
    var neighbours = Physics.neighbours(card, list, presentation === "carousel"
      ? Physics.tuning.carouselNeighbourLimit : Physics.tuning.neighbourLimit)
    for (var i = 0; i < neighbours.length; i++) {
      var n = neighbours[i], b = bodies[n.card.key]
      if (b && b.surface && firmWorkspaces[b.surface.workspace]) continue
      // Distance selects strength; all neighbours bounce vertically, including
      // cards in the same row and cards above/below the receiving workspace.
      if (target) setTarget(b, 0, -amount * n.weight)
      else kick(b, 0, -amount * n.weight)
    }
  }
  function impact(record, strength, landing, list, firm) {
    var card = null, body = null
    for (var key in bodies) {
      var b = bodies[key]
      if (b.surface && b.surface.presentation === presentation
          && b.surface.kind === "card" && b.surface.workspace === record.workspace) {
        body = b; card = b.surface.bounds(); break
      }
      if (!b.surface && b.bounds && key.indexOf(presentation + ":card:" + record.workspace + ":") === 0)
        card = b.bounds
    }
    if (!card) return
    if (landing && dropIntent && dropIntent.address === record.address
        && dropIntent.workspace === record.workspace && Date.now() - dropIntent.time <= Physics.tuning.intentMs) {
      dropIntent = null
      intentExpiry.stop()
    }
    if (landing || firm) settle(body)
    else kick(body, 0, Physics.tuning.cardImpact * strength)
    // Firm topology endpoints send their impact into immediate surroundings.
    // Other departures and geometry changes keep the weaker secondary ripple.
    ripple(card, list, ((landing || firm) ? Physics.tuning.cardImpact : Physics.tuning.cardRipple) * strength, false)
  }
  function react(event) {
    var list = cards()
    if (event.before && event.kind !== "geometry") impact(event.before, Physics.tuning.departure, false, list,
      true)
    if (event.after) impact(event.after, event.kind === "geometry" ? Physics.tuning.geometry : 1,
      event.kind !== "geometry", list)
  }
  function settle(b) {
    if (!b) return
    b.x = Physics.axis(); b.y = Physics.axis(); b.awake = false
    var index = activeBodies.indexOf(b)
    if (index !== -1) activeBodies.splice(index, 1)
    publish(b)
    if (!activeBodies.length) animation.stop()
  }
  function settleWorkspace(workspace) {
    for (var key in bodies) {
      var b = bodies[key]
      if (b.surface && b.surface.kind === "card" && b.surface.workspace === String(workspace)) settle(b)
    }
  }
  function setTarget(b, x, y) {
    if (!b || !usable(b)) return
    if (b.x.target === x && b.y.target === y) return
    b.x.target = x; b.y.target = y; wake(b)
  }
  function pointer(x, y, address, workspace) {
    if (!enabled) return
    drag = { x: x, y: y, address: Physics.address(address), workspace: String(workspace) }
    updateAnticipation()
  }
  function endDrag() { drag = null; updateAnticipation() }
  function expectDrop(address, workspace) {
    if (drag) {
      dropIntent = { address: Physics.address(address), workspace: String(workspace),
        time: Date.now() }
      intentExpiry.restart()
    }
    endDrag()
    // Stop the target's hover spring at the drop handoff, before IPC catches up.
    settleWorkspace(workspace)
  }
  function updateAnticipation() {
    if (!enabled) return
    var list = cards(), best = null, bestDistance = Physics.tuning.approach
    for (var i = 0; i < list.length; i++) {
      var c = list[i], b = bodies[c.key]
      if (!drag || !c.surface.validDropTarget) continue
      var dx = Math.max(c.x - drag.x, 0, drag.x - c.x - c.width)
      var dy = Math.max(c.y - drag.y, 0, drag.y - c.y - c.height)
      var distance = Math.sqrt(dx * dx + dy * dy)
      if (c.surface.dropHovered) { best = c; bestDistance = 0; break }
      if (distance < bestDistance) { best = c; bestDistance = distance }
    }
    // Clear all targets, including cards after a hovered candidate in the list.
    for (var j = 0; j < list.length; j++) setTarget(bodies[list[j].key], 0, 0)
    if (!best) return
    var strength = 1 - bestDistance / Physics.tuning.approach
    // The target remains firm throughout anticipation and drop; only adjacent
    // cards lift. Its existing stable highlight still identifies the target.
    settle(bodies[best.key])
    ripple(best, list, Physics.tuning.hoverRipple * strength, true)
  }
  Timer { id: intentExpiry; interval: Physics.tuning.intentMs; onTriggered: root.dropIntent = null }
  Timer { id: quiet; interval: Physics.tuning.quietMs; onTriggered: root.flush() }
  Timer { id: deadline; interval: Physics.tuning.maximumBatchMs; onTriggered: root.flush() }
  Timer {
    id: animation
    interval: Physics.tuning.frameMs; repeat: true
    onTriggered: {
      var now = Date.now()
      root.advance(Math.max(0, (now - root.lastTick) / 1000))
      root.lastTick = now
    }
  }
}
