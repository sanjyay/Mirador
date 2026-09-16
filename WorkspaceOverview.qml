import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "WindowGeometry.js" as WindowGeometry
import "GestureHelper.js" as GestureHelper
import "WindowModel.js" as WindowModel

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool livePreviewsReady: false
  property bool demoMode: false
  property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  property var draggedToplevel: null
  property int selectedCardIndex: -1
  property string selectedWindowAddress: ""
  property string overviewMode: "normal"
  property string keybindMode: "normal"
  property string configuredModifier: "super"
  property string cycleUI: "full"
  property string activePresentation: "full"
  property bool cycled: false
  property int activeCycleModifier: 0
  property int initialWorkspaceId: -1
  property string initialActiveWindowAddress: ""
  property var closingWindowAddresses: ({})
  property int pendingRestoreWorkspaceId: -1
  property string pendingRestoreWindowAddress: ""
  property string pendingCarouselWindowAddress: ""
  property double pendingCarouselWindowExpiresAt: 0
  property int pendingWorkspaceNavigationTarget: -1
  property bool carouselAddressedActionHandled: false

  Timer {
    id: restoreCompositorFocusTimer
    interval: 50
    repeat: false
    onTriggered: {
      var workspaceId = root.pendingRestoreWorkspaceId
      var address = root.pendingRestoreWindowAddress
      root.pendingRestoreWorkspaceId = -1
      root.pendingRestoreWindowAddress = ""

      if (workspaceId > 0) root.dispatchWorkspace(workspaceId)
      if (!address) return
      if (Hyprland.usingLua)
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })")
      else
        Hyprland.dispatch("focuswindow address:" + address)
    }
  }

  function setOverviewMode(mode) {
    if (mode !== "normal" && mode !== "focused") return
    if (root.overviewMode === mode) return
    root.overviewMode = mode
    root.railScrollY = 0
    root.wheelDeltaAccumulatorX = 0
    root.wheelDeltaAccumulatorY = 0
    if (mode === "focused") {
      root.ensureCardVisible(root.selectedCardIndex)
    }
  }

  function toggleOverviewMode() {
    if (root.overviewMode === "focused") {
      root.setOverviewMode("normal")
    } else {
      root.setOverviewMode("focused")
    }
  }

  // ── Hold-to-cycle ("cycle" keybindMode) & Settings Probe ────────────────────
  Process {
    id: settingsProbe
    running: true
    command: ["sh", "-c",
      'f="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/mirador/settings.json"; ' +
      '[ ! -f "$f" ] && f="${XDG_CONFIG_HOME:-$HOME/.config}/mirador/settings.json"; ' +
      '[ -f "$f" ] && exec timeout 2 head -c 65536 -- "$f"']
    stdout: StdioCollector {
      onStreamFinished: {
        root.loadSettings(text)
      }
    }
  }

  function loadSettings(rawJson) {
    if (!rawJson || root.opened) return
    try {
      var s = JSON.parse(String(rawJson).trim())
      if (!root.opened) {
        if (s.keybindMode === "normal" || s.keybindMode === "cycle")
          root.keybindMode = s.keybindMode
        if (s.modifier && typeof s.modifier === "string")
          root.configuredModifier = s.modifier
        if (s.cycleUI === "compact" || s.cycleUI === "full" || s.cycleUI === "carousel")
          root.cycleUI = s.cycleUI
      }
    } catch (e) {}
  }

  Timer {
    id: holdWatchdog
    interval: 10000
    repeat: false
    onTriggered: {
      root.cycled = false
      root.activeCycleModifier = 0
    }
  }

  // Map the lightweight carousel shell before doing compositor IPC refreshes
  // or starting screencopy streams. This keeps the first frame responsive;
  // fresh model data and live captures arrive immediately afterward.
  Timer {
    id: postOpenRefreshTimer
    interval: 16
    repeat: false
    onTriggered: {
      if (!root.opened) return
      Hyprland.refreshMonitors()
      Hyprland.refreshWorkspaces()
      Hyprland.refreshToplevels()
      livePreviewStartTimer.restart()
    }
  }

  Timer {
    id: livePreviewStartTimer
    interval: 16
    repeat: false
    onTriggered: {
      if (root.opened) root.livePreviewsReady = true
    }
  }

  function isSummoningModifier(key) {
    if (root.activeCycleModifier === Qt.MetaModifier) {
      return key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R
          || key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R
    }
    if (root.activeCycleModifier === Qt.AltModifier) {
      return key === Qt.Key_Alt || key === Qt.Key_AltGr
    }
    if (root.activeCycleModifier === Qt.ControlModifier) {
      return key === Qt.Key_Control
    }

    var mod = String(root.configuredModifier || "super").toLowerCase()
    if (mod === "alt") {
      return key === Qt.Key_Alt || key === Qt.Key_AltGr
    }
    if (mod === "ctrl" || mod === "control") {
      return key === Qt.Key_Control
    }
    return key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R
        || key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R
  }

  function cycleStep(delta) {
    root.pendingWorkspaceNavigationTarget = -1
    root.cycled = true
    holdWatchdog.restart()
    var stepVal = delta < 0 ? -1 : 1
    root.moveCardSelection(stepVal, 0)
    if (root.activePresentation === "carousel") {
      var curItem = (root.selectedCardIndex >= 0 && root.selectedCardIndex < root.overviewCardModel.length)
        ? root.overviewCardModel[root.selectedCardIndex] : null
      var curWsId = curItem !== null && typeof curItem === "object" ? curItem.workspaceId : curItem
      if (typeof curWsId === "number" && curWsId > 0) {
        if (!Hyprland.focusedWorkspace || Hyprland.focusedWorkspace.id !== curWsId) {
          root.dispatchWorkspace(curWsId)
        }
      }
      if (carouselCycleView) {
        carouselCycleView.step(stepVal)
      }
    }
    if (root.demoMode && demoOverlay) {
      root.showDemoHint(stepVal < 0 ? "CYCLE PREV" : "CYCLE NEXT", false)
    }
  }

  function navigateToWorkspaceNumber(target) {
    if (target === null || target === undefined) return false

    var isScratch = (target === "scratchpad" || target === "special" || target === -1)
    var foundIndex = WindowModel.findWorkspaceCardIndex(root.overviewCardModel, target)

    // If target workspace is not yet in card model (e.g. not yet created in compositor),
    // dispatch workspace in Hyprland and refresh workspaces to populate the model
    if (foundIndex === -1 && !isScratch) {
      var targetNum = typeof target === "number" ? target : parseInt(target, 10)
      if (!isNaN(targetNum) && targetNum > 0) {
        root.pendingWorkspaceNavigationTarget = targetNum
        root.dispatchWorkspace(targetNum)
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
        foundIndex = WindowModel.findWorkspaceCardIndex(root.overviewCardModel, targetNum)
        if (foundIndex === -1) {
          Qt.callLater(root.resolvePendingWorkspaceNavigation)
          return true
        }
      }
    }

    if (foundIndex !== -1) {
      root.pendingWorkspaceNavigationTarget = -1
      root.selectedCardIndex = foundIndex
      // Workspace cards can be inserted or removed without changing this
      // numeric index. Always re-resolve the window for the workspace now
      // represented by the selected card.
      root.resetSelectedWindowSelection()
      Qt.callLater(root.resetSelectedWindowSelection)
      if (root.keybindMode === "cycle") {
        root.cycled = true
        holdWatchdog.restart()
      }
      if (root.activePresentation === "carousel") {
        var curFoundItem = (foundIndex >= 0 && foundIndex < root.overviewCardModel.length)
          ? root.overviewCardModel[foundIndex] : null
        var foundWsId = typeof curFoundItem === "object" ? curFoundItem.workspaceId : curFoundItem
        if (typeof foundWsId === "number" && foundWsId > 0) {
          if (!Hyprland.focusedWorkspace || Hyprland.focusedWorkspace.id !== foundWsId) {
            root.dispatchWorkspace(foundWsId)
          }
        }
        if (carouselCycleView) {
          carouselCycleView.step(0)
        }
      }
      if (root.demoMode && demoOverlay) {
        var label = isScratch ? "SCRATCHPAD" : ("WS " + (target === 10 ? "10" : target))
        root.showDemoHint("NAVIGATE → " + label, false)
      }
      return true
    }
    return false
  }

  function resolvePendingWorkspaceNavigation() {
    var target = root.pendingWorkspaceNavigationTarget
    if (!root.opened || target < 1) return false
    var foundIndex = WindowModel.findWorkspaceCardIndex(root.overviewCardModel, target)
    if (foundIndex === -1) return false
    return root.navigateToWorkspaceNumber(target)
  }

  function workspaceTargetFromEvent(event) {
    if (!event) return null

    var cleanMods = event.modifiers & ~(Qt.KeypadModifier | Qt.GroupSwitchModifier)
    var isSuper = Boolean(cleanMods & Qt.MetaModifier)
    var isCycleMod = Boolean(root.activeCycleModifier && (cleanMods & root.activeCycleModifier))
    var isNoMod = (cleanMods === Qt.NoModifier)

    if (root.activePresentation === "carousel") {
      if (!isSuper && !isCycleMod && !isNoMod) return null
    } else {
      if (!isSuper && !isCycleMod) return null
    }

    var k = event.key
    if (k >= Qt.Key_1 && k <= Qt.Key_9) {
      return k - Qt.Key_0
    }
    if (k === Qt.Key_0) {
      return 10
    }
    if (k === Qt.Key_S) {
      return "scratchpad"
    }

    if (event.text && event.text.length === 1) {
      if (event.text >= "1" && event.text <= "9") {
        return parseInt(event.text, 10)
      }
      if (event.text === "0") {
        return 10
      }
      if (event.text === "s" || event.text === "S") {
        return "scratchpad"
      }
    }

    return null
  }

  // ── Pinch gesture handling ──────────────────────────────────────────────────
  readonly property real pinchThreshold: GestureHelper.PINCH_THRESHOLD
  property bool pinchTriggered: false

  function handlePinchScale(scale) {
    if (root.pinchTriggered) return
    var targetMode = GestureHelper.shouldTriggerTransition(
      root.overviewMode, scale, root.pinchTriggered, root.pinchThreshold)
    if (targetMode) {
      root.pinchTriggered = true
      root.setOverviewMode(targetMode)
    }
  }

  function handlePinchActiveChanged(active) {
    if (!active) {
      root.pinchTriggered = false
    }
  }

  // ── Cursor wheel workspace navigation ─────────────────────────────
  // Mode-specific navigation:
  // In Normal mode:
  // - vertical wheel down = Right arrow / l -> moveCardSelection(1, 0)  (endless global cycle forward)
  // - vertical wheel up   = Left arrow / h  -> moveCardSelection(-1, 0) (endless global cycle backward)
  // In Focused mode:
  // - vertical wheel down = Down arrow / j -> moveCardSelection(0, 1)  (spatial row down)
  // - vertical wheel up   = Up arrow / k   -> moveCardSelection(0, -1) (spatial row up)
  // In both modes:
  // - horizontal wheel right = Right arrow / l -> moveCardSelection(1, 0)
  // - horizontal wheel left  = Left arrow / h  -> moveCardSelection(-1, 0)
  property real wheelDeltaAccumulatorX: 0
  property real wheelDeltaAccumulatorY: 0

  function handleWheelNavigation(deltaX, deltaY) {
    var threshold = 60
    if (Math.abs(deltaY) >= Math.abs(deltaX) && deltaY !== 0) {
      root.wheelDeltaAccumulatorX = 0
      root.wheelDeltaAccumulatorY += deltaY
      if (root.overviewMode === "normal") {
        if (root.wheelDeltaAccumulatorY <= -threshold) {
          root.moveCardSelection(1, 0)  // wheel down = global next (Right arrow / l)
          root.wheelDeltaAccumulatorY = 0
        } else if (root.wheelDeltaAccumulatorY >= threshold) {
          root.moveCardSelection(-1, 0) // wheel up = global previous (Left arrow / h)
          root.wheelDeltaAccumulatorY = 0
        }
      } else {
        if (root.wheelDeltaAccumulatorY <= -threshold) {
          root.moveCardSelection(0, 1)  // wheel down = Down arrow / j
          root.wheelDeltaAccumulatorY = 0
        } else if (root.wheelDeltaAccumulatorY >= threshold) {
          root.moveCardSelection(0, -1) // wheel up = Up arrow / k
          root.wheelDeltaAccumulatorY = 0
        }
      }
    } else if (deltaX !== 0) {
      root.wheelDeltaAccumulatorY = 0
      root.wheelDeltaAccumulatorX += deltaX
      if (root.wheelDeltaAccumulatorX >= threshold) {
        root.moveCardSelection(1, 0)  // wheel right = Right arrow / l
        root.wheelDeltaAccumulatorX = 0
      } else if (root.wheelDeltaAccumulatorX <= -threshold) {
        root.moveCardSelection(-1, 0) // wheel left = Left arrow / h
        root.wheelDeltaAccumulatorX = 0
      }
    }
  }

  function handleCardWheel(isPrimary, deltaX, deltaY) {
    if (root.overviewMode === "focused" && !isPrimary && root.railScrollNeeded) {
      root.scrollRail(deltaY)
    } else {
      root.handleWheelNavigation(deltaX, deltaY)
    }
  }

  // ── Bar geometry & Safe Viewport ────────────────────────────────────────────
  // Authoritative multi-tier bar detection:
  // 1. Live Omarchy `shell.bar` (exposes position, barSize, barHidden)
  // 2. Shell configuration `shell.barConfig` (position)
  // 3. Hyprland monitor IPC `reserved` struts ([left, top, right, bottom])
  readonly property var activeBar: shell ? shell.bar : null
  readonly property string configuredBarPosition: {
    if (activeBar && activeBar.position) return String(activeBar.position)
    if (shell && shell.barConfig && shell.barConfig.position) return String(shell.barConfig.position)
    return "top"
  }
  readonly property bool isBarHidden: activeBar ? Boolean(activeBar.barHidden) : false

  readonly property var targetMonitor: {
    var m = Hyprland.focusedMonitor
    if (m && root.targetScreen && m.name === root.targetScreen.name) return m
    var monValues = Hyprland.monitors ? Hyprland.monitors.values : []
    for (var i = 0; i < monValues.length; i++) {
      if (monValues[i] && root.targetScreen && monValues[i].name === root.targetScreen.name)
        return monValues[i]
    }
    return m
  }

  readonly property var monitorReserved: {
    var mon = root.targetMonitor
    if (mon && mon.lastIpcObject && mon.lastIpcObject.reserved && mon.lastIpcObject.reserved.length >= 4) {
      return mon.lastIpcObject.reserved
    }
    return [0, 0, 0, 0]
  }

  // Authoritative bar position & thickness resolution
  readonly property string barPosition: {
    if (root.isBarHidden) return ""
    var resL = root.monitorReserved[0] || 0
    var resT = root.monitorReserved[1] || 0
    var resR = root.monitorReserved[2] || 0
    var resB = root.monitorReserved[3] || 0
    if (resT > 0 && resT >= resB && resT >= resL && resT >= resR) return "top"
    if (resB > 0 && resB >= resT && resB >= resL && resB >= resR) return "bottom"
    if (resL > 0 && resL >= resR && resL >= resT && resL >= resB) return "left"
    if (resR > 0 && resR >= resL && resR >= resT && resR >= resB) return "right"
    return root.configuredBarPosition
  }

  readonly property int barPixels: {
    if (root.isBarHidden) return 0
    var pos = root.barPosition
    var monPixels = 0
    if (pos === "top") monPixels = root.monitorReserved[1] || 0
    else if (pos === "bottom") monPixels = root.monitorReserved[3] || 0
    else if (pos === "left") monPixels = root.monitorReserved[0] || 0
    else if (pos === "right") monPixels = root.monitorReserved[2] || 0

    var shellBarSize = (activeBar && activeBar.barSize > 0) ? activeBar.barSize : 0
    return Math.max(shellBarSize, monPixels)
  }

  // Inset for each edge in logical pixels, derived entirely from authoritative geometry
  readonly property int barInsetTop:    barPosition === "top"    ? barPixels : (root.monitorReserved[1] || 0)
  readonly property int barInsetBottom: barPosition === "bottom" ? barPixels : (root.monitorReserved[3] || 0)
  readonly property int barInsetLeft:   barPosition === "left"   ? barPixels : (root.monitorReserved[0] || 0)
  readonly property int barInsetRight:  barPosition === "right"  ? barPixels : (root.monitorReserved[2] || 0)

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

  // Optimized breathing outer margin & inter-card spacing to maximize preview dimensions
  readonly property real outerMargin: Math.max(16, Style.space(16))
  readonly property real gridSpacing: Style.space(24)

  // Safe area geometry calculation across any bar position (top/bottom/left/right)
  readonly property var safeArea: WindowGeometry.safeAreaGeometry(
    panel.width, panel.height, root.barPosition, root.barPixels, root.outerMargin, root.monitorReserved)

  // Usable panel area strictly bounded inside the safe rectangle
  readonly property real usableX:      safeArea.usableX
  readonly property real usableY:      safeArea.usableY
  readonly property real usableWidth:  safeArea.usableWidth
  readonly property real usableHeight: safeArea.usableHeight

  // Usable grid area across full usable panel
  readonly property real usableGridY: root.usableY
  readonly property real usableGridHeight: root.usableHeight

  readonly property var gridGeometry: WindowGeometry.overviewGridGeometry(
    cardCount, usableWidth, usableGridHeight, cardAspectRatio,
    gridSpacing)
  readonly property int columns: Math.max(1, gridGeometry.columns)
  readonly property int rows: Math.max(1, gridGeometry.rows)
  readonly property real cardWidth: Math.max(1, gridGeometry.cardWidth)
  readonly property real cardHeight: Math.max(1, gridGeometry.cardHeight)

  // ── Focused mode rail geometry & scrolling ─────────────────────────────────
  property real railScrollY: 0

  readonly property var focusedGeometry: {
    if (root.overviewMode !== "focused") return null
    var primIdx = root.selectedCardIndex >= 0 ? root.selectedCardIndex : 0
    return WindowGeometry.focusedOverviewGeometry(
      root.cardCount, primIdx, root.usableWidth, root.usableGridHeight,
      root.cardAspectRatio, root.gridSpacing)
  }
  readonly property var railGeometry: focusedGeometry ? focusedGeometry.rail : null
  readonly property real railX: railGeometry ? railGeometry.x : 0
  readonly property real railWidth: railGeometry ? railGeometry.width : 0
  readonly property real railHeight: railGeometry ? railGeometry.height : root.usableGridHeight
  readonly property real railContentHeight: railGeometry ? railGeometry.contentHeight : 0
  readonly property bool railScrollNeeded: railGeometry ? Boolean(railGeometry.scrollNeeded) : false
  readonly property real railScrollMax: Math.max(0, root.railContentHeight - root.railHeight)

  function scrollRail(deltaY) {
    if (!root.railScrollNeeded) return
    var step = (deltaY / 120.0) * Style.space(60)
    var target = root.railScrollY - step
    root.railScrollY = Math.max(0, Math.min(root.railScrollMax, target))
  }

  function ensureCardVisible(idx) {
    if (root.overviewMode !== "focused" || !root.railScrollNeeded) return
    var fg = root.focusedGeometry
    if (!fg || !fg.cards || idx < 0 || idx >= fg.cards.length) return
    var card = fg.cards[idx]
    if (!card) return

    var contentY = card.railContentY
    var cardH = card.height
    var viewH = root.railHeight
    var margin = root.gridSpacing

    if (contentY < root.railScrollY + margin) {
      root.railScrollY = Math.max(0, contentY - margin)
    } else if (contentY + cardH > root.railScrollY + viewH - margin) {
      root.railScrollY = Math.min(root.railScrollMax, contentY + cardH - viewH + margin)
    }
  }

  onSelectedCardIndexChanged: {
    root.ensureCardVisible(root.selectedCardIndex)
    root.resetSelectedWindowSelection()
    if (root.opened && root.activePresentation === "carousel") {
      var curItem = (root.selectedCardIndex >= 0 && root.selectedCardIndex < root.overviewCardModel.length)
        ? root.overviewCardModel[root.selectedCardIndex] : null
      var curWsId = curItem !== null && typeof curItem === "object" ? curItem.workspaceId : curItem
      if (typeof curWsId === "number" && curWsId > 0) {
        if (!Hyprland.focusedWorkspace || Hyprland.focusedWorkspace.id !== curWsId) {
          root.dispatchWorkspace(curWsId)
        }
      }
    }
  }

  // ── Workspace helpers ───────────────────────────────────────────────────────
  function isSpecialWorkspace(ws) {
    return WindowModel.isSpecialWorkspace(ws)
  }

  function specialWorkspaceName(ws) {
    return WindowModel.specialWorkspaceName(ws)
  }

  function workspaceWindowCount(ws) {
    if (!ws) return 0
    if (ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0)
      return ws.toplevels.values.length
    if (ws.lastIpcObject && typeof ws.lastIpcObject.windows === "number")
      return ws.lastIpcObject.windows
    var count = 0
    var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < toplevels.length; i++) {
      var t = toplevels[i]
      if (t && t.workspace && t.workspace.id === ws.id) {
        count++
      }
    }
    return count
  }

  function specialWorkspaces() {
    var specials = []
    var seenIds = {}
    var wsValues = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < wsValues.length; i++) {
      var ws = wsValues[i]
      if (!ws) continue
      if (root.isSpecialWorkspace(ws) && root.workspaceWindowCount(ws) > 0) {
        if (!seenIds[ws.id]) {
          seenIds[ws.id] = true
          specials.push(ws)
        }
      }
    }

    var tops = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var j = 0; j < tops.length; j++) {
      var tws = tops[j] ? tops[j].workspace : null
      if (tws && root.isSpecialWorkspace(tws) && !seenIds[tws.id]) {
        seenIds[tws.id] = true
        specials.push(tws)
      }
    }

    return specials
  }

  function toggleSpecialWorkspace(specialName) {
    var name = root.specialWorkspaceName(specialName)
    if (Hyprland.usingLua) {
      if (name.length > 0) {
        Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"" + name + "\")")
      } else {
        Hyprland.dispatch("hl.dsp.workspace.toggle_special()")
      }
    } else {
      if (name.length > 0) {
        Hyprland.dispatch("togglespecialworkspace " + name)
      } else {
        Hyprland.dispatch("togglespecialworkspace")
      }
    }
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < values.length; i++) {
      if (values[i] && (values[i].id === id || values[i].name === id)) return values[i]
    }
    var tops = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var j = 0; j < tops.length; j++) {
      var tws = tops[j] ? tops[j].workspace : null
      if (tws && (tws.id === id || tws.name === id)) return tws
    }
    return null
  }

  function workspaceIds() {
    var numericIds = []
    var values = Hyprland.workspaces ? Hyprland.workspaces.values : []

    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (!ws) continue
      var id = Number(ws.id)
      if (id > 0 && numericIds.indexOf(id) === -1) {
        numericIds.push(id)
      }
    }

    if (numericIds.length === 0) {
      var focused = Hyprland.focusedWorkspace
      if (focused && focused.id > 0) numericIds.push(focused.id)
      else numericIds.push(1)
    }

    numericIds.sort(function(left, right) { return left - right })

    var specials = root.specialWorkspaces()
    var result = numericIds.slice()
    for (var s = 0; s < specials.length; s++) {
      result.push(Number(specials[s].id))
    }
    return result
  }

  function contextualNextWorkspaceId(currentId, existingIds) {
    var c = Number(currentId) || 1
    if (c < 1) c = 1
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
      : (root.workspaceModel.length > 0 && root.workspaceModel[0] > 0 ? root.workspaceModel[0] : 1)
    return contextualNextWorkspaceId(currentId, root.workspaceModel)
  }

  function buildOverviewItems(workspaceIds, isDragging) {
    var raw = workspaceIds || []
    if (raw.length === 0) return []

    var numericIds = []
    var specialIds = []
    for (var i = 0; i < raw.length; i++) {
      var id = raw[i]
      var ws = root.workspaceById(id)
      if (root.isSpecialWorkspace(ws) || (typeof id === "number" && id < 0)) {
        specialIds.push(id)
      } else {
        numericIds.push(id)
      }
    }
    numericIds.sort(function(a, b) { return a - b })

    if (!isDragging) {
      var items = []
      for (var n = 0; n < numericIds.length; n++) {
        items.push({ workspaceId: numericIds[n], isInsertion: false, isScratchpad: false })
      }
      for (var s = 0; s < specialIds.length; s++) {
        items.push({ workspaceId: specialIds[s], isInsertion: false, isScratchpad: true })
      }
      return items
    }

    var items = []
    // 1. Before first workspace (if first > 1)
    if (numericIds.length > 0 && numericIds[0] > 1) {
      items.push({ workspaceId: numericIds[0] - 1, isInsertion: true, isScratchpad: false })
    }

    for (var j = 0; j < numericIds.length; j++) {
      // Add the real workspace
      items.push({ workspaceId: numericIds[j], isInsertion: false, isScratchpad: false })

      // If there is a gap before the next workspace, insert target (cur + 1)
      if (j < numericIds.length - 1) {
        if (numericIds[j + 1] > numericIds[j] + 1) {
          items.push({ workspaceId: numericIds[j] + 1, isInsertion: true, isScratchpad: false })
        }
      }
    }

    // 3. After last numeric workspace
    if (numericIds.length > 0) {
      items.push({ workspaceId: numericIds[numericIds.length - 1] + 1, isInsertion: true, isScratchpad: false })
    }

    // 4. Scratchpad cards appended at the end without insertion targets
    for (var k = 0; k < specialIds.length; k++) {
      items.push({ workspaceId: specialIds[k], isInsertion: false, isScratchpad: true })
    }

    return items
  }

  function computeInsertionTargets(workspaceIds) {
    var raw = workspaceIds || []
    var ids = []
    for (var k = 0; k < raw.length; k++) {
      if (raw[k] > 0) ids.push(raw[k])
    }
    ids.sort(function(a, b) { return a - b })
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

  function focusedCardGeom(idx) {
    if (root.overviewMode !== "focused" || idx < 0) return null
    var fg = root.focusedGeometry
    if (fg && fg.cards && idx < fg.cards.length) {
      return fg.cards[idx]
    }
    return null
  }

  function normalCardGeom(idx) {
    if (idx < 0 || !root.gridGeometry || !root.gridGeometry.cards) return null
    if (idx < root.gridGeometry.cards.length) {
      return root.gridGeometry.cards[idx]
    }
    return null
  }

  function slotWidth(idx) {
    if (root.overviewMode === "focused") {
      var card = root.focusedCardGeom(idx)
      if (card && card.width > 0) return Math.round(card.width)
    }
    var nCard = root.normalCardGeom(idx)
    if (nCard && nCard.width > 0) return Math.round(nCard.width)
    return Math.round(root.cardWidth)
  }

  function slotHeight(idx) {
    if (root.overviewMode === "focused") {
      var card = root.focusedCardGeom(idx)
      if (card && card.height > 0) return Math.round(card.height)
    }
    var nCard = root.normalCardGeom(idx)
    if (nCard && nCard.height > 0) return Math.round(nCard.height)
    return Math.round(root.cardHeight)
  }

  function slotX(idx) {
    if (idx < 0) return 0
    if (root.overviewMode === "focused") {
      var card = root.focusedCardGeom(idx)
      if (card) return Math.round(card.x)
    }
    var nCard = root.normalCardGeom(idx)
    if (nCard) return Math.round(nCard.x)
    var col = idx % root.columns
    return Math.round(root.gridGeometry.x + col * (root.cardWidth + root.gridSpacing))
  }

  function slotY(idx) {
    if (idx < 0) return 0
    if (root.overviewMode === "focused") {
      var card = root.focusedCardGeom(idx)
      if (card) {
        var yOffset = card.isPrimary ? 0 : root.railScrollY
        return Math.round(card.y - yOffset)
      }
    }
    var nCard = root.normalCardGeom(idx)
    if (nCard) return Math.round(nCard.y)
    var row = Math.floor(idx / root.columns)
    return Math.round(root.gridGeometry.y + row * (root.cardHeight + root.gridSpacing))
  }

  function workspaceNavigationItems() {
    var items = []
    var isDragging = root.draggedToplevel !== null
    var wsIds = root.workspaceModel || []

    for (var i = 0; i < wsIds.length; i++) {
      var wsId = wsIds[i]
      var slotIdx = root.slotIndexForWorkspace(wsId, isDragging)
      if (slotIdx < 0) continue

      var gx = root.slotX(slotIdx)
      var gy = root.slotY(slotIdx)
      var width = root.slotWidth(slotIdx)
      var height = root.slotHeight(slotIdx)
      var isPrimary = (root.overviewMode === "focused" && slotIdx === (root.selectedCardIndex >= 0 ? root.selectedCardIndex : 0))

      items.push({
        index: slotIdx,
        workspaceId: wsId,
        x: gx,
        y: gy,
        width: width,
        height: height,
        centerX: gx + width / 2,
        centerY: gy + height / 2,
        isInsertion: false,
        isPrimary: isPrimary,
        visualOrder: i
      })
    }
    return items
  }

  function cardIndexAfterMove(index, dx, dy, count, columnCount) {
    var navItems = root.workspaceNavigationItems()
    if (navItems && navItems.length > 0) {
      return WindowGeometry.cyclicCardMove(navItems, index, dx, dy)
    }

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
    root.pendingWorkspaceNavigationTarget = -1
    root.selectedCardIndex = root.cardIndexAfterMove(
      root.selectedCardIndex, dx, dy, root.cardCount, root.columns)
  }

  function isSelectedWindow(toplevel) {
    var address = root.normalizedAddress(toplevel)
    return address !== "" && address === root.selectedWindowAddress
  }

  function rememberPendingCarouselWindow() {
    var address = root.normalizedAddress(root.selectedWindowAddress)
    root.pendingCarouselWindowAddress = address
    root.pendingCarouselWindowExpiresAt = address ? Date.now() + 2000 : 0
  }

  function takePendingCarouselWindow() {
    var address = root.pendingCarouselWindowAddress
    var expiresAt = root.pendingCarouselWindowExpiresAt
    root.pendingCarouselWindowAddress = ""
    root.pendingCarouselWindowExpiresAt = 0
    if (!address || Date.now() > expiresAt) return ""
    return root.normalizedAddress(address)
  }

  function clearPendingCarouselWindow() {
    root.pendingCarouselWindowAddress = ""
    root.pendingCarouselWindowExpiresAt = 0
  }

  function toplevelForAddress(value) {
    var address = root.normalizedAddress(value)
    if (!address || !Hyprland.toplevels || !Hyprland.toplevels.values) return null
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      if (root.normalizedAddress(values[i]) === address) return values[i]
    }
    return null
  }

  function resetSelectedWindowSelection() {
    root.selectedWindowAddress = ""
    if (root.selectedCardIndex < 0 || root.selectedCardIndex >= root.overviewCardModel.length) return
    var item = root.overviewCardModel[root.selectedCardIndex]
    if (!item) return
    var workspaceId = typeof item === "object" ? item.workspaceId : item
    var target = root.activeToplevelForWorkspace(root.workspaceById(workspaceId) || workspaceId)
    root.selectedWindowAddress = root.normalizedAddress(target)
  }

  function moveSelectedWindow(dx, dy) {
    if (!carouselCycleView || root.activePresentation !== "carousel") return false
    return carouselCycleView.moveWindowSelection(dx, dy)
  }

  function dispatchDirectionalFocus(dx, dy) {
    var direction = dx < 0 ? "l" : (dx > 0 ? "r" : (dy < 0 ? "u" : (dy > 0 ? "d" : "")))
    if (!direction) return false
    if (Hyprland.usingLua)
      Hyprland.dispatch("hl.dsp.focus({ direction = \"" + direction + "\" })")
    else
      Hyprland.dispatch("movefocus " + direction)
    return true
  }

  function activateSelectedCard() {
    root.initialWorkspaceId = -1
    root.initialActiveWindowAddress = ""
    root.cycled = false
    root.activeCycleModifier = 0
    holdWatchdog.stop()
    var pendingWorkspaceTarget = root.pendingWorkspaceNavigationTarget
    if (pendingWorkspaceTarget > 0) {
      root.pendingWorkspaceNavigationTarget = -1
      root.dispatchWorkspace(pendingWorkspaceTarget)
      root.dismiss()
      return
    }
    var index = root.selectedCardIndex
    if (index < 0 || index >= root.cardCount) return
    var item = root.overviewCardModel[index]
    var workspaceId = typeof item === "object" ? item.workspaceId : item
    var isInsertion = typeof item === "object" ? Boolean(item.isInsertion) : false
    var ws = root.workspaceById(workspaceId)
    var isScratch = (typeof item === "object" && Boolean(item.isScratchpad))
                    || root.isSpecialWorkspace(ws)
                    || (typeof workspaceId === "number" && workspaceId < 0)

    if (isInsertion) {
      root.dispatchWorkspace(workspaceId)
      Hyprland.refreshWorkspaces()
      Hyprland.refreshToplevels()
    } else if (isScratch) {
      root.showDemoHint("TOGGLE SCRATCHPAD", false)
      var specialName = (ws && ws.name) ? ws.name : "scratchpad"
      root.toggleSpecialWorkspace(specialName)
    } else {
      if (ws) ws.activate()
      else root.dispatchWorkspace(workspaceId)
    }
    root.dismiss()
  }

  function normalizedAddress(toplevel) {
    var rawAddr = ""
    if (typeof toplevel === "string") {
      rawAddr = toplevel
    } else if (toplevel) {
      rawAddr = toplevel.address || (toplevel.toplevel && toplevel.toplevel.address)
        || (toplevel.lastIpcObject && toplevel.lastIpcObject.address) || ""
    }
    var address = String(rawAddr).trim().toLowerCase()
    if (!address.match(/^(0x)?[0-9a-f]+$/)) return ""
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
    var payload = null
    try {
      if (typeof payloadJson === "string" && payloadJson.length > 0)
        payload = JSON.parse(payloadJson)
      else if (typeof payloadJson === "object" && payloadJson !== null)
        payload = payloadJson
    } catch (e) {
      payload = null
    }

    // Global compositor bindings can be consumed before an exclusive
    // layer-shell client receives the matching key event. Route numeric
    // workspace navigation through IPC so carousel selection is deterministic,
    // while retaining normal desktop workspace switching when Mirador is shut.
    if (payload && payload.action === "navigateWorkspace") {
      var workspaceTarget = Number(payload.workspace)
      if (!isFinite(workspaceTarget) || workspaceTarget < 1 || workspaceTarget > 10
          || Math.floor(workspaceTarget) !== workspaceTarget) return
      if (root.opened) {
        root.navigateToWorkspaceNumber(workspaceTarget)
      } else {
        root.dispatchWorkspace(workspaceTarget)
      }
      return
    }

    // Compositor close bindings are consumed before an exclusive layer-shell
    // client receives the key event. Route the binding through this action so
    // carousel closes always use an explicit address and normal desktop closes
    // retain Hyprland's usual active-window behavior.
    if (payload && payload.action === "closeWindow") {
      if (root.opened) {
        root.closeActiveWindowInSelectedWorkspace()
      } else if (Hyprland.usingLua) {
        Hyprland.dispatch("hl.dsp.window.close()")
      } else {
        Hyprland.dispatch("killactive")
      }
      return
    }

    if (payload && payload.action === "navigateWindow") {
      var navDx = Number(payload.dx) || 0
      var navDy = Number(payload.dy) || 0
      if (root.opened) {
        if (root.activePresentation === "carousel") root.moveSelectedWindow(navDx, navDy)
        else root.moveCardSelection(navDx, navDy)
      } else {
        root.dispatchDirectionalFocus(navDx, navDy)
      }
      return
    }

    if (payload && payload.action === "moveWindowToWorkspace") {
      var moveTarget = Number(payload.workspace)
      if (!isFinite(moveTarget) || moveTarget < 1 || moveTarget > 10
          || Math.floor(moveTarget) !== moveTarget) return
      if (root.opened) {
        root.carouselAddressedActionHandled = true
        root.clearPendingCarouselWindow()
        root.moveSelectedWindowToWorkspace(moveTarget)
      } else {
        var pendingAddress = root.takePendingCarouselWindow()
        if (pendingAddress) {
          var pendingToplevel = root.toplevelForAddress(pendingAddress)
          if (pendingToplevel) root.moveWindowToWorkspace(pendingToplevel, moveTarget)
        } else {
          root.dispatchActiveWindowToWorkspace(moveTarget)
        }
      }
      return
    }

    var isCycleInvocation = false
    if (payload && payload.keybindMode === "cycle") {
      isCycleInvocation = true
    } else if (payload && payload.keybindMode === "normal") {
      isCycleInvocation = false
    } else if (payload && typeof payload.step === "number") {
      isCycleInvocation = true
    } else if (payload && (payload.cycleUI === "carousel" || payload.cycleUI === "compact")) {
      isCycleInvocation = true
    }

    var activeMod = (payload && payload.modifier && typeof payload.modifier === "string")
      ? String(payload.modifier).toLowerCase() : String(root.configuredModifier || "super").toLowerCase()

    if (payload && payload.modifier && typeof payload.modifier === "string") {
      root.configuredModifier = activeMod
    }

    // A step while already open is repeated keypress asking to cycle
    if (root.opened && payload && typeof payload.step === "number") {
      if (activeMod === "alt") root.activeCycleModifier = Qt.AltModifier
      else if (activeMod === "ctrl" || activeMod === "control") root.activeCycleModifier = Qt.ControlModifier
      else if (activeMod === "super") root.activeCycleModifier = Qt.MetaModifier
      var stepVal = payload.step < 0 ? -1 : 1
      if (root.keybindMode === "cycle") {
        root.cycleStep(stepVal)
      } else {
        root.moveCardSelection(stepVal, 0)
      }
      return
    }

    restoreCompositorFocusTimer.stop()
    root.pendingRestoreWorkspaceId = -1
    root.pendingRestoreWindowAddress = ""
    root.closingWindowAddresses = ({})
    root.clearPendingCarouselWindow()
    root.carouselAddressedActionHandled = false
    root.pendingWorkspaceNavigationTarget = -1
    root.selectedWindowAddress = ""
    root.targetScreen = root.focusedScreen()
    root.draggedToplevel = null
    root.selectedCardIndex = root.initialSelectedCardIndex()
    root.initialWorkspaceId = (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0)
      ? Hyprland.focusedWorkspace.id : 1
    root.initialActiveWindowAddress = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
    root.overviewMode = "normal"
    root.railScrollY = 0
    root.pinchTriggered = false
    root.wheelDeltaAccumulatorX = 0
    root.wheelDeltaAccumulatorY = 0
    root.cycled = false
    holdWatchdog.stop()

    if (isCycleInvocation) {
      root.keybindMode = "cycle"
      if (activeMod === "alt") {
        root.activeCycleModifier = Qt.AltModifier
      } else if (activeMod === "ctrl" || activeMod === "control") {
        root.activeCycleModifier = Qt.ControlModifier
      } else {
        root.activeCycleModifier = Qt.MetaModifier
      }
    } else {
      root.keybindMode = "normal"
      root.activeCycleModifier = 0
    }

    root.demoMode = Boolean(payload && payload.demo)
    if (payload && (payload.focused || payload.mode === "focused")) {
      root.overviewMode = "focused"
    }

    if (payload && (payload.cycleUI === "compact" || payload.cycleUI === "full" || payload.cycleUI === "carousel")) {
      root.activePresentation = payload.cycleUI
    } else if (payload && payload.carousel) {
      root.activePresentation = "carousel"
    } else if (payload && payload.compact) {
      root.activePresentation = "compact"
    } else if (payload && (payload.modifier === "alt" || payload.alt)) {
      // Alt modifier (or payload.alt) opens full Mirador overview from version 2.2
      root.activePresentation = "full"
    } else if (isCycleInvocation) {
      // Super+Tab (or non-alt cycle) uses configured cycleUI or default (carousel)
      if (root.configuredModifier === "alt" || root.cycleUI === "full") {
        root.activePresentation = "full"
      } else if (root.cycleUI === "compact") {
        root.activePresentation = "compact"
      } else {
        root.activePresentation = "carousel"
      }
    } else {
      root.activePresentation = "full"
    }

    // Make the layer visible before workspace activation, model refreshes, or
    // screencopy initialization. All remaining state changes in this handler
    // complete before Qt renders the first frame.
    root.livePreviewsReady = false
    root.opened = true

    if (root.keybindMode === "cycle" && payload && typeof payload.step === "number") {
      root.cycleStep(payload.step < 0 ? -1 : 1)
    } else if (root.keybindMode === "cycle") {
      root.cycleStep(1)
    }

    if (root.activePresentation === "carousel" && carouselCycleView) {
      carouselCycleView.resetTo(root.selectedCardIndex)
    }

    root.resetSelectedWindowSelection()

    keyCatcher.forceActiveFocus()
    postOpenRefreshTimer.restart()
    Qt.callLater(function() {
      keyCatcher.forceActiveFocus()
      if (root.demoMode && demoOverlay) {
        demoOverlay.showHint("MIRADOR DEMO", false)
      }
    })
  }

  function close() {
    var restoreWorkspaceId = root.keybindMode === "cycle" ? root.initialWorkspaceId : -1
    var restoreWindowAddress = root.keybindMode === "cycle"
      ? root.normalizedAddress(root.initialActiveWindowAddress) : ""
    root.initialWorkspaceId = -1
    root.initialActiveWindowAddress = ""
    root.cycled = false
    root.activeCycleModifier = 0
    holdWatchdog.stop()
    postOpenRefreshTimer.stop()
    livePreviewStartTimer.stop()
    root.livePreviewsReady = false
    root.demoMode = false
    root.draggedToplevel = null
    root.selectedCardIndex = -1
    root.selectedWindowAddress = ""
    root.pendingWorkspaceNavigationTarget = -1
    root.overviewMode = "normal"
    root.activePresentation = "full"
    root.keybindMode = "normal"
    root.railScrollY = 0
    root.pinchTriggered = false
    root.wheelDeltaAccumulatorX = 0
    root.wheelDeltaAccumulatorY = 0
    root.opened = false
    if (carouselCycleView) carouselCycleView.animatingEnabled = false
    if (demoOverlay) demoOverlay.hideHint()
    root.scheduleCompositorFocusRestore(restoreWorkspaceId, restoreWindowAddress)
  }

  function dismiss() {
    var restoreWorkspaceId = root.keybindMode === "cycle" ? root.initialWorkspaceId : -1
    var restoreWindowAddress = root.keybindMode === "cycle"
      ? root.normalizedAddress(root.initialActiveWindowAddress) : ""
    root.initialWorkspaceId = -1
    root.initialActiveWindowAddress = ""
    root.cycled = false
    root.activeCycleModifier = 0
    holdWatchdog.stop()
    postOpenRefreshTimer.stop()
    livePreviewStartTimer.stop()
    root.livePreviewsReady = false
    root.demoMode = false
    root.draggedToplevel = null
    root.selectedCardIndex = -1
    root.selectedWindowAddress = ""
    root.pendingWorkspaceNavigationTarget = -1
    root.overviewMode = "normal"
    root.activePresentation = "full"
    root.keybindMode = "normal"
    root.railScrollY = 0
    root.pinchTriggered = false
    root.wheelDeltaAccumulatorX = 0
    root.wheelDeltaAccumulatorY = 0
    root.opened = false
    if (carouselCycleView) carouselCycleView.animatingEnabled = false
    if (demoOverlay) demoOverlay.hideHint()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "mirador")
    root.scheduleCompositorFocusRestore(restoreWorkspaceId, restoreWindowAddress)
  }

  function scheduleCompositorFocusRestore(workspaceId, address) {
    if (!(workspaceId > 0) && !address) return
    root.pendingRestoreWorkspaceId = workspaceId
    root.pendingRestoreWindowAddress = address || ""
    restoreCompositorFocusTimer.restart()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // Workspace activation: switches Hyprland active workspace.
  // When clicking inside an empty workspace or scratchpad, transports/toggles that workspace and closes Mirador.
  // When clicking a non-empty workspace, switches active workspace and keeps Mirador open.
  function activateWorkspace(workspace, workspaceId, occupied) {
    root.initialWorkspaceId = -1
    root.initialActiveWindowAddress = ""
    root.cycled = false
    root.activeCycleModifier = 0
    holdWatchdog.stop()
    var isSpecial = root.isSpecialWorkspace(workspace)
      || (function() {
        for (var i = 0; i < root.overviewCardModel.length; i++) {
          var it = root.overviewCardModel[i]
          if (it && it.workspaceId === workspaceId) return Boolean(it.isScratchpad)
        }
        return typeof workspaceId === "number" && workspaceId < 0
      })()

    if (isSpecial) {
      root.showDemoHint("TOGGLE SCRATCHPAD", false)
      var specialName = (workspace && workspace.name) ? workspace.name : "scratchpad"
      root.toggleSpecialWorkspace(specialName)
      Qt.callLater(root.dismiss)
      return
    }

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
    root.initialWorkspaceId = -1
    root.initialActiveWindowAddress = ""
    root.cycled = false
    root.activeCycleModifier = 0
    holdWatchdog.stop()
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

  function activeToplevelForWorkspace(workspace) {
    if (!workspace && workspace !== 0) return null
    var wsObj = (typeof workspace === "object" && workspace !== null) ? workspace : root.workspaceById(workspace)
    var wsId = wsObj && wsObj.id !== undefined ? wsObj.id : (typeof workspace === "number" ? workspace : null)

    var toplevels = []
    // Prefer the global model because workspace.toplevels can keep a destroyed
    // object for another event-loop turn after a close.
    if (wsId !== null && Hyprland.toplevels && Hyprland.toplevels.values) {
      var allTops = Hyprland.toplevels.values
      for (var t = 0; t < allTops.length; t++) {
        var top = allTops[t]
        if (!top) continue
        var ipc = top.lastIpcObject || {}
        var tws = top.workspace || ipc.workspace
        if (tws && (tws.id === wsId || tws.name === wsId || String(tws.id) === String(wsId))) {
          toplevels.push(top)
        }
      }
    }

    // Fall back to the workspace-owned model only when the global collection
    // has not populated this workspace yet.
    if (toplevels.length === 0 && wsObj && wsObj.toplevels) {
      if (wsObj.toplevels.values) toplevels = wsObj.toplevels.values
      else if (Array.isArray(wsObj.toplevels)) toplevels = wsObj.toplevels
    }

    var activeAddr = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
    return WindowModel.selectCloseTarget(
      toplevels, activeAddr, root.recentClosingWindowAddresses(), root.selectedWindowAddress)
  }

  function recentClosingWindowAddresses() {
    var recent = ({})
    var now = Date.now()
    for (var address in root.closingWindowAddresses) {
      if (now - Number(root.closingWindowAddresses[address]) < 1500) recent[address] = true
    }
    return recent
  }

  function markWindowClosing(value) {
    var address = root.normalizedAddress(value)
    if (!address || root.closingWindowAddresses[address]) return
    var next = ({})
    for (var key in root.closingWindowAddresses) next[key] = root.closingWindowAddresses[key]
    next[address] = Date.now()
    root.closingWindowAddresses = next
  }

  // Closes a window in Hyprland and refreshes UI WITHOUT exiting Mirador
  function closeWindow(toplevel) {
    if (!toplevel) return false
    var address = root.normalizedAddress(toplevel)
    if (!address) return false
    root.markWindowClosing(address)
    var app = root.appNameFor(toplevel)
    if (root.demoMode && demoOverlay) {
      root.showDemoHint(app ? ("CLOSE → " + app) : "CLOSE WINDOW", false)
    }

    if (Hyprland.usingLua) {
      Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + address + "\" })")
    } else {
      Hyprland.dispatch("closewindow address:" + address)
    }

    if (carouselCycleView) {
      carouselCycleView.toplevelRevision++
    }

    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()

    if (root.keybindMode === "cycle") {
      root.cycled = true
      holdWatchdog.restart()
    }
    Qt.callLater(root.resetSelectedWindowSelection)
    return true
  }

  // Closes active window in currently selected workspace card and keeps Mirador open
  function closeActiveWindowInSelectedWorkspace() {
    if (root.selectedCardIndex < 0 || root.selectedCardIndex >= root.overviewCardModel.length) {
      return false
    }
    var currentItem = root.overviewCardModel[root.selectedCardIndex]
    if (!currentItem) return false

    var currentWsId = typeof currentItem === "object" ? currentItem.workspaceId : currentItem
    var ws = root.workspaceById(currentWsId)
    var targetToplevel = root.activeToplevelForWorkspace(ws || currentWsId)
    if (!targetToplevel) {
      if (root.demoMode && demoOverlay) {
        root.showDemoHint("EMPTY WORKSPACE", false)
      }
      return false
    }
    return root.closeWindow(targetToplevel)
  }

  function dispatchActiveWindowToWorkspace(workspaceId) {
    if (workspaceId < 1 || workspaceId > 10) return false
    if (Hyprland.usingLua) {
      Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + workspaceId + "\" })")
    } else {
      Hyprland.dispatch("movetoworkspace " + workspaceId)
    }
    return true
  }

  function moveSelectedWindowToWorkspace(workspaceId) {
    if (root.selectedCardIndex < 0 || root.selectedCardIndex >= root.overviewCardModel.length) {
      return false
    }
    var currentItem = root.overviewCardModel[root.selectedCardIndex]
    if (!currentItem || (typeof currentItem === "object" && currentItem.isInsertion)) return false

    var currentWsId = typeof currentItem === "object" ? currentItem.workspaceId : currentItem
    var targetToplevel = root.activeToplevelForWorkspace(root.workspaceById(currentWsId) || currentWsId)
    if (!targetToplevel) {
      root.showDemoHint("EMPTY WORKSPACE", false)
      return false
    }

    var moved = root.moveWindowToWorkspace(targetToplevel, workspaceId)
    if (moved) Qt.callLater(root.resetSelectedWindowSelection)
    return moved
  }

  function moveWindowToWorkspace(toplevel, workspaceId) {
    var address = root.normalizedAddress(toplevel)
    var sourceId = root.sourceWorkspaceId(toplevel)
    var targetWs = root.workspaceById(workspaceId)
    var isTargetSpecial = root.isSpecialWorkspace(targetWs)
      || (function() {
        for (var i = 0; i < root.overviewCardModel.length; i++) {
          var it = root.overviewCardModel[i]
          if (it && it.workspaceId === workspaceId) return Boolean(it.isScratchpad)
        }
        return typeof workspaceId === "number" && workspaceId < 0
      })()

    if (!address || (!isTargetSpecial && workspaceId <= 0) || sourceId === workspaceId) {
      if (demoOverlay) demoOverlay.hideHint()
      return false
    }

    var app = root.appNameFor(toplevel)
    var targetStr = ""

    if (isTargetSpecial) {
      var targetWs = root.workspaceById(workspaceId)
      var specialName = (targetWs && targetWs.name) ? targetWs.name : "special:scratchpad"
      if (specialName.indexOf("special:") !== 0 && specialName !== "special") {
        specialName = "special:" + specialName
      }
      targetStr = specialName
      root.showDemoHint(app ? (app + " → SCRATCHPAD") : "MOVE → SCRATCHPAD", false)
    } else {
      targetStr = String(workspaceId)
      root.showDemoHint(app ? (app + " → WS " + workspaceId) : ("MOVE → WS " + workspaceId), false)
    }

    root.draggedToplevel = null
    if (Hyprland.usingLua) {
      Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + targetStr
        + "\", window = \"address:" + address + "\", follow = false })")
    } else {
      Hyprland.dispatch("movetoworkspacesilent " + targetStr + ",address:" + address)
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
      color: root.activePresentation === "compact" ? Util.alpha("#000000", 0.35) : "transparent"
      Behavior on color {
        ColorAnimation { duration: 100 }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
      onWheel: function(wheel) {
        root.handleWheelNavigation(wheel.angleDelta.x, wheel.angleDelta.y)
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      property bool returnHandled: false

      // ── Cursor wheel arrow-key workspace navigation ─────────────────────────
      WheelHandler {
        id: catcherWheelHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          root.handleWheelNavigation(event.angleDelta.x, event.angleDelta.y)
        }
      }

      onTabRequested: function(direction) {
        if (root.keybindMode === "cycle") {
          root.cycleStep(direction)
        } else {
          root.moveCardSelection(direction, 0)
        }
      }

      onMoveRequested: function(dx, dy) {
        if (root.cycled) holdWatchdog.restart()
        if (root.activePresentation !== "carousel" || !root.moveSelectedWindow(dx, dy)) {
          root.moveCardSelection(dx, dy)
        }
      }
      onReturnRequested: {
        keyCatcher.returnHandled = true
        root.activateSelectedCard()
      }
      onActivateRequested: {
        if (keyCatcher.returnHandled) {
          keyCatcher.returnHandled = false
          return
        }
        root.toggleOverviewMode()
      }
      onCloseRequested: root.dismiss()

      Keys.onPressed: function(event) {
        if (root.cycled) holdWatchdog.restart()
        if (event.modifiers & Qt.MetaModifier) {
          root.activeCycleModifier = Qt.MetaModifier
        } else if (event.modifiers & Qt.AltModifier) {
          root.activeCycleModifier = Qt.AltModifier
        } else if (event.modifiers & Qt.ControlModifier) {
          root.activeCycleModifier = Qt.ControlModifier
        }

        if (root.demoMode && demoOverlay) {
          demoOverlay.handleKeyEvent(event)
        }
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.text === "+" || event.text === "=") {
          event.accepted = true
          root.createNewWorkspace()
          return
        }

        var targetWs = root.workspaceTargetFromEvent(event)
        var isCarouselWindowMove = root.activePresentation === "carousel"
          && typeof targetWs === "number"
          && Boolean(event.modifiers & Qt.MetaModifier)
          && Boolean(event.modifiers & Qt.ShiftModifier)
        if (isCarouselWindowMove) {
          // This key is also handled by Hyprland's Super+Shift+N binding.
          // Preserve the source card and explicit window address until that
          // asynchronous IPC action arrives; do not reinterpret N as carousel
          // workspace navigation.
          root.rememberPendingCarouselWindow()
          event.accepted = true
          return
        }
        if (targetWs !== null && root.navigateToWorkspaceNumber(targetWs)) {
          event.accepted = true
          if (root.activePresentation === "carousel" && root.keybindMode !== "cycle" && (event.modifiers & Qt.MetaModifier)) {
            root.activateSelectedCard()
          }
          return
        }
      }

      Keys.onReleased: function(event) {
        if (event.isAutoRepeat) return
        if (root.keybindMode !== "cycle" || !root.cycled) return
        if (!root.isSummoningModifier(event.key)) return

        root.cycled = false
        root.activeCycleModifier = 0
        holdWatchdog.stop()
        if (!root.carouselAddressedActionHandled) root.rememberPendingCarouselWindow()
        root.carouselAddressedActionHandled = false
        root.activateSelectedCard()
        event.accepted = true
      }

      // ── Two-finger pinch handler (native QtQuick pointer handler) ───────────
      PinchHandler {
        id: pinchHandler
        target: null
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onActiveChanged: {
          root.handlePinchActiveChanged(active)
        }
        onScaleChanged: function(delta) {
          var s = (activeScale > 0) ? activeScale : scale
          root.handlePinchScale(s)
        }
        onUpdated: {
          var s = (activeScale > 0) ? activeScale : scale
          root.handlePinchScale(s)
        }
      }

      // ── Cards Viewport Container (Clips to usable overview bounds) ──────────
      Item {
        id: cardsContainer
        x: root.usableX
        y: root.usableGridY
        width: root.usableWidth
        height: root.usableGridHeight
        clip: true
        visible: root.activePresentation !== "compact" && root.activePresentation !== "carousel"

        // ── Secondary Rail Wheel Area (Scrolls rail without activating) ───────
        MouseArea {
          id: railWheelArea
          x: root.railX
          y: 0
          width: root.railWidth
          height: parent.height
          visible: root.overviewMode === "focused" && root.railScrollNeeded
          z: 0
          acceptedButtons: Qt.NoButton
          onWheel: function(wheel) {
            root.scrollRail(wheel.angleDelta.y)
          }
        }

        // ── Real Workspace Cards (Persistent across drag transitions) ──────────
        Repeater {
          model: root.workspaceModel

          WorkspaceCard {
            required property int modelData
            required property int index

            readonly property int slotIndex: root.slotIndexForWorkspace(modelData, root.draggedToplevel !== null)
            readonly property var overviewItem: (slotIndex >= 0 && slotIndex < root.overviewCardModel.length) ? root.overviewCardModel[slotIndex] : null

            x: root.slotX(slotIndex)
            y: root.slotY(slotIndex)
            width: root.slotWidth(slotIndex)
            height: root.slotHeight(slotIndex)
            visible: {
              if (root.overviewMode !== "focused") return true
              if (slotIndex === (root.selectedCardIndex >= 0 ? root.selectedCardIndex : 0)) return true
              var cy = y
              var ch = height
              return (cy + ch > -root.gridSpacing && cy < root.usableGridHeight + root.gridSpacing)
            }

            overview: root
            workspaceId: modelData
            workspace: root.workspaceById(modelData)
            isSpecial: Boolean(overviewItem && overviewItem.isScratchpad)
            livePreviews: root.opened && root.livePreviewsReady && panel.visible && root.activePresentation !== "compact" && root.activePresentation !== "carousel"
            draggedToplevel: root.draggedToplevel
            keyboardSelected: slotIndex === root.selectedCardIndex
            focused: Hyprland.focusedWorkspace !== null
            onWorkspaceActivated: function(occupied) {
              if (root.overviewMode === "focused" && root.selectedCardIndex !== slotIndex) {
                root.selectedCardIndex = slotIndex
                return
              }
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
            width: root.slotWidth(slotIndex)
            height: root.slotHeight(slotIndex)

            overview: root
            targetWorkspaceId: modelData
            draggedToplevel: root.draggedToplevel
            onWindowDropped: function(toplevel) { root.moveWindowToWorkspace(toplevel, modelData) }
          }
        }
      }

      // ── Compact Cycle Switcher (Active in compact cycle mode) ──────────────
      CompactCycleView {
        id: compactCycleView
        anchors.centerIn: parent
        visible: root.activePresentation === "compact"
        overview: root
        livePreviews: root.opened && root.livePreviewsReady && panel.visible && root.activePresentation === "compact"
      }

      // ── Continuous Carousel Switcher (Active in carousel cycle mode) ──────
      CarouselCycleView {
        id: carouselCycleView
        anchors.fill: parent
        visible: root.activePresentation === "carousel"
        overview: root
        livePreviews: root.opened && root.livePreviewsReady && panel.visible && root.activePresentation === "carousel"
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
        if (root.pendingWorkspaceNavigationTarget > 0)
          Qt.callLater(root.resolvePendingWorkspaceNavigation)
      }
      if (name.indexOf("window") !== -1 || name.indexOf("group") !== -1
          || name === "fullscreen" || name === "changefloatingmode"
          || name.indexOf("workspace") !== -1 || name === "focusedmon"
          || name === "movewindow" || name === "movewindowv2") {
        Hyprland.refreshToplevels()
        if (carouselCycleView) {
          carouselCycleView.toplevelRevision++
        }
        if (name === "closewindow" || name === "destroywindow") {
          var closingAddress = String(event.data || "").split(",")[0]
          root.markWindowClosing(closingAddress)
          if (root.normalizedAddress(closingAddress) === root.selectedWindowAddress)
            Qt.callLater(root.resetSelectedWindowSelection)
        }
      }

      // When in carousel presentation, sync selection with compositor workspace switches
      if (root.activePresentation === "carousel" && root.keybindMode !== "cycle"
          && (name === "workspace" || name === "workspacev2")) {
        var rawData = String(event.data || "").trim()
        var targetWs = null
        if (name === "workspacev2") {
          var parts = rawData.split(",")
          if (parts.length > 0) {
            var wsIdNum = parseInt(parts[0], 10)
            if (!isNaN(wsIdNum)) {
              targetWs = wsIdNum
            } else if (parts[0].indexOf("special") === 0) {
              targetWs = "scratchpad"
            }
          }
        } else {
          if (rawData.indexOf("special") === 0) {
            targetWs = "scratchpad"
          } else {
            var num = parseInt(rawData, 10)
            if (!isNaN(num)) targetWs = num
          }
        }

        if (targetWs !== null) {
          root.navigateToWorkspaceNumber(targetWs)
        }
      }
    }

    function onFocusedWorkspaceChanged() {
      if (!root.opened || root.activePresentation !== "carousel" || root.keybindMode === "cycle") return
      var fw = Hyprland.focusedWorkspace
      if (fw) {
        var isSpecial = WindowModel.isSpecialWorkspace(fw)
        var target = isSpecial ? "scratchpad" : Number(fw.id)
        if (target) {
          root.navigateToWorkspaceNumber(target)
        }
      }
    }
  }

  onCardCountChanged: {
    if (root.selectedCardIndex >= root.cardCount)
      root.selectedCardIndex = root.cardCount - 1
  }

  onOverviewCardModelChanged: {
    if (root.pendingWorkspaceNavigationTarget > 0)
      Qt.callLater(root.resolvePendingWorkspaceNavigation)
  }
}
