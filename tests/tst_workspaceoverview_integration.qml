import QtQuick 2.15
import QtTest 1.3
import "../WindowGeometry.js" as WindowGeometry

TestCase {
  name: "WorkspaceOverviewIntegration"

  function workspaceOverviewSource() {
    var request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../WorkspaceOverview.qml"), false)
    request.send()
    verify(request.status === 0 || request.status === 200)
    return request.responseText
  }

  function workspaceCardSource() {
    var request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../WorkspaceCard.qml"), false)
    request.send()
    verify(request.status === 0 || request.status === 200)
    return request.responseText
  }

  function workspaceInsertionCardSource() {
    var request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../InsertionWorkspaceCard.qml"), false)
    request.send()
    verify(request.status === 0 || request.status === 200)
    return request.responseText
  }

  function test_blurNamespaceRemainsStable() {
    var source = workspaceOverviewSource()
    verify(/WlrLayershell\.namespace\s*:\s*"omarchy-workspace-overview"/.test(source))
  }

  function test_keyboardFocusRemainsExclusive() {
    var source = workspaceOverviewSource()
    verify(/WlrLayershell\.keyboardFocus\s*:\s*WlrKeyboardFocus\.Exclusive/.test(source))
  }

  function test_groupModelRefreshesAfterIpcObjectChanges() {
    var source = workspaceCardSource()
    verify(/onLastIpcObjectChanged\s*\(\)\s*\{\s*root\.toplevelRevision\+\+\s*\}/.test(source))
    verify(/onActiveToplevelChanged\s*\(\)\s*\{\s*root\.toplevelRevision\+\+\s*\}/.test(source))
    verify(/WindowModel\.resolveWorkspacePreviews/.test(source))
  }

  function test_groupEventsUseExistingToplevelRefreshPath() {
    var source = workspaceOverviewSource()
    verify(/name\.indexOf\("group"\)\s*!==\s*-1/.test(source))
    verify(/name\.indexOf\("group"\)[\s\S]*Hyprland\.refreshToplevels\(\)/.test(source))
  }

  function test_workspaceIdsOnlyEnumeratesActualExistingWorkspaces() {
    var source = workspaceOverviewSource()
    // Must NOT contain hardcoded [1, 2, 3, 4, 5] initialization
    verify(!/var ids\s*=\s*\[\s*1\s*,\s*2\s*,\s*3\s*,\s*4\s*,\s*5\s*\]/.test(source))
    // Model must derive from actual workspace collection via buildOverviewItems
    verify(/readonly property var overviewCardModel\s*:\s*root\.buildOverviewItems/.test(source))
  }

  function test_topPlusSignAndHeaderRemoved() {
    var source = workspaceOverviewSource()
    // Must NOT contain overviewHeader, top plusButton, Workspaces title, or 3-dot menu
    verify(!/id\s*:\s*overviewHeader/.test(source))
    verify(!/id\s*:\s*plusButton/.test(source))
    verify(!/text\s*:\s*"Workspaces"/.test(source))
    verify(!/id\s*:\s*menuButton/.test(source))
    verify(!/id\s*:\s*overviewMenu/.test(source))
    verify(!/component\s*MenuActionItem/.test(source))
  }

  function test_workspaceCardHeaderOnlyHasNumberBadge() {
    var source = workspaceCardSource()
    // Header layout containing badge only
    verify(/id\s*:\s*cardHeader/.test(source))
    verify(/id\s*:\s*badge/.test(source))
    // Must NOT contain workspace name text or property
    verify(!/id\s*:\s*nameLabel/.test(source))
    verify(!/workspaceDisplayName/.test(source))
  }

  function test_workspaceKeyboardShortcutsForPlusAndEqual() {
    var source = workspaceOverviewSource()
    // Must handle Plus, Equal, "+", and "=" keys
    verify(/Keys\.onPressed/.test(source))
    verify(/Qt\.Key_Plus/.test(source))
    verify(/Qt\.Key_Equal/.test(source))
    verify(/createNewWorkspace\(\)/.test(source))
  }

  function test_emptyWorkspaceDismissalClickSemantics() {
    var source = workspaceOverviewSource()
    // activateWorkspace dismisses if occupied === false
    verify(/if\s*\(\s*occupied\s*===\s*false\s*\)\s*\{\s*Qt\.callLater\(\s*root\.dismiss\s*\)/.test(source))
    // activateWindow focuses window and dismisses overview
    verify(/function\s*activateWindow\s*\([\s\S]*?\)\s*\{[\s\S]*?root\.dismiss[\s\S]*?\}/.test(source))
  }

  function test_activeCardHighlightingAndStyling() {
    var source = workspaceCardSource()
    // Active border uses Color.accent with activeBorderWidth
    verify(/focused[\s\S]*Color\.accent[\s\S]*activeBorderWidth/.test(source))
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

  function test_contextualNextWorkspaceAlgorithm() {
    // Example A: existing 1, 3, 4, 5 with current 3 -> creates 2
    compare(contextualNextWorkspaceId(3, [1, 3, 4, 5]), 2)

    // Example B: existing 1, 3, 5 with current 3 -> creates 2
    compare(contextualNextWorkspaceId(3, [1, 3, 5]), 2)

    // Example C: existing 1, 2, 3, 5 with current 3 -> creates 4
    compare(contextualNextWorkspaceId(3, [1, 2, 3, 5]), 4)

    // Example D (Outward search): existing 1, 2, 3, 4, 5 with current 3 -> creates 6
    compare(contextualNextWorkspaceId(3, [1, 2, 3, 4, 5]), 6)

    // Equal distance prefers lower side: existing [2] with current 2 -> creates 1
    compare(contextualNextWorkspaceId(2, [2]), 1)
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

  function test_insertionDropZoneTargets() {
    // Basic contiguous [1, 2, 3] -> only append target [4]
    var t1 = computeInsertionTargets([1, 2, 3])
    compare(t1.length, 1)
    compare(t1[0], 4)

    // With leading gap [3, 4] -> prepend target [2] and append [5]
    var t2 = computeInsertionTargets([3, 4])
    compare(t2.length, 2)
    compare(t2[0], 2)
    compare(t2[1], 5)

    // With middle gap [1, 3, 5] -> targets [2, 4, 6]
    var t3 = computeInsertionTargets([1, 3, 5])
    compare(t3.length, 3)
    compare(t3[0], 2)
    compare(t3[1], 4)
    compare(t3[2], 6)

    // Single workspace [1] -> target [2]
    var t4 = computeInsertionTargets([1])
    compare(t4.length, 1)
    compare(t4[0], 2)

    // Single workspace > 1 [2] -> targets [1, 3]
    var t5 = computeInsertionTargets([2])
    compare(t5.length, 2)
    compare(t5[0], 1)
    compare(t5[1], 3)
  }

  function test_insertionWorkspaceCardStructure() {
    var source = workspaceInsertionCardSource()
    // Must contain BorderSurface, KDE-style header badge, centered drop cue, and full DropArea
    verify(/BorderSurface/.test(source))
    verify(/id\s*:\s*cardHeader/.test(source))
    verify(/id\s*:\s*badge/.test(source))
    verify(/id\s*:\s*dropArea/.test(source))
    verify(/keys\s*:\s*\[\s*"omarchy-window"\s*\]/.test(source))
    verify(/Drop to create WS/.test(source))
  }

  function buildOverviewItems(workspaceIds, isDragging) {
    var raw = workspaceIds || []
    if (raw.length === 0) return []

    var numericIds = []
    var specialIds = []
    for (var i = 0; i < raw.length; i++) {
      var id = raw[i]
      if (id > 0) numericIds.push(id)
      else specialIds.push(id)
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

  function test_buildOverviewItemsInterleaving() {
    // Resting state: [1, 3, 5] -> 3 items, all isInsertion === false
    var resting = buildOverviewItems([1, 3, 5], false)
    compare(resting.length, 3)
    compare(resting[0].workspaceId, 1)
    compare(resting[0].isInsertion, false)
    compare(resting[1].workspaceId, 3)
    compare(resting[1].isInsertion, false)
    compare(resting[2].workspaceId, 5)
    compare(resting[2].isInsertion, false)

    // Drag state: [1, 3, 5] -> [1 (ws), 2 (ins), 3 (ws), 4 (ins), 5 (ws), 6 (ins)]
    var dragging135 = buildOverviewItems([1, 3, 5], true)
    compare(dragging135.length, 6)
    compare(dragging135[0].workspaceId, 1)
    compare(dragging135[0].isInsertion, false)
    compare(dragging135[1].workspaceId, 2)
    compare(dragging135[1].isInsertion, true)
    compare(dragging135[2].workspaceId, 3)
    compare(dragging135[2].isInsertion, false)
    compare(dragging135[3].workspaceId, 4)
    compare(dragging135[3].isInsertion, true)
    compare(dragging135[4].workspaceId, 5)
    compare(dragging135[4].isInsertion, false)
    compare(dragging135[5].workspaceId, 6)
    compare(dragging135[5].isInsertion, true)

    // Drag state: [3, 5] -> [2 (ins), 3 (ws), 4 (ins), 5 (ws), 6 (ins)]
    var dragging35 = buildOverviewItems([3, 5], true)
    compare(dragging35.length, 5)
    compare(dragging35[0].workspaceId, 2)
    compare(dragging35[0].isInsertion, true)
    compare(dragging35[1].workspaceId, 3)
    compare(dragging35[1].isInsertion, false)
    compare(dragging35[2].workspaceId, 4)
    compare(dragging35[2].isInsertion, true)
    compare(dragging35[3].workspaceId, 5)
    compare(dragging35[3].isInsertion, false)
    compare(dragging35[4].workspaceId, 6)
    compare(dragging35[4].isInsertion, true)
  }

  function test_demoModePayloadAndOverlayIntegration() {
    var source = workspaceOverviewSource()
    // Must contain demoMode property, DemoInputOverlay integration, and demo payload extraction
    verify(/property bool demoMode\s*:\s*false/.test(source))
    verify(/DemoInputOverlay/.test(source))
    verify(/root\.demoMode\s*=\s*Boolean\(payload\s*&&\s*payload\.demo\)/.test(source))
    verify(/demoOverlay\.handleKeyEvent/.test(source))
  }

  function test_workspaceDimmingAndFocusStyling() {
    var source = workspaceCardSource()
    // Must define isCurrent property reflecting keyboard and initial focus selection
    verify(/readonly property bool isCurrent\s*:\s*root\.keyboardSelected/.test(source))
    // Must define cardOpacity with smooth animation Behavior
    verify(/readonly property real cardOpacity/.test(source))
    verify(/opacity\s*:\s*root\.cardOpacity/.test(source))
    verify(/Behavior on opacity/.test(source))
    // Inactive card dimming level should be 0.90 and active level 1.0
    verify(/root\.isCurrent\s*\?\s*1\.0\s*:/.test(source))
    verify(/0\.90/.test(source))
  }

  function test_workspaceCyclicNavigationIntegration() {
    var source = workspaceOverviewSource()
    // Overview must define workspaceNavigationItems and delegate cardIndexAfterMove to WindowGeometry.cyclicCardMove
    verify(/function workspaceNavigationItems\(\)/.test(source))
    verify(/WindowGeometry\.cyclicCardMove/.test(source))
    verify(/isInsertion\s*:\s*false/.test(source))
  }

  function test_focusedOverviewModePropertiesAndKeyHandling() {
    var source = workspaceOverviewSource()
    // Overview must declare overviewMode defaulting to "normal"
    verify(/property string overviewMode\s*:\s*"normal"/.test(source))
    // Overview must have toggleOverviewMode()
    verify(/function toggleOverviewMode\(\)/.test(source))
    // Return key activates card; Space key (onActivateRequested) toggles overviewMode
    verify(/onReturnRequested[\s\S]*root\.activateSelectedCard\(\)/.test(source))
    verify(/onActivateRequested[\s\S]*root\.toggleOverviewMode\(\)/.test(source))
    // Focused mode uses dynamic card dimensions
    verify(/function slotWidth\(/.test(source))
    verify(/function slotHeight\(/.test(source))
    verify(/WindowGeometry\.focusedOverviewGeometry/.test(source))
    // Dismissing resets overviewMode to "normal"
    verify(/root\.overviewMode\s*=\s*"normal"/.test(source))
  }

  function test_focusedOverviewRailScrollingAndWheelIntegration() {
    var source = workspaceOverviewSource()
    var cardSource = workspaceCardSource()

    // Must declare rail scrolling properties
    verify(/property real railScrollY\s*:\s*0/.test(source))
    verify(/readonly property bool railScrollNeeded/.test(source))
    verify(/readonly property real railScrollMax/.test(source))
    verify(/function scrollRail\(/.test(source))
    verify(/function ensureCardVisible\(/.test(source))
    verify(/onSelectedCardIndexChanged\s*:\s*\{[\s\S]*root\.ensureCardVisible/.test(source))

    // Must clip cards inside cardsContainer
    verify(/id\s*:\s*cardsContainer/.test(source))
    verify(/clip\s*:\s*true/.test(source))

    // Must have rail wheel capture that does not steal clicks
    verify(/id\s*:\s*railWheelArea/.test(source))
    verify(/acceptedButtons\s*:\s*Qt\.NoButton/.test(source))
    verify(/root\.scrollRail\(wheel\.angleDelta\.y\)/.test(source))

    // WorkspaceCard forwards mouse wheel to overview without activation
    verify(/cardMouseArea[\s\S]*onWheel\s*:\s*function\(wheel\)/.test(cardSource))
    verify(/root\.overview\.scrollRail\(wheel\.angleDelta\.y\)/.test(cardSource))
  }

  function test_focusedOverviewPromotionAndNoDuplicates() {
    // Test geometry promotion with 5 workspaces
    for (var prim = 0; prim < 5; prim++) {
      var geom = WindowGeometry.focusedOverviewGeometry(5, prim, 1920, 1080, 1.55, 48)
      compare(geom.cards.length, 5)
      compare(geom.primaryIndex, prim)
      verify(geom.cards[prim].isPrimary)

      var primaryCount = 0
      var secondaryCount = 0
      var seenIndices = {}

      for (var i = 0; i < geom.cards.length; i++) {
        var card = geom.cards[i]
        verify(card !== null)
        verify(!seenIndices[card.index], "Duplicate card index detected: " + card.index)
        seenIndices[card.index] = true

        if (card.isPrimary) {
          primaryCount++
          compare(card.index, prim)
        } else {
          secondaryCount++
          verify(card.index !== prim)
          compare(card.x, geom.rail.x)
          compare(card.width, geom.rail.width)
        }
      }

      compare(primaryCount, 1)
      compare(secondaryCount, 4)
    }
  }

  function test_pinchGestureIntegrationAndStateConvergence() {
    var source = workspaceOverviewSource()

    // 1. GestureHelper import
    verify(/import\s+"GestureHelper\.js"\s+as\s+GestureHelper/.test(source),
      "WorkspaceOverview must import GestureHelper.js")

    // 2. Pinch threshold and triggered state properties
    verify(/readonly\s+property\s+real\s+pinchThreshold\s*:\s*GestureHelper\.PINCH_THRESHOLD/.test(source),
      "WorkspaceOverview must declare pinchThreshold referencing GestureHelper.PINCH_THRESHOLD")
    verify(/property\s+bool\s+pinchTriggered\s*:\s*false/.test(source),
      "WorkspaceOverview must declare pinchTriggered boolean property")

    // 3. Mode state machine convergence (setOverviewMode & toggleOverviewMode)
    verify(/function\s+setOverviewMode\(mode\)/.test(source),
      "WorkspaceOverview must define unified setOverviewMode(mode)")
    verify(/function\s+toggleOverviewMode\(\)/.test(source),
      "WorkspaceOverview must define toggleOverviewMode()")
    verify(/root\.setOverviewMode\("normal"\)/.test(source),
      "toggleOverviewMode must delegate to setOverviewMode('normal')")
    verify(/root\.setOverviewMode\("focused"\)/.test(source),
      "toggleOverviewMode must delegate to setOverviewMode('focused')")

    // 4. Pinch event handling functions
    verify(/function\s+handlePinchScale\(scale\)/.test(source),
      "WorkspaceOverview must declare handlePinchScale(scale)")
    verify(/function\s+handlePinchActiveChanged\(active\)/.test(source),
      "WorkspaceOverview must declare handlePinchActiveChanged(active)")

    // 5. One-shot debounce guard in handlePinchScale
    verify(/if\s*\(root\.pinchTriggered\)\s*return/.test(source),
      "handlePinchScale must bail out early if pinchTriggered is already true")
    verify(/GestureHelper\.shouldTriggerTransition/.test(source),
      "handlePinchScale must delegate transition decision to GestureHelper")

    // 6. Reset on active == false
    verify(/if\s*\(!active\)\s*\{\s*root\.pinchTriggered\s*=\s*false\s*\}/.test(source),
      "handlePinchActiveChanged must reset pinchTriggered when fingers are lifted (active == false)")

    // 7. Reset on open(), close(), dismiss()
    var openMatch = source.match(/function\s+open\(payloadJson\)[\s\S]*?\n  \}/)
    verify(openMatch && /root\.pinchTriggered\s*=\s*false/.test(openMatch[0]),
      "open() must reset pinchTriggered to false")
    var closeMatch = source.match(/function\s+close\(\)[\s\S]*?\n  \}/)
    verify(closeMatch && /root\.pinchTriggered\s*=\s*false/.test(closeMatch[0]),
      "close() must reset pinchTriggered to false")
    var dismissMatch = source.match(/function\s+dismiss\(\)[\s\S]*?\n  \}/)
    verify(dismissMatch && /root\.pinchTriggered\s*=\s*false/.test(dismissMatch[0]),
      "dismiss() must reset pinchTriggered to false")

    // 8. PinchHandler declaration inside PanelWindow / keyCatcher
    verify(/PinchHandler\s*\{/.test(source),
      "WorkspaceOverview must declare a native PinchHandler")
    verify(/target\s*:\s*null/.test(source),
      "PinchHandler must set target: null to prevent continuous rescaling blur")
    verify(/grabPermissions\s*:\s*PointerHandler\.CanTakeOverFromAnything/.test(source),
      "PinchHandler must declare grabPermissions")
    verify(/onActiveChanged\s*:\s*\{\s*root\.handlePinchActiveChanged\(active\)\s*\}/.test(source),
      "PinchHandler must wire onActiveChanged to root.handlePinchActiveChanged")
  }

  function test_wheelNavigationArrowKeyDirectMappingAndTouchpadDistinction() {
    var source = workspaceOverviewSource()
    var cardSource = workspaceCardSource()

    // 1. Wheel accumulators and navigation function
    verify(/property\s+real\s+wheelDeltaAccumulatorX\s*:\s*0/.test(source),
      "WorkspaceOverview must declare wheelDeltaAccumulatorX")
    verify(/property\s+real\s+wheelDeltaAccumulatorY\s*:\s*0/.test(source),
      "WorkspaceOverview must declare wheelDeltaAccumulatorY")
    verify(/function\s+handleWheelNavigation\(deltaX,\s*deltaY\)/.test(source),
      "WorkspaceOverview must define handleWheelNavigation(deltaX, deltaY)")

    // 2. Mode-specific wheel navigation branching:
    // Normal mode: endless visual cycle
    // - Wheel down -> Right arrow / l -> moveCardSelection(1, 0)
    // - Wheel up   -> Left arrow / h  -> moveCardSelection(-1, 0)
    // Focused mode: spatial row navigation
    // - Wheel down -> Down arrow / j -> moveCardSelection(0, 1)
    // - Wheel up   -> Up arrow / k   -> moveCardSelection(0, -1)
    verify(/if\s*\(root\.overviewMode\s*===\s*"normal"\)/.test(source),
      "handleWheelNavigation must branch based on overviewMode === 'normal'")
    verify(/root\.moveCardSelection\(1,\s*0\)/.test(source),
      "Normal mode wheel down & horizontal right must call moveCardSelection(1, 0)")
    verify(/root\.moveCardSelection\(-1,\s*0\)/.test(source),
      "Normal mode wheel up & horizontal left must call moveCardSelection(-1, 0)")
    verify(/root\.moveCardSelection\(0,\s*1\)/.test(source),
      "Focused mode wheel down must call moveCardSelection(0, 1)")
    verify(/root\.moveCardSelection\(0,\s*-1\)/.test(source),
      "Focused mode wheel up must call moveCardSelection(0, -1)")

    // 3. One wheel detent threshold (60)
    verify(/var\s+threshold\s*=\s*60/.test(source),
      "handleWheelNavigation must use a 60-unit accumulator threshold for 1-detent mapping")

    // 4. Background MouseArea and keyCatcher WheelHandler wiring
    verify(/MouseArea[\s\S]*onWheel\s*:\s*function\(wheel\)\s*\{\s*root\.handleWheelNavigation\(wheel\.angleDelta\.x,\s*wheel\.angleDelta\.y\)/.test(source),
      "Background MouseArea must forward wheel events to handleWheelNavigation")
    verify(/WheelHandler[\s\S]*id\s*:\s*catcherWheelHandler/.test(source),
      "keyCatcher must include catcherWheelHandler for overview-wide wheel reception")

    // 5. Touchpad scroll distinction in WorkspaceCard.qml
    verify(/isTouchpadScroll\s*=\s*Boolean\(wheel\.pixelDelta/.test(cardSource),
      "WorkspaceCard must inspect wheel.pixelDelta to distinguish touchpad two-finger scroll from mouse wheel")
    verify(/isRailSecondary\s*&&/.test(cardSource),
      "WorkspaceCard must preserve two-finger scrolling in focused secondary rail")
    verify(/root\.overview\.handleCardWheel/.test(cardSource),
      "WorkspaceCard must delegate normal mode and primary card wheel to handleCardWheel")
  }

  function test_adaptiveOverviewNormalModeIntegration() {
    var source = workspaceOverviewSource()

    // 1. Grid geometry without 520px cap
    verify(/overviewGridGeometry\(\s*cardCount,\s*usableWidth,\s*usableGridHeight,\s*cardAspectRatio,\s*gridSpacing\)/.test(source),
      "WorkspaceOverview must invoke overviewGridGeometry without hardcoded 520px cap")

    // 2. normalCardGeom helper defined and used
    verify(/function\s+normalCardGeom\(idx\)/.test(source),
      "WorkspaceOverview must define normalCardGeom helper")

    var slotXMatch = source.match(/function\s+slotX\(idx\)[\s\S]*?\n  \}/)
    verify(slotXMatch && /normalCardGeom/.test(slotXMatch[0]),
      "slotX must query normalCardGeom in normal overview mode")

    var slotYMatch = source.match(/function\s+slotY\(idx\)[\s\S]*?\n  \}/)
    verify(slotYMatch && /normalCardGeom/.test(slotYMatch[0]),
      "slotY must query normalCardGeom in normal overview mode")

    var slotWMatch = source.match(/function\s+slotWidth\(idx\)[\s\S]*?\n  \}/)
    verify(slotWMatch && /normalCardGeom/.test(slotWMatch[0]),
      "slotWidth must query normalCardGeom in normal overview mode")

    var slotHMatch = source.match(/function\s+slotHeight\(idx\)[\s\S]*?\n  \}/)
    verify(slotHMatch && /normalCardGeom/.test(slotHMatch[0]),
      "slotHeight must query normalCardGeom in normal overview mode")

    // 3. Invariant: gridGeometry has NO dependency on selectedCardIndex
    var gridGeomDecl = source.match(/readonly\s+property\s+var\s+gridGeometry\s*:\s*WindowGeometry\.overviewGridGeometry[\s\S]*?\)/)
    verify(gridGeomDecl && !/selectedCardIndex/.test(gridGeomDecl[0]),
      "gridGeometry must never depend on selectedCardIndex (selection must not alter Normal mode geometry)")
  }

  function test_safeAreaAuthoritativeBarIntegration() {
    var source = workspaceOverviewSource()

    // 1. Safe area geometry helper invocation
    verify(/safeArea\s*:\s*WindowGeometry\.safeAreaGeometry\s*\(/.test(source),
      "WorkspaceOverview must compute safeArea via WindowGeometry.safeAreaGeometry")

    // 2. Usable viewport wired strictly to safeArea results
    verify(/readonly\s+property\s+real\s+usableX\s*:\s*safeArea\.usableX/.test(source),
      "usableX must be driven by safeArea.usableX")
    verify(/readonly\s+property\s+real\s+usableY\s*:\s*safeArea\.usableY/.test(source),
      "usableY must be driven by safeArea.usableY")
    verify(/readonly\s+property\s+real\s+usableWidth\s*:\s*safeArea\.usableWidth/.test(source),
      "usableWidth must be driven by safeArea.usableWidth")
    verify(/readonly\s+property\s+real\s+usableHeight\s*:\s*safeArea\.usableHeight/.test(source),
      "usableHeight must be driven by safeArea.usableHeight")

    // 3. Multi-tier authoritative bar detection (shell.bar, shell.barConfig, monitorReserved struts)
    verify(/readonly\s+property\s+var\s+monitorReserved\s*:/.test(source),
      "WorkspaceOverview must expose monitorReserved from Hyprland monitor IPC")
    verify(/lastIpcObject\.reserved/.test(source),
      "WorkspaceOverview must read lastIpcObject.reserved struts")
    verify(/configuredBarPosition/.test(source),
      "WorkspaceOverview must support configuredBarPosition fallback")
    verify(/Math\.max\(\s*shellBarSize,\s*monPixels\s*\)/.test(source),
      "barPixels must resolve to Math.max(shellBarSize, monPixels) for authoritative sizing")

    // 4. Tightened margins and spacing to enlarge previews
    verify(/outerMargin\s*:\s*Math\.max\(16,\s*Style\.space\(16\)\)/.test(source),
      "outerMargin must be streamlined to 16px to minimize wasted edge padding")
    verify(/gridSpacing\s*:\s*Style\.space\(24\)/.test(source),
      "gridSpacing must be optimized to 24px (from 48px)")

    // 5. Cards container positioned and clipped strictly to usable bounds inside safe area
    verify(/id\s*:\s*cardsContainer/.test(source),
      "cardsContainer must host all cards within the safe viewport")
    verify(/cardsContainer[\s\S]*x\s*:\s*root\.usableX/.test(source),
      "cardsContainer must be positioned at root.usableX")
    verify(/cardsContainer[\s\S]*y\s*:\s*root\.usableGridY/.test(source),
      "cardsContainer must be positioned at root.usableGridY")
    verify(/cardsContainer[\s\S]*width\s*:\s*root\.usableWidth/.test(source),
      "cardsContainer must be bounded by root.usableWidth")
    verify(/cardsContainer[\s\S]*height\s*:\s*root\.usableGridHeight/.test(source),
      "cardsContainer must be bounded by root.usableGridHeight")
    verify(/cardsContainer[\s\S]*clip\s*:\s*true/.test(source),
      "cardsContainer must clip content so nothing ever renders outside safe viewport")
  }

  function test_scratchpadIntegrationAndPresence() {
    var source = workspaceOverviewSource()
    var cardSource = workspaceCardSource()

    // 1. WindowModel import in WorkspaceOverview.qml
    verify(/import\s+"WindowModel\.js"\s+as\s+WindowModel/.test(source),
      "WorkspaceOverview must import WindowModel.js")

    // 2. Special workspace discovery and window count functions
    verify(/function\s+isSpecialWorkspace\(ws\)/.test(source),
      "WorkspaceOverview must declare isSpecialWorkspace helper")
    verify(/function\s+specialWorkspaceName\(ws\)/.test(source),
      "WorkspaceOverview must declare specialWorkspaceName helper")
    verify(/function\s+workspaceWindowCount\(ws\)/.test(source),
      "WorkspaceOverview must declare workspaceWindowCount helper")
    verify(/function\s+specialWorkspaces\(\)/.test(source),
      "WorkspaceOverview must declare specialWorkspaces helper")
    verify(/function\s+toggleSpecialWorkspace\(specialName\)/.test(source),
      "WorkspaceOverview must declare toggleSpecialWorkspace helper")

    // 3. Scratchpad disappearance when empty: specialWorkspaces only includes workspaces with window count > 0
    verify(/workspaceWindowCount\(ws\)\s*>\s*0/.test(source),
      "specialWorkspaces must filter only special workspaces holding windows (> 0)")

    // 4. Scratchpad card property and badge label in WorkspaceCard.qml
    verify(/readonly\s+property\s+bool\s+isScratchpad\s*:/.test(cardSource),
      "WorkspaceCard must declare isScratchpad property")
    verify(/WindowModel\.workspaceBadgeText\(root\.workspaceId,\s*root\.isScratchpad\)/.test(cardSource),
      "WorkspaceCard badge must display badge text via WindowModel.workspaceBadgeText")

    // 5. Valid drop target accepts scratchpad
    verify(/\(workspaceId\s*>\s*0\s*\|\|\s*root\.isScratchpad\)/.test(cardSource),
      "WorkspaceCard must allow drop targeting when isScratchpad is true")
  }

  function test_scratchpadBuildOverviewItemsAndInsertionTargets() {
    // 1. Resting state: [1, 2, -98] -> 3 items, numeric first, scratchpad appended with isScratchpad === true
    var resting = buildOverviewItems([1, 2, -98], false)
    compare(resting.length, 3)
    compare(resting[0].workspaceId, 1)
    compare(resting[0].isInsertion, false)
    compare(resting[0].isScratchpad, false)
    compare(resting[1].workspaceId, 2)
    compare(resting[1].isInsertion, false)
    compare(resting[1].isScratchpad, false)
    compare(resting[2].workspaceId, -98)
    compare(resting[2].isInsertion, false)
    compare(resting[2].isScratchpad, true)

    // 2. Drag state: [1, 2, -98] -> insertion targets ONLY for numeric workspaces
    // Numeric: [1, 2] -> [1, 2, 3 (ins)]
    // Scratchpad: [-98] -> appended at end without insertion targets
    var dragging = buildOverviewItems([1, 2, -98], true)
    compare(dragging.length, 4)
    compare(dragging[0].workspaceId, 1)
    compare(dragging[0].isInsertion, false)
    compare(dragging[1].workspaceId, 2)
    compare(dragging[1].isInsertion, false)
    compare(dragging[2].workspaceId, 3)
    compare(dragging[2].isInsertion, true)
    compare(dragging[3].workspaceId, -98)
    compare(dragging[3].isInsertion, false)
    compare(dragging[3].isScratchpad, true)

    // 3. computeInsertionTargets ignores negative special workspace IDs
    var targets = computeInsertionTargets([1, 2, -98])
    compare(targets.length, 1)
    compare(targets[0], 3)

    var targetsWithGap = computeInsertionTargets([1, 4, -98])
    compare(targetsWithGap.length, 2)
    compare(targetsWithGap[0], 2)
    compare(targetsWithGap[1], 5)
  }

  function test_scratchpadActivationAndWindowMovement() {
    var source = workspaceOverviewSource()

    // 1. activateWorkspace toggles special workspace when ID < 0 or isSpecialWorkspace
    var actWsMatch = source.match(/function\s+activateWorkspace\(workspace,\s*workspaceId,\s*occupied\)[\s\S]*?\n  \}/)
    verify(actWsMatch && /toggleSpecialWorkspace/.test(actWsMatch[0]),
      "activateWorkspace must call toggleSpecialWorkspace for scratchpad")
    verify(actWsMatch && /Qt\.callLater\(root\.dismiss\)/.test(actWsMatch[0]),
      "activateWorkspace must dismiss overview when scratchpad is toggled")

    // 2. activateSelectedCard toggles special workspace when selected card is scratchpad
    var actSelMatch = source.match(/function\s+activateSelectedCard\(\)[\s\S]*?\n  \}/)
    verify(actSelMatch && /toggleSpecialWorkspace/.test(actSelMatch[0]),
      "activateSelectedCard must call toggleSpecialWorkspace for scratchpad")

    // 3. moveWindowToWorkspace supports negative target workspace IDs (scratchpad)
    var moveMatch = source.match(/function\s+moveWindowToWorkspace\(toplevel,\s*workspaceId\)[\s\S]*?\n  \}/)
    verify(moveMatch && /isTargetSpecial\s*=\s*workspaceId\s*<\s*0/.test(moveMatch[0]),
      "moveWindowToWorkspace must identify negative IDs as special targets")
    verify(moveMatch && /special:scratchpad/.test(moveMatch[0]),
      "moveWindowToWorkspace must resolve special:scratchpad target name")
    verify(moveMatch && /MOVE\s*→\s*SCRATCHPAD/.test(moveMatch[0]),
      "moveWindowToWorkspace must show SCRATCHPAD demo hint when moving to scratchpad")
  }
}
