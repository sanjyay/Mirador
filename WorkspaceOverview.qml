import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "WindowGeometry.js" as WindowGeometry

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool demoMode: false
  property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  property var draggedToplevel: null
  property int selectedCardIndex: -1

  // ── Bar geometry ────────────────────────────────────────────────────────────
  // `shell.bar` is the live Bar plugin instance injected by the shell loader.
  // It exposes `position` ("top"/"bottom"/"left"/"right"), `barSize` (pixels),
  // and `barHidden` (bool). We read these reactively — any change automatically
  // re-evaluates the derived usable-area properties below.
  //
  // Fallback: if the bar object is not yet available, all insets stay 0 and the
  // overview uses its normal outer margin across the full panel.
  readonly property var activeBar: shell ? shell.bar : null
  readonly property string barPosition: (activeBar && !activeBar.barHidden)
    ? String(activeBar.position || "top")
    : ""
  readonly property int barPixels: (activeBar && !activeBar.barHidden && activeBar.barSize > 0)
    ? activeBar.barSize
    : 0

  // Inset for each edge in logical pixels, derived entirely from the bar's own
  // exported geometry — no hardcoded heights, no heuristics.
  readonly property int barInsetTop:    barPosition === "top"    ? barPixels : 0
  readonly property int barInsetBottom: barPosition === "bottom" ? barPixels : 0
  readonly property int barInsetLeft:   barPosition === "left"   ? barPixels : 0
  readonly property int barInsetRight:  barPosition === "right"  ? barPixels : 0

  // ── Layout calculation ──────────────────────────────────────────────────────
  readonly property var workspaceModel: root.workspaceIds()
  readonly property int workspaceCount: workspaceModel.length
  readonly property var insertionModel: (root.draggedToplevel !== null)
    ? root.computeInsertionTargets(root.workspaceModel)
    : []
  readonly property var overviewCardModel: root.buildOverviewItems(
    root.workspaceModel, root.draggedToplevel !== null)
  readonly property int cardCount: overviewCardModel.length
  readonly property real cardAspectRatio: 1.55

  // Mirador's own outer margin, applied on top of the bar inset so there is
  // always a small breathing gap between cards and the bar (or monitor edge).
  readonly property real outerMargin: Math.max(Style.gapsOut, Style.spacing.panelPadding)
  readonly property real gridSpacing: Style.space(48)

  // Usable panel area after subtracting bar-reserved edges.
  readonly property real usableX:      barInsetLeft   + outerMargin
  readonly property real usableY:      barInsetTop    + outerMargin
  readonly property real usableWidth:  Math.max(1, panel.width
    - barInsetLeft - barInsetRight - outerMargin * 2)
  readonly property real usableHeight: Math.max(1, panel.height
    - barInsetTop - barInsetBottom - outerMargin * 2)

  // Usable grid area across full usable panel
  readonly property real usableGridY: root.usableY
  readonly property real usableGridHeight: root.usableHeight

  readonly property var gridGeometry: WindowGeometry.overviewGridGeometry(
    cardCount, usableWidth, usableGridHeight, cardAspectRatio,
    Style.space(520), gridSpacing)
  readonly property int columns: Math.max(1, gridGeometry.columns)
  readonly property int rows: Math.max(1, gridGeometry.rows)
  readonly property real cardWidth: Math.max(1, gridGeometry.cardWidth)
  readonly property real cardHeight: Math.max(1, gridGeometry.cardHeight)

  // ── Workspace helpers ───────────────────────────────────────────────────────
  function workspaceById(id) {
    var values = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < values.length; i++) {
      if (values[i] && values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceIds() {
    var ids = []
    var values = Hyprland.workspaces ? Hyprland.workspaces.values : []

    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (!ws) continue
      var id = Number(ws.id)
      if (id > 0 && ids.indexOf(id) === -1) {
        ids.push(id)
      }
    }

    if (ids.length === 0) {
      var focused = Hyprland.focusedWorkspace
      if (focused && focused.id > 0) ids.push(focused.id)
      else ids.push(1)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function contextualNextWorkspaceId(currentId, existingIds) {
    var c = Number(currentId) || 1
    var existing = existingIds || []

    for (var d = 1; d <= 100; d++) {
      var lower = c - d
      if (lower >= 1 && existing.indexOf(lower) === -1) {
        return lower
      }
      var higher = c + d
      if (higher >= 1 && existing.indexOf(higher) === -1) {
        return higher
      }
    }
    return c + 1
  }

  function nextWorkspaceId() {
    var currentId = (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0)
      ? Hyprland.focusedWorkspace.id
      : (root.workspaceModel.length > 0 ? root.workspaceModel[0] : 1)
    return contextualNextWorkspaceId(currentId, root.workspaceModel)
  }

  function buildOverviewItems(workspaceIds, isDragging) {
    var ids = (workspaceIds || []).slice().sort(function(a, b) { return a - b })
    if (ids.length === 0) return []

    if (!isDragging) {
      var items = []
      for (var i = 0; i < ids.length; i++) {
        items.push({ workspaceId: ids[i], isInsertion: false })
      }
      return items
    }

    var items = []
    // 1. Before first workspace (if first > 1)
    if (ids[0] > 1) {
      items.push({ workspaceId: ids[0] - 1, isInsertion: true })
    }

    for (var i = 0; i < ids.length; i++) {
      // Add the real workspace
      items.push({ workspaceId: ids[i], isInsertion: false })

      // If there is a gap before the next workspace, insert target (cur + 1)
      if (i < ids.length - 1) {
        if (ids[i + 1] > ids[i] + 1) {
          items.push({ workspaceId: ids[i] + 1, isInsertion: true })
        }
      }
    }

    // 3. After last workspace
    items.push({ workspaceId: ids[ids.length - 1] + 1, isInsertion: true })

    return items
  }

  function computeInsertionTargets(workspaceIds) {
    var ids = (workspaceIds || []).slice().sort(function(a, b) { return a - b })
    if (ids.length === 0) return []

    var targets = []
    if (ids[0] > 1) {
      targets.push(ids[0] - 1)
    }

    for (var i = 0; i < ids.length - 1; i++) {
      if (ids[i + 1] > ids[i] + 1) {
        targets.push(ids[i] + 1)
      }
    }

    targets.push(ids[ids.length - 1] + 1)
    return targets
  }

  function slotIndexForWorkspace(wsId, isDragging) {
    if (!isDragging) {
      return root.workspaceModel.indexOf(wsId)
    }
    for (var i = 0; i < root.overviewCardModel.length; i++) {
      var item = root.overviewCardModel[i]
      if (item && !item.isInsertion && item.workspaceId === wsId) {
        return i
      }
    }
    return -1
  }

  function slotIndexForInsertion(targetWsId) {
    for (var i = 0; i < root.overviewCardModel.length; i++) {
      var item = root.overviewCardModel[i]
      if (item && item.isInsertion && item.workspaceId === targetWsId) {
        return i
      }
    }
    return -1
  }

  function slotX(idx) {
    if (idx < 0) return 0
    var col = idx % root.columns
    return Math.round(root.usableX + root.gridGeometry.x + col * (root.cardWidth + root.gridSpacing))
  }

  function slotY(idx) {
    if (idx < 0) return 0
    var row = Math.floor(idx / root.columns)
    return Math.round(root.usableGridY + root.gridGeometry.y + row * (root.cardHeight + root.gridSpacing))
  }

  function cardIndexAfterMove(index, dx, dy, count, columnCount) {
    if (count <= 0) return -1
    var current = Math.max(0, Math.min(index, count - 1))
    var cols = Math.max(1, columnCount)
    var row = Math.floor(current / cols)
    var column = current % cols

    if (dx < 0) return Math.max(row * cols, current - 1)
    if (dx > 0) return Math.min(Math.min(row * cols + cols - 1, count - 1), current + 1)

    var targetRow = Math.max(0, Math.min(Math.ceil(count / cols) - 1, row + dy))
    return Math.min(targetRow * cols + column, count - 1)
  }

  function initialSelectedCardIndex() {
    var focused = Hyprland.focusedWorkspace
    if (focused) {
      for (var i = 0; i < root.overviewCardModel.length; i++) {
        var item = root.overviewCardModel[i]
        var wsId = typeof item === "object" ? item.workspaceId : item
        if (wsId === focused.id) return i
      }
    }
    return root.cardCount > 0 ? 0 : -1
  }

  function moveCardSelection(dx, dy) {
    root.selectedCardIndex = root.cardIndexAfterMove(
      root.selectedCardIndex, dx, dy, root.cardCount, root.columns)
  }

  function activateSelectedCard() {
    var index = root.selectedCardIndex
    if (index < 0 || index >= root.cardCount) return
    var item = root.overviewCardModel[index]
    var workspaceId = typeof item === "object" ? item.workspaceId : item
    var isInsertion = typeof item === "object" ? Boolean(item.isInsertion) : false
    if (isInsertion) {
      root.dispatchWorkspace(workspaceId)
      Hyprland.refreshWorkspaces()
      Hyprland.refreshToplevels()
    } else {
      var ws = root.workspaceById(workspaceId)
      if (ws) ws.activate()
      else root.dispatchWorkspace(workspaceId)
    }
    Qt.callLater(root.dismiss)
  }

  function normalizedAddress(toplevel) {
    var address = String((toplevel && toplevel.address) || "").trim()
    if (!address.match(/^(0x)?[0-9a-fA-F]+$/)) return ""
    return address.indexOf("0x") === 0 ? address : "0x" + address
  }

  function sourceWorkspaceId(toplevel) {
    return toplevel && toplevel.workspace ? Number(toplevel.workspace.id) : -1
  }

  function dispatchWorkspace(workspaceId) {
    if (workspaceId <= 0) return false
    if (Hyprland.usingLua)
      Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + workspaceId + "\" })")
    else
      Hyprland.dispatch("workspace " + workspaceId)
    return true
  }

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var screens = Quickshell.screens || []
    if (monitor) {
      for (var i = 0; i < screens.length; i++) {
        if (screens[i] && screens[i].name === monitor.name) return screens[i]
      }
    }
    return screens.length > 0 ? screens[0] : null
  }

  function showDemoHint(text, sticky) {
    if (root.demoMode && demoOverlay) {
      demoOverlay.showHint(text, sticky)
    }
  }

  function cleanAppName(raw) {
    if (!raw) return ""
    var name = String(raw).split(".").pop()
    if (name.length > 0) return name.charAt(0).toUpperCase() + name.slice(1)
    return name
  }

  function appNameFor(top) {
    if (!top) return ""
    var wayland = top.wayland
    if (wayland && wayland.appId) return root.cleanAppName(String(wayland.appId))
    var ipc = top.lastIpcObject
    if (ipc && ipc.initialClass) return root.cleanAppName(String(ipc.initialClass))
    if (ipc && ipc.class) return root.cleanAppName(String(ipc.class))
    if (top.appId) return root.cleanAppName(String(top.appId))
    return ""
  }

  function open(payloadJson) {
    Hyprland.refreshMonitors()
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    root.targetScreen = root.focusedScreen()
    root.draggedToplevel = null
    root.selectedCardIndex = root.initialSelectedCardIndex()

    var payload = null
    try {
      if (typeof payloadJson === "string" && payloadJson.length > 0)
        payload = JSON.parse(payloadJson)
      else if (typeof payloadJson === "object" && payloadJson !== null)
        payload = payloadJson
    } catch (e) {
      payload = null
    }
    root.demoMode = Boolean(payload && payload.demo)
    root.opened = true
    Qt.callLater(function() {
      keyCatcher.forceActiveFocus()
      if (root.demoMode && demoOverlay) {
        demoOverlay.showHint("MIRADOR DEMO", false)
      }
    })
  }

  function close() {
    root.demoMode = false
    root.draggedToplevel = null
    root.selectedCardIndex = -1
    root.opened = false
    if (demoOverlay) demoOverlay.hideHint()
  }

  function dismiss() {
    root.demoMode = false
    root.draggedToplevel = null
    root.selectedCardIndex = -1
    root.opened = false
    if (demoOverlay) demoOverlay.hideHint()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "mirador")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // Workspace activation: switches Hyprland active workspace.
  // When clicking inside an empty workspace, transports to that workspace and closes Mirador.
  // When clicking a non-empty workspace, switches active workspace and keeps Mirador open.
  function activateWorkspace(workspace, workspaceId, occupied) {
    root.showDemoHint("SWITCH → WS " + workspaceId, false)
    if (workspace) workspace.activate()
    else root.dispatchWorkspace(workspaceId)

    if (occupied === false) {
      Qt.callLater(root.dismiss)
    }
  }

  // Plus button creation: creates contextual workspace AND KEEPS MIRADOR OPEN
  function createNewWorkspace() {
    var workspaceId = root.nextWorkspaceId()
    root.showDemoHint("CREATE WS " + workspaceId, false)
    if (!root.dispatchWorkspace(workspaceId)) return
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    // MIRADOR STAYS OPEN
  }

  function activateNextWorkspace() {
    root.createNewWorkspace()
  }

  // Window preview activation: focuses target window AND CLOSES MIRADOR
  function activateWindow(toplevel) {
    var app = root.appNameFor(toplevel)
    root.showDemoHint(app ? ("FOCUS → " + app) : "FOCUS WINDOW", false)
    var address = root.normalizedAddress(toplevel)
    var wayland = toplevel ? toplevel.wayland : null
    if (address && Hyprland.usingLua)
      Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })")
    else if (address)
      Hyprland.dispatch("focuswindow address:" + address)
    else if (wayland)
      wayland.activate()
    else
      return
    Qt.callLater(root.dismiss) // WINDOW ACTIVATION CLOSES MIRADOR
  }

  // Drag-and-drop window move: moves window to workspace AND KEEPS MIRADOR OPEN
  function moveWindowToWorkspace(toplevel, workspaceId) {
    var address = root.normalizedAddress(toplevel)
    var sourceId = root.sourceWorkspaceId(toplevel)
    if (!address || workspaceId <= 0 || sourceId === workspaceId) {
      if (demoOverlay) demoOverlay.hideHint()
      return false
    }

    var app = root.appNameFor(toplevel)
    var label = app ? (app + " → WS " + workspaceId) : ("MOVE → WS " + workspaceId)
    root.showDemoHint(label, false)

    root.draggedToplevel = null
    if (Hyprland.usingLua) {
      Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + workspaceId
        + "\", window = \"address:" + address + "\", follow = false })")
    } else {
      Hyprland.dispatch("movetoworkspacesilent " + workspaceId + ",address:" + address)
    }
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    return true
  }

  function beginWindowDrag(toplevel) {
    if (root.normalizedAddress(toplevel)) {
      root.draggedToplevel = toplevel
      var app = root.appNameFor(toplevel)
      root.showDemoHint(app ? ("DRAG " + app) : "DRAG WINDOW", true)
    }
  }

  function endWindowDrag(toplevel) {
    if (root.draggedToplevel === toplevel) {
      root.draggedToplevel = null
      if (demoOverlay) demoOverlay.hideHint()
    }
  }

  // ── Panel window ────────────────────────────────────────────────────────────
  PanelWindow {
    id: panel

    screen: root.targetScreen
    visible: root.opened && root.targetScreen !== null
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-workspace-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: "transparent"
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      onMoveRequested: function(dx, dy) { root.moveCardSelection(dx, dy) }
      onActivateRequested: root.activateSelectedCard()
      onCloseRequested: root.dismiss()

      Keys.onPressed: function(event) {
        if (root.demoMode && demoOverlay) {
          demoOverlay.handleKeyEvent(event)
        }
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.text === "+" || event.text === "=") {
          event.accepted = true
          root.createNewWorkspace()
        }
      }

      // ── Real Workspace Cards (Persistent across drag transitions) ──────────
      Repeater {
        model: root.workspaceModel

        WorkspaceCard {
          required property int modelData
          required property int index

          readonly property int slotIndex: root.slotIndexForWorkspace(modelData, root.draggedToplevel !== null)

          x: root.slotX(slotIndex)
          y: root.slotY(slotIndex)
          width: Math.round(root.cardWidth)
          height: Math.round(root.cardHeight)

          overview: root
          workspaceId: modelData
          workspace: root.workspaceById(modelData)
          livePreviews: root.opened && panel.visible
          draggedToplevel: root.draggedToplevel
          keyboardSelected: slotIndex === root.selectedCardIndex
          focused: Hyprland.focusedWorkspace !== null
          onWorkspaceActivated: function(occupied) {
            root.selectedCardIndex = slotIndex
            root.activateWorkspace(workspace, modelData, occupied)
          }
          onWindowActivated: function(toplevel) { root.activateWindow(toplevel) }
          onWindowDragStarted: function(toplevel) { root.beginWindowDrag(toplevel) }
          onWindowDragFinished: function(toplevel) { root.endWindowDrag(toplevel) }
          onWindowDropped: function(toplevel) { root.moveWindowToWorkspace(toplevel, modelData) }
        }
      }

      // ── Temporary Insertion Workspace Cards (Active only during drag) ───────
      Repeater {
        model: root.insertionModel

        InsertionWorkspaceCard {
          required property int modelData
          required property int index

          readonly property int slotIndex: root.slotIndexForInsertion(modelData)

          x: root.slotX(slotIndex)
          y: root.slotY(slotIndex)
          width: Math.round(root.cardWidth)
          height: Math.round(root.cardHeight)

          overview: root
          targetWorkspaceId: modelData
          draggedToplevel: root.draggedToplevel
          onWindowDropped: function(toplevel) { root.moveWindowToWorkspace(toplevel, modelData) }
        }
      }
    }

    // ── Demo Input Overlay ──────────────────────────────────────────────────
    DemoInputOverlay {
      id: demoOverlay
      z: 1000
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.max(root.barInsetBottom + Style.space(24), Style.space(32))
      demoMode: root.demoMode
    }
  }

  Connections {
    target: root.draggedToplevel
    ignoreUnknownSignals: true
    function onDestroyed() { root.draggedToplevel = null }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (!root.opened || !event || !event.name) return
      var name = String(event.name)
      if (name.indexOf("monitor") !== -1 || name.indexOf("workspace") !== -1
          || name.indexOf("moveworkspace") === 0 || name === "createworkspace"
          || name === "destroyworkspace") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
      if (name.indexOf("window") !== -1 || name.indexOf("group") !== -1
          || name === "fullscreen" || name === "changefloatingmode"
          || name.indexOf("workspace") !== -1 || name === "focusedmon"
          || name === "movewindow" || name === "movewindowv2") {
        Hyprland.refreshToplevels()
      }
    }
  }

  onCardCountChanged: {
    if (root.selectedCardIndex >= root.cardCount)
      root.selectedCardIndex = root.cardCount - 1
  }
}
