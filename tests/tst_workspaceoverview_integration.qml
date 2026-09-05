import QtQuick 2.15
import QtTest 1.3

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
    // Inactive card dimming level should be 0.72 and active level 1.0
    verify(/root\.isCurrent\s*\?\s*1\.0\s*:/.test(source))
    verify(/0\.72/.test(source))
  }
}
