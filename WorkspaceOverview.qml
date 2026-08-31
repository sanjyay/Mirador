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
  readonly property var overviewCardModel: root.workspaceModel
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

  readonly property var insertionZones: (root.draggedToplevel !== null)
    ? root.computeInsertionZones(root.workspaceModel, root.columns, root.rows,
        root.cardWidth, root.cardHeight, root.gridSpacing,
        root.usableX + root.gridGeometry.x, root.usableGridY + root.gridGeometry.y)
    : []

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

  function computeInsertionZones(workspaceIds, columnCount, rowCount, cWidth, cHeight, gSpacing, gX, gY) {
    var ids = (workspaceIds || []).slice().sort(function(a, b) { return a - b })
    if (ids.length === 0) return []

    var zones = []
    var count = ids.length
    var cols = Math.max(1, columnCount)
    var pillWidth = Style.space(32)

    function cardRect(index) {
      var row = Math.floor(index / cols)
      var col = index % cols
      return {
        x: gX + col * (cWidth + gSpacing),
        y: gY + row * (cHeight + gSpacing),
        width: cWidth,
        height: cHeight
      }
    }

    // 1. Before first workspace (if first > 1)
    if (ids[0] > 1) {
      var r0 = cardRect(0)
      zones.push({
        targetWorkspaceId: ids[0] - 1,
        x: r0.x - pillWidth - gSpacing / 2,
        y: r0.y,
        width: pillWidth,
        height: r0.height
      })
    }

    // 2. Between adjacent workspaces
    for (var i = 0; i < count - 1; i++) {
      var curId = ids[i]
      var nextId = ids[i + 1]
      if (nextId > curId + 1) {
        var rCur = cardRect(i)
        var zX = rCur.x + rCur.width + (gSpacing - pillWidth) / 2
        var zY = rCur.y
        zones.push({
          targetWorkspaceId: curId + 1,
          x: zX,
          y: zY,
          width: pillWidth,
          height: rCur.height
        })
      }
    }

    // 3. After last workspace
    var rLast = cardRect(count - 1)
    zones.push({
      targetWorkspaceId: ids[count - 1] + 1,
      x: rLast.x + rLast.width + (gSpacing - pillWidth) / 2,
      y: rLast.y,
      width: pillWidth,
      height: rLast.height
    })

    return zones
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
      var index = root.workspaceModel.indexOf(focused.id)
      if (index >= 0) return index
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
    var workspaceId = root.overviewCardModel[index]
    var ws = root.workspaceById(workspaceId)
    var occupied = Boolean(ws && ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0)
    root.activateWorkspace(ws, workspaceId, occupied)
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

  function open(payloadJson) {
    Hyprland.refreshMonitors()
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    root.targetScreen = root.focusedScreen()
    root.draggedToplevel = null
    root.selectedCardIndex = root.initialSelectedCardIndex()
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.draggedToplevel = null
    root.selectedCardIndex = -1
    root.opened = false
  }

  function dismiss() {
    root.draggedToplevel = null
    root.selectedCardIndex = -1
    root.opened = false
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
    if (workspace) workspace.activate()
    else root.dispatchWorkspace(workspaceId)

    if (occupied === false) {
      Qt.callLater(root.dismiss)
    }
  }

  // Plus button creation: creates contextual workspace AND KEEPS MIRADOR OPEN
  function createNewWorkspace() {
    var workspaceId = root.nextWorkspaceId()
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
    if (!address || workspaceId <= 0 || sourceId === workspaceId) return false

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
    if (root.normalizedAddress(toplevel)) root.draggedToplevel = toplevel
  }

  function endWindowDrag(toplevel) {
    if (root.draggedToplevel === toplevel) root.draggedToplevel = null
  }

  // ── Insertion Drop Zone Component ──────────────────────────────────────────
  component WorkspaceInsertionZone: BorderSurface {
    id: insertionRoot

    required property int targetWorkspaceId
    required property real targetX
    required property real targetY
    required property real targetWidth
    required property real targetHeight

    x: targetX
    y: targetY
    width: targetWidth
    height: targetHeight
    z: 40

    radius: Math.min(Style.cornerRadius, Style.space(8))
    color: dropArea.containsDrag
      ? Style.hoverFillFor(Color.menu.text, Color.accent)
      : Util.alpha(Color.menu.background, 0.50)
    borderSpec: Border.flat(
      dropArea.containsDrag
        ? Color.accent
        : Util.alpha(Color.accent, 0.40),
      dropArea.containsDrag ? Math.max(2, Style.focusBorderWidth) : 1)

    Behavior on color { ColorAnimation { duration: 80 } }

    Column {
      anchors.centerIn: parent
      spacing: Style.spacing.xs

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "+"
        color: dropArea.containsDrag ? Color.accent : Color.menu.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.title
        font.bold: true
        opacity: dropArea.containsDrag ? 1.0 : 0.60
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: String(insertionRoot.targetWorkspaceId)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        font.bold: true
        color: dropArea.containsDrag ? Color.accent : Color.menu.text
        opacity: dropArea.containsDrag ? 1.0 : 0.75
      }
    }

    DropArea {
      id: dropArea
      anchors.fill: parent
      keys: ["omarchy-window"]

      onDropped: function(drop) {
        if (!drop.source || !drop.source.toplevel) {
          drop.accepted = false
          return
        }
        drop.acceptProposedAction()
        root.moveWindowToWorkspace(drop.source.toplevel, insertionRoot.targetWorkspaceId)
      }
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
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.text === "+" || event.text === "=") {
          event.accepted = true
          root.createNewWorkspace()
        }
      }

      // ── Temporary Insertion Drop Zones (During Window Drag) ────────────────
      Repeater {
        model: root.insertionZones

        WorkspaceInsertionZone {
          required property var modelData

          targetWorkspaceId: modelData.targetWorkspaceId
          targetX: modelData.x
          targetY: modelData.y
          targetWidth: modelData.width
          targetHeight: modelData.height
        }
      }

      // The grid is positioned inside the usable area below any bar
      // rather than centred in the full panel, so cards never overlap the bar.
      Grid {
        id: workspaceGrid

        x: root.usableX + root.gridGeometry.x
        y: root.usableGridY + root.gridGeometry.y

        columns: root.columns
        spacing: root.gridSpacing

        Repeater {
          model: root.overviewCardModel

          WorkspaceCard {
            required property int modelData
            required property int index

            width: root.cardWidth
            height: root.cardHeight
            workspaceId: modelData
            workspace: root.workspaceById(modelData)
            livePreviews: root.opened && panel.visible
            draggedToplevel: root.draggedToplevel
            keyboardSelected: index === root.selectedCardIndex
            focused: Hyprland.focusedWorkspace !== null
              && Hyprland.focusedWorkspace.id === modelData
            onWorkspaceActivated: function(occupied) { root.activateWorkspace(workspace, modelData, occupied) }
            onWindowActivated: function(toplevel) { root.activateWindow(toplevel) }
            onWindowDragStarted: function(toplevel) { root.beginWindowDrag(toplevel) }
            onWindowDragFinished: function(toplevel) { root.endWindowDrag(toplevel) }
            onWindowDropped: function(toplevel) { root.moveWindowToWorkspace(toplevel, modelData) }
          }
        }
      }
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
