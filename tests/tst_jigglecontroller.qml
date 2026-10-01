import QtQuick 2.15
import QtTest 1.3
import ".."
import "../JigglePhysics.js" as Physics

TestCase {
  id: test
  name: "JiggleController"
  width: 800; height: 600
  when: windowShown
  property alias controllerRef: controller
  JiggleController { id: controller; scene: test; enabled: true }
  Item {
    id: hitSurface
    x: 200; y: 100; width: 100; height: 100
    JiggleSurface {
      id: surface
      controller: test.controllerRef
      workspace: "1"
      active: true
      validDropTarget: true
    }
    Rectangle {
      id: visual
      anchors.fill: parent
      transform: Translate { x: surface.offsetX; y: surface.offsetY }
    }
  }
  Component {
    id: fixture
    Item {
      property string workspaceId: "2"
      property string kind: "card"
      property var addresses: []
      property alias motion: motion
      width: 100; height: 100
      JiggleSurface {
        id: motion
        controller: test.controllerRef
        workspace: parent.workspaceId
        kind: parent.kind
        addresses: parent.addresses
        identity: addresses.join(",")
        active: true
        validDropTarget: true
      }
    }
  }
  SignalSpy { id: events; target: controller; signalName: "semanticEvent" }
  function row(id, ws, x) { return { address: id, workspace: ws, x: x || 0, y: 0, width: 100, height: 100 } }
  function init() {
    controller.presentation = "full"
    controller.enabled = true
    controller.reset([row("a", 1)])
    controller.suppressGeometryUntil = 0
    events.clear()
  }
  function cleanup() { controller.reset([]) }
  function test_semanticEventAndIdle() {
    createTemporaryObject(fixture, test, { x: 320, y: 100 })
    controller.pendingSnapshot = [row("a", 1), row("b", 1)]
    controller.evidence("open", "b")
    controller.flush()
    compare(events.count, 1)
    verify(controller.running)
    for (var i = 0; i < 100; i++) controller.advance(0.016)
    compare(controller.running, false)
    compare(surface.offsetX, 0); compare(surface.offsetY, 0)
  }
  function test_fixedHitSurfaceAndPixelSnapping() {
    controller.dpr = 1.5
    controller.kick(controller.bodies[surface.bodyKey], 2, 3)
    controller.advance(0.032)
    compare(hitSurface.x, 200); compare(hitSurface.y, 100)
    compare(surface.bounds().x, 200)
    verify(surface.offsetY !== 0)
    fuzzyCompare(surface.offsetY * 1.5, Math.round(surface.offsetY * 1.5), 0.00001)
    compare(visual.mapToItem(test, 0, 0).y, 100 + surface.offsetY)
    controller.dpr = 1
  }
  function test_hoverReleaseAndCancel() {
    var neighbour = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    controller.pointer(250, 110, "a", "2")
    for (var i = 0; i < 100; i++) controller.advance(0.016)
    verify(neighbour.motion.offsetY < 0); compare(surface.offsetY, 0); compare(controller.running, false)
    compare(surface.bounds().y, 100)
    controller.endDrag()
    for (i = 0; i < 100; i++) controller.advance(0.016)
    compare(surface.offsetY, 0); compare(neighbour.motion.offsetY, 0); compare(events.count, 0)
  }
  function test_dropWaitsForMembership() {
    controller.pointer(250, 110, "a", "2")
    controller.expectDrop("a", 1)
    compare(events.count, 0)
    controller.pendingSnapshot = [row("a", 1)]
    controller.flush()
    compare(events.count, 0)
  }
  function test_rapidEventsKeepMomentum() {
    var neighbour = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    controller.pendingSnapshot = [row("a", 1), row("b", 1)]
    controller.evidence("open", "b"); controller.flush(); controller.advance(0.016)
    var b = controller.bodies[neighbour.motion.bodyKey], position = b.y.position, velocity = b.y.velocity
    controller.pendingSnapshot = [row("a", 1), row("b", 1), row("c", 1)]
    controller.evidence("open", "c"); controller.flush()
    compare(b.y.position, position); compare(b.y.velocity, velocity); verify(b.y.pulse < 0)
  }
  function test_resetClearsPendingAndMotion() {
    controller.evidence("open", "b")
    controller.kick(controller.bodies[surface.bodyKey], 2, 3)
    controller.advance(0.016)
    controller.enabled = false
    compare(controller.running, false); compare(surface.offsetY, 0)
    wait(150); compare(events.count, 0)
  }
  function test_verticalRippleUsesDistance() {
    var left = createTemporaryObject(fixture, test, { x: 80, y: 100, workspaceId: "99" })
    var right = createTemporaryObject(fixture, test, { x: 320, y: 100, workspaceId: "-99" })
    controller.pendingSnapshot = [row("a", 1), row("b", 1)]
    controller.evidence("open", "b"); controller.flush()
    compare(controller.bodies[left.motion.bodyKey].x.pulse, 0)
    compare(controller.bodies[right.motion.bodyKey].x.pulse, 0)
    verify(controller.bodies[left.motion.bodyKey].y.pulse < 0)
    compare(controller.bodies[left.motion.bodyKey].y.pulse, controller.bodies[right.motion.bodyKey].y.pulse)
  }
  function test_applicationPreviewsReceiveNoIndependentPhysics() {
    var preview = createTemporaryObject(fixture, test, {
      x: 235, y: 135, width: 30, height: 30, workspaceId: "1", kind: "window", addresses: ["b"] })
    controller.pendingSnapshot = [row("a", 1), row("b", 1)]
    controller.evidence("open", "b"); controller.flush()
    controller.advance(0.016)
    compare(preview.motion.offsetX, 0); compare(preview.motion.offsetY, 0)
    compare(surface.offsetY, 0)
  }
  function test_migrationEndpointsAndDuplicateRefresh() {
    var destination = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    controller.pendingSnapshot = [row("a", 2)]
    controller.evidence("move", "a"); controller.flush()
    compare(events.count, 1)
    compare(controller.bodies[destination.motion.bodyKey].y.pulse, 0)
    compare(controller.bodies[destination.motion.bodyKey].x.pulse, 0)
    compare(controller.bodies[surface.bodyKey].y.pulse, 0)
    controller.evidence("move", "a"); controller.flush()
    compare(events.count, 1)
  }
  function test_confirmedDropConsumesIntentOnce() {
    controller.reset([row("a", 2)])
    controller.pointer(250, 110, "a", "2")
    controller.expectDrop("a", 1)
    controller.pendingSnapshot = [row("a", 1)]
    controller.flush()
    compare(events.count, 1); compare(controller.dropIntent, null)
    controller.flush(); compare(events.count, 1)
  }
  function test_initialRefreshAndPresentationChangeSilent() {
    controller.pendingSnapshot = [row("a", 1, 100)]
    controller.flush(); compare(events.count, 0)
    controller.pendingSnapshot = [row("a", 1, 120)]
    controller.flush(); compare(events.count, 1)
    controller.presentation = "carousel"
    compare(surface.offsetY, 0); compare(controller.running, false)
    controller.flush(); compare(events.count, 1)
  }
  function test_quietBatchMergesIntermediateDestinations() {
    controller.pendingSnapshot = [row("a", 2)]
    controller.evidence("move", "a")
    controller.pendingSnapshot = [row("a", 3)]
    controller.evidence("move", "a")
    tryCompare(events, "count", 1, 300)
    compare(events.signalArguments[0][0].before.workspace, "1")
    compare(events.signalArguments[0][0].after.workspace, "3")
    wait(130); compare(events.count, 1)
  }
  function test_reattachRetainsExistingSpring() {
    var first = fixture.createObject(test, { x: 320, y: 100 })
    var key = first.motion.bodyKey, b = controller.bodies[key]
    controller.kick(b, 1, 2)
    var velocity = b.y.velocity
    controller.detach(first.motion)
    first.destroy()
    var replacement = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    compare(controller.bodies[replacement.motion.bodyKey], b)
    compare(b.y.velocity, velocity)
    compare(events.count, 0)
  }

  function test_unconfirmedDropExpires() {
    controller.pointer(250, 110, "a", "2")
    controller.expectDrop("a", 1)
    verify(controller.dropIntent !== null)
    tryCompare(controller, "dropIntent", null, 650)
    compare(events.count, 0)
  }
  function test_continuousRefreshCannotStarveBatch() {
    controller.pendingSnapshot = [row("a", 1), row("b", 1)]
    controller.evidence("open", "b")
    for (var i = 0; i < 7; i++) { wait(20); controller.observe() }
    compare(events.count, 1)
  }


  function test_dragAcrossTargetCenterHasContinuousAnticipation() {
    controller.pointer(249.9, 150, "a", "2")
    var b = controller.bodies[surface.bodyKey], left = b.x.target, raised = b.y.target
    controller.pointer(250.1, 150, "a", "2")
    compare(left, 0); compare(b.x.target, 0)
    compare(b.y.target, raised)
    compare(raised, 0)
  }

  function test_openSettlesDestinationAndBouncesNeighbours_data() {
    return [{ tag: "overview", presentation: "full" }, { tag: "carousel", presentation: "carousel" }]
  }
  function test_openSettlesDestinationAndBouncesNeighbours(data) {
    controller.presentation = data.presentation
    surface.presentation = data.presentation
    var left = createTemporaryObject(fixture, test, { x: 80, y: 100, workspaceId: "99" })
    var right = createTemporaryObject(fixture, test, { x: 320, y: 100, workspaceId: "-99" })
    left.motion.presentation = data.presentation; right.motion.presentation = data.presentation
    var destination = controller.bodies[surface.bodyKey]
    controller.kick(destination, 3, 5); controller.advance(0.05)
    controller.pendingSnapshot = [row("a", 1), row("b", 1)]
    controller.evidence("open", "b"); controller.flush()
    for (var i = 0; i < 100; i++) {
      controller.advance(0.016)
      compare(surface.offsetX, 0); compare(surface.offsetY, 0)
      compare(left.motion.offsetX, 0); compare(right.motion.offsetX, 0)
      if (i === 3) { verify(left.motion.offsetY < 0); verify(right.motion.offsetY < 0) }
    }
    compare(controller.running, false)
    surface.presentation = "full"
  }
  function test_dropHandoffSettlesHoverImmediately() {
    controller.pointer(250, 110, "a", "2")
    controller.advance(0.08); compare(surface.offsetY, 0)
    controller.expectDrop("a", 1)
    compare(surface.offsetX, 0); compare(surface.offsetY, 0)
    controller.advance(0.016); compare(surface.offsetY, 0)
  }
  function test_batchReceiversCannotRippleEachOther() {
    var other = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    controller.pendingSnapshot = [row("a", 1), row("b", 1), row("c", 2)]
    controller.evidence("open", "b"); controller.evidence("open", "c"); controller.flush()
    controller.advance(0.05)
    compare(surface.offsetX, 0); compare(surface.offsetY, 0)
    compare(other.motion.offsetX, 0); compare(other.motion.offsetY, 0)
    compare(controller.running, false)
  }

  function test_verticalRippleBouncesAndFallsOffInTwoDimensions() {
    var near = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    var far = createTemporaryObject(fixture, test, { x: 200, y: 340, workspaceId: "3" })
    controller.pendingSnapshot = [row("a", 1), row("b", 1)]
    controller.evidence("open", "b"); controller.flush()
    verify(Math.abs(controller.bodies[near.motion.bodyKey].y.pulse)
      > Math.abs(controller.bodies[far.motion.bodyKey].y.pulse))
    var lifted = false, rebound = false
    for (var i = 0; i < 100; i++) {
      controller.advance(0.016)
      compare(near.motion.offsetX, 0); compare(far.motion.offsetX, 0)
      lifted = lifted || near.motion.offsetY < 0
      rebound = rebound || near.motion.offsetY > 0
    }
    verify(lifted); verify(rebound)
    compare(near.motion.offsetY, 0); compare(far.motion.offsetY, 0)
    compare(controller.running, false)
  }
  function test_carouselOffscreenOriginRipplesVisibleCardsOnly() {
    controller.presentation = "carousel"; surface.presentation = "carousel"
    var origin = createTemporaryObject(fixture, test, { x: 420, y: 100 })
    origin.motion.presentation = "carousel"; origin.motion.active = false
    var hidden = createTemporaryObject(fixture, test, { x: 520, y: 100, workspaceId: "3" })
    hidden.motion.presentation = "carousel"; hidden.motion.active = false
    controller.pendingSnapshot = [row("a", 1), row("b", 2)]
    controller.evidence("open", "b"); controller.flush()
    var visible = controller.bodies[surface.bodyKey]
    fuzzyCompare(visible.y.pulse, -Physics.tuning.cardImpact
      * Physics.falloff(220, 100 * Physics.tuning.cardRadius), 0.000001)
    controller.advance(0.06)
    verify(surface.offsetY < 0); compare(surface.offsetX, 0)
    compare(origin.motion.offsetY, 0); compare(hidden.motion.offsetY, 0)
    surface.presentation = "full"
  }
  function test_carouselCloseKeepsAffectedWorkspaceFirm() {
    controller.presentation = "carousel"; surface.presentation = "carousel"
    controller.reset([row("a", 1)])
    var neighbour = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    neighbour.motion.presentation = "carousel"
    controller.kick(controller.bodies[surface.bodyKey], 0, -8)
    controller.advance(0.06); verify(surface.offsetY < 0)
    controller.pendingSnapshot = []
    controller.evidence("close", "a"); controller.flush()
    compare(events.count, 1)
    verify(controller.bodies[neighbour.motion.bodyKey].y.pulse < 0)
    var bounced = false
    for (var i = 0; i < 100; i++) {
      controller.advance(0.016)
      compare(surface.offsetX, 0); compare(surface.offsetY, 0)
      compare(neighbour.motion.offsetX, 0)
      bounced = bounced || neighbour.motion.offsetY !== 0
    }
    verify(bounced); compare(controller.running, false)
    surface.presentation = "full"
  }
  function test_carouselConcurrentCloseAndOpenKeepBothAffectedCardsFirm() {
    controller.presentation = "carousel"; surface.presentation = "carousel"
    controller.reset([row("a", 1)])
    var destination = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    destination.motion.presentation = "carousel"
    controller.pendingSnapshot = [row("b", 2)]
    controller.evidence("close", "a"); controller.evidence("open", "b"); controller.flush()
    compare(events.count, 2)
    controller.advance(0.08)
    compare(surface.offsetY, 0); compare(destination.motion.offsetY, 0)
    compare(controller.running, false)
    surface.presentation = "full"
  }
  function test_overviewCloseKeepsAffectedWorkspaceFirm() {
    var neighbour = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    controller.kick(controller.bodies[surface.bodyKey], 0, 8); controller.advance(0.06)
    controller.pendingSnapshot = []; controller.evidence("close", "a"); controller.flush()
    for (var i = 0; i < 100; i++) {
      controller.advance(0.016); compare(surface.offsetY, 0)
      if (i === 3) verify(neighbour.motion.offsetY < 0)
    }
    compare(controller.running, false)
  }
  function test_onlyImmediateHorizontalNeighboursBounce() {
    var near = createTemporaryObject(fixture, test, { x: 320, y: 100 })
    var second = createTemporaryObject(fixture, test, { x: 440, y: 100, workspaceId: "3" })
    controller.pendingSnapshot = [row("a", 1), row("b", 1)]
    controller.evidence("open", "b"); controller.flush(); controller.advance(0.06)
    compare(surface.offsetY, 0); verify(near.motion.offsetY < 0)
    compare(second.motion.offsetY, 0)
  }
}
