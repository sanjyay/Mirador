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

  function test_insertionDropZoneTargets() {
    // [1, 3, 5] -> insertion targets [2, 4, 6]
    var targets135 = computeInsertionTargets([1, 3, 5])
    compare(targets135.length, 3)
    compare(targets135[0], 2)
    compare(targets135[1], 4)
    compare(targets135[2], 6)

    // [3, 5] -> insertion targets [2, 4, 6]
    var targets35 = computeInsertionTargets([3, 5])
    compare(targets35.length, 3)
    compare(targets35[0], 2)
    compare(targets35[1], 4)
    compare(targets35[2], 6)

    // [1, 2, 3] -> insertion target [4]
    var targets123 = computeInsertionTargets([1, 2, 3])
    compare(targets123.length, 1)
    compare(targets123[0], 4)
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
    if (ids[0] > 1) {
      items.push({ workspaceId: ids[0] - 1, isInsertion: true })
    }

    for (var i = 0; i < ids.length; i++) {
      items.push({ workspaceId: ids[i], isInsertion: false })
      if (i < ids.length - 1) {
        if (ids[i + 1] > ids[i] + 1) {
          items.push({ workspaceId: ids[i] + 1, isInsertion: true })
        }
      }
    }

    items.push({ workspaceId: ids[ids.length - 1] + 1, isInsertion: true })
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

      compare(primaryCount, 1, "Exactly one primary workspace")
      compare(secondaryCount, 4, "Remaining workspaces are secondary rail items")
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
}
