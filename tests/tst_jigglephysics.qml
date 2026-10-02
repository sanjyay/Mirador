import QtQuick 2.15
import QtTest 1.3
import "../JigglePhysics.js" as Physics

TestCase {
  name: "JigglePhysics"
  function row(id, ws, x) { return { address: id, workspace: ws, x: x || 0, y: 0, width: 100, height: 100 } }
  function test_baselineAndLatePopulation() {
    var s = Physics.detector()
    compare(Physics.diff(s, [row("0xA", 1)], 0, true).length, 0)
    compare(Physics.diff(s, [row("a", 1), row("b", 1)], 1, true).length, 0)
    compare(Object.keys(s.known).length, 2)
  }
  function test_openCloseAndStaleRoster() {
    var s = Physics.detector(); Physics.baseline(s, [])
    Physics.hint(s, "open", "0xA", 1)
    var e = Physics.diff(s, [row("a", 1)], 2, true)
    compare(e.length, 1); compare(e[0].kind, "open")
    compare(Physics.diff(s, [], 3, true).length, 0)
    Physics.hint(s, "close", "a", 4)
    e = Physics.diff(s, [row("a", 1)], 5, true)
    compare(e.length, 1); compare(e[0].before.x, 0)
    compare(Physics.diff(s, [row("a", 1)], 6, true).length, 0)
  }
  function test_migrationAbsorbsGeometry() {
    var s = Physics.detector(); Physics.baseline(s, [row("a", 1), row("b", 1)])
    Physics.hint(s, "move", "a", 0)
    var e = Physics.diff(s, [row("a", -99, 50), row("b", 1, 40)], 1, true)
    compare(e.length, 1); compare(e[0].kind, "move")
    compare(e[0].before.workspace, "1"); compare(e[0].after.workspace, "-99")
    Physics.hint(s, "move", "a", 2)
    compare(Physics.diff(s, [row("a", -99, 50), row("b", 1, 40)], 3, true).length, 0)
  }
  function test_noiseAccumulatesAndNavigationRebases() {
    var s = Physics.detector(); Physics.baseline(s, [row("a", "name:web")])
    compare(Physics.diff(s, [row("a", "name:web", 5)], 1, true).length, 0)
    compare(Physics.diff(s, [row("a", "name:web", 9)], 2, true)[0].kind, "geometry")
    compare(Physics.diff(s, [row("a", "name:web", 40)], 3, false).length, 0)
    compare(Physics.diff(s, [row("a", "name:web", 40)], 4, true).length, 0)
  }
  function test_focusAndInvalidMetadata() {
    var s = Physics.detector(); Physics.baseline(s, [row("a", 1)])
    var r = row("a", 1); r.title = "changed"; r.focused = true
    compare(Physics.diff(s, [r], 1, true).length, 0)
    r.width = 0
    compare(Physics.diff(s, [r], 2, true).length, 0)
    verify(s.known.a.width === 100)
  }
  function test_groupFocusGeometrySilent() {
    var s = Physics.detector(); Physics.baseline(s, [row("a", 1)])
    var r = row("a", 1, 90); r.grouped = true
    compare(Physics.diff(s, [r], 1, true).length, 0)
  }
  function test_directionFalloffAndNeighbours() {
    compare(Physics.vector(-10, 0).x, -1)
    compare(Physics.vector(0, 0).y, -1)
    compare(Physics.falloff(0, 10), 1)
    compare(Physics.falloff(10, 10), 0.5)
    compare(Physics.falloff(21, 10), 0)
    var c = { key: "center", x: 100, y: 0, width: 100, height: 60 }
    var neighbours = Physics.neighbours(c, [c,
      { key: "left", x: 0, y: 0, width: 100, height: 60 },
      { key: "right", x: 200, y: 0, width: 100, height: 60 },
      { key: "insert", x: 80, y: 0, width: 100, height: 60, insertion: true }], 2)
    compare(neighbours.length, 2)
    compare(neighbours[0].vector.x, -1); compare(neighbours[1].vector.x, 1)
  }
  function test_additiveSpringClampsAndRests() {
    var a = Physics.axis()
    Physics.impulse(a, 2); Physics.step(a, 0.016, 4)
    var position = a.position, velocity = a.velocity
    Physics.impulse(a, 1)
    compare(a.position, position); compare(a.velocity, velocity); compare(a.pulse, 3)
    Physics.impulse(a, 100); compare(a.pulse, Physics.tuning.cardLimit * 0.8)
    for (var i = 0; i < 200; i++) { Physics.step(a, 0.016, 4); verify(Math.abs(a.position) <= 4) }
    compare(a.position, 0); compare(a.velocity, 0)
  }
  function test_opposingImpulseAndHoverEquilibrium() {
    var a = Physics.axis(); Physics.impulse(a, 1); Physics.impulse(a, -1)
    compare(a.velocity, 0)
    a.target = 2
    for (var i = 0; i < 100; i++) Physics.step(a, 0.016, 4)
    compare(a.position, 2); compare(Physics.step(a, 0.016, 4), false)
    a.target = 0
    for (i = 0; i < 100; i++) Physics.step(a, 0.016, 4)
    compare(a.position, 0)
  }
  function test_delayedRelayoutAbsorbedByTopology() {
    var s = Physics.detector(); Physics.baseline(s, [row("a", 1), row("b", 1)])
    Physics.hint(s, "close", "b", 1)
    compare(Physics.diff(s, [row("a", 1)], 2, true).length, 1)
    compare(Physics.diff(s, [row("a", 1, 100)], 50, true).length, 0)
    compare(s.known.a.x, 100)
    compare(Physics.diff(s, [row("a", 1, 120)], 300, true)[0].kind, "geometry")
  }
  function test_openThenCloseBeforePopulationIsSilent() {
    var s = Physics.detector(); Physics.baseline(s, [])
    Physics.hint(s, "open", "a", 0)
    Physics.hint(s, "close", "a", 1)
    compare(Physics.diff(s, [], 2, true).length, 0)
  }

  function test_openFollowedByMoveLandsAtFinalWorkspace() {
    var s = Physics.detector(); Physics.baseline(s, [])
    Physics.hint(s, "open", "a", 0)
    Physics.hint(s, "move", "a", 1)
    var e = Physics.diff(s, [row("a", 3)], 2, true)
    compare(e.length, 1); compare(e[0].kind, "open")
    compare(e[0].after.workspace, "3")
  }
  function test_expiredOpenEvidenceDoesNotReplay() {
    var s = Physics.detector(); Physics.baseline(s, [])
    Physics.hint(s, "open", "a", 0)
    compare(Physics.diff(s, [row("a", 1)], 600, true).length, 0)
  }
  function test_workspaceImpactHasOneVisibleRebound() {
    var a = Physics.axis(), peak = 0, minimum = 0, peakTime = 0, signs = [], lastSign = 0
    Physics.impulse(a, Physics.tuning.cardImpact)
    for (var i = 1; i <= 180; i++) {
      Physics.step(a, 1 / 120, Physics.tuning.cardLimit)
      if (a.position > peak) { peak = a.position; peakTime = i / 120 }
      minimum = Math.min(minimum, a.position)
      var pixel = Math.round(a.position), sign = pixel > 0 ? 1 : (pixel < 0 ? -1 : 0)
      if (sign && sign !== lastSign) { signs.push(sign); lastSign = sign }
    }
    verify(peak > 9 && peak <= Physics.tuning.cardLimit)
    verify(peakTime > 0.055 && peakTime < 0.18)
    verify(minimum < -0.5)
    compare(signs.length, 2)
    compare(signs[0], 1); compare(signs[1], -1)
    compare(a.position, 0); compare(a.velocity, 0)
  }

  function test_compositorSettlingDoesNotBecomeRepeatedImpacts() {
    var s = Physics.detector(); Physics.baseline(s, [row("a", 1), row("b", 1)])
    Physics.hint(s, "close", "b", 0)
    compare(Physics.diff(s, [row("a", 1)], 1, true).length, 1)
    for (var i = 1; i <= 8; i++)
      compare(Physics.diff(s, [row("a", 1, i * 10)], i * 90, true).length, 0)
    compare(Physics.diff(s, [row("a", 1, 100)], 1000, true)[0].kind, "geometry")
  }
  function test_materialRetargetPreservesMomentumAndFrameIndependence() {
    var fine = Physics.axis(), coarse = Physics.axis()
    Physics.impulse(fine, 10); Physics.impulse(coarse, 10)
    compare(fine.position, 0); compare(fine.velocity, 0)
    for (var i = 0; i < 12; i++) Physics.step(fine, 0.01, 14)
    Physics.step(coarse, 0.12, 14)
    fuzzyCompare(fine.position, coarse.position, 0.00001)
    fuzzyCompare(fine.velocity, coarse.velocity, 0.00001)
    compare(fine.pulse, 0)
    var position = fine.position, velocity = fine.velocity
    Physics.impulse(fine, 4)
    compare(fine.position, position); compare(fine.velocity, velocity)
    verify(fine.pulse > 0)
  }

  function test_immediateNeighboursExcludeSecondRingAndUseVisualGeometry() {
    var origin = { key: "origin", x: 200, y: 200, width: 100, height: 100 }
    var cards = [origin,
      { key: "left", x: 80, y: 200, width: 100, height: 100 },
      { key: "right", x: 320, y: 200, width: 100, height: 100 },
      { key: "above", x: 200, y: 80, width: 100, height: 100 },
      { key: "below", x: 200, y: 320, width: 100, height: 100 },
      { key: "second-right", x: 440, y: 200, width: 100, height: 100 },
      { key: "diagonal", x: 320, y: 320, width: 100, height: 100 }]
    var adjacent = Physics.neighbours(origin, cards, 4)
    compare(adjacent.length, 4)
    var names = adjacent.map(function(n) { return n.card.key }).sort().join(",")
    compare(names, "above,below,left,right")
  }
}
