import QtQuick 2.15
import QtTest 1.3
import "../WindowModel.js" as WindowModel

// Pinning a window while its live preview runs must drop the capture at once.
// Hyprland 0.56 crashes in CScreenshareSession::init() when a toplevel capture
// starts for a pinned window whose monitor was unplugged, and lastIpcObject can
// still say pinned: false after the pin (#70, PR #71 review). These tests run the
// real onRawEvent handler and capture guard from WindowPreview.qml against a fake
// preview, through pin, unplug-free refresh, unpin and restore.
TestCase {
  name: "WindowPreviewPin"

  readonly property string address: "0x55aa10"

  function previewSource() {
    var request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../WindowPreview.qml"), false)
    request.send()
    verify(request.status === 0 || request.status === 200)
    return request.responseText
  }

  // The fake preview: the real guard and handler, evaluated over plain objects.
  function makePreview() {
    var src = previewSource()
    var alive = src.match(/readonly property bool monitorAlive: (\{[\s\S]*?\n  \})\n/)
    verify(alive !== null, "WindowPreview must define the monitorAlive guard")
    var allowed = src.match(/readonly property bool captureAllowed: ([^\n]*\n[^\n]*)\n/)
    verify(allowed !== null, "WindowPreview must define captureAllowed")
    var handler = src.match(/    function onRawEvent\(event\) \{[\s\S]*?\n    \}\n/)
    verify(handler !== null, "WindowPreview must handle raw Hyprland events")

    var monitor = { name: "DP-1" }
    var ipc = { address: address.slice(2), monitor: 0, pinned: false }
    var f = {
      refreshes: 0,
      settleRestarts: 0,
      monitors: [monitor],
      toplevel: { address: address, monitor: monitor, workspace: null, lastIpcObject: ipc }
    }
    var root = {
      toplevel: f.toplevel,
      liveCaptureEnabled: true,
      captureSettled: true,
      hasReceivedFrame: true,
      monitorRemovalHold: false,
      pinOverride: null
    }
    var Hyprland = {
      monitors: { get values() { return f.monitors } },
      refreshToplevels: function() { f.refreshes++ },
      refreshMonitors: function() {}
    }
    var captureSettleTimer = { restart: function() { f.settleRestarts++ } }
    var monitorRemovalHoldTimer = { restart: function() {} }
    var toplevel = f.toplevel

    f.root = root
    f.monitorAlive = eval("(function() " + alive[1] + ")")
    f.captureAllowed = function() {
      root.monitorAlive = f.monitorAlive()
      return eval(allowed[1])
    }
    f.onRawEvent = eval("(" + handler[0].trim().replace(/^function onRawEvent/, "function") + ")")
    f.event = function(name, data) { f.onRawEvent({ name: name, data: data }) }
    // What Hyprland.refreshToplevels() eventually delivers.
    f.ipcRefreshed = function(pinned) { ipc.pinned = pinned }
    return f
  }

  function test_pinEventStateReadsOnlyThisWindowsPin() {
    compare(WindowModel.pinEventState("pin", "55aa10,1", "0x55aa10"), true)
    compare(WindowModel.pinEventState("pin", "0x55aa10,0", "55aa10"), false)
    compare(WindowModel.pinEventState("pin", "55aa11,1", "0x55aa10"), null)
    compare(WindowModel.pinEventState("pin", "55aa10", "0x55aa10"), null)
    compare(WindowModel.pinEventState("pin", "55aa10,x", "0x55aa10"), null)
    compare(WindowModel.pinEventState("pin", "55aa10,1", ""), null)
    compare(WindowModel.pinEventState("float", "55aa10,1", "0x55aa10"), null)
  }

  function test_pinEventBeatsStaleIpc() {
    compare(WindowModel.previewWindowPinned({ pinned: false }, true), true)
    compare(WindowModel.previewWindowPinned({ pinned: true }, false), false)
    compare(WindowModel.previewWindowPinned({ pinned: true }, null), true)
    compare(WindowModel.previewWindowPinned({ pinned: false }, null), false)
    compare(WindowModel.previewWindowPinned(null, null), false)
  }

  function test_pinningALivePreviewReleasesItsCaptureAtOnce() {
    var p = makePreview()
    verify(p.captureAllowed(), "an unpinned window on a live monitor is captured")

    // Pinned while the overview is open. lastIpcObject still says pinned: false.
    p.event("pin", address.slice(2) + ",1")
    compare(p.root.pinOverride, true)
    verify(!p.captureAllowed(), "the capture is released on the pin event, not on the next refresh")
    verify(p.refreshes >= 1, "the pin asks Hyprland for fresh toplevel metadata")
    compare(p.root.hasReceivedFrame, false, "the card drops the last frame and shows the app icon")

    // The refresh lands: still released.
    p.ipcRefreshed(true)
    verify(!p.captureAllowed())
  }

  function test_anotherWindowsPinLeavesThisPreviewAlone() {
    var p = makePreview()
    p.event("pin", "deadbeef,1")
    compare(p.root.pinOverride, null)
    compare(p.refreshes, 0)
    verify(p.captureAllowed())
  }

  function test_unpinningRestoresTheLivePreviewAfterSettling() {
    var p = makePreview()
    p.event("pin", address.slice(2) + ",1")
    p.ipcRefreshed(true)
    verify(!p.captureAllowed())

    // Unpinned. lastIpcObject still says pinned: true.
    p.event("pin", address.slice(2) + ",0")
    compare(p.root.pinOverride, false)
    verify(!p.captureAllowed(), "no capture until the settle interval has passed")
    compare(p.settleRestarts, 1)

    p.root.captureSettled = true          // captureSettleTimer fired
    verify(p.captureAllowed(), "the normal live preview comes back")

    p.ipcRefreshed(false)
    verify(p.captureAllowed())
  }

  function test_aPinnedWindowWithStaleIpcAndNoEventIsStillTrustedFromIpc() {
    var p = makePreview()
    p.ipcRefreshed(true)
    verify(!p.captureAllowed())
  }

  function test_repointingThePreviewForgetsTheOldPin() {
    var src = previewSource()
    verify(/onToplevelChanged:\s*\{[\s\S]*?root\.pinOverride\s*=\s*null/.test(src),
      "a preview pointed at another window must not carry the old window's pin state")
  }
}
