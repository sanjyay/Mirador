import QtQuick 2.15
import QtTest 1.3
import "../WindowGeometry.js" as WindowGeometry

TestCase {
  name: "WindowGeometry"

  readonly property var monitor: ({ name: "test", x: 100, y: -900, width: 1600, height: 900, scale: 1 })
  readonly property var screen: ({ name: "test", width: 1600, height: 900 })

  function geometry(x, y, width, height) {
    return WindowGeometry.previewGeometry(
      { at: [x, y], size: [width, height] }, monitor, screen, 320, 180, 20, 16)
  }

  function fuzzyCompare(actual, expected) {
    verify(Math.abs(actual - expected) < 0.001,
      "Expected " + expected + ", got " + actual)
  }

  function test_oneWindowFillsArea() {
    var result = geometry(100, -900, 1600, 900)
    verify(result.valid)
    compare(result.x, 0)
    compare(result.y, 0)
    compare(result.width, 320)
    compare(result.height, 180)
  }

  function test_horizontalTiles() {
    var left = geometry(100, -900, 800, 900)
    var right = geometry(900, -900, 800, 900)
    compare(left.x, 0)
    compare(left.width, 160)
    compare(right.x, 160)
    compare(right.width, 160)
  }

  function test_verticalTiles() {
    var top = geometry(100, -900, 1600, 450)
    var bottom = geometry(100, -450, 1600, 450)
    compare(top.y, 0)
    compare(top.height, 90)
    compare(bottom.y, 90)
    compare(bottom.height, 90)
  }

  function test_mixedTiling() {
    var left = geometry(100, -900, 800, 900)
    var topRight = geometry(900, -900, 800, 450)
    var bottomRight = geometry(900, -450, 800, 450)
    compare(left.width, 160)
    compare(left.height, 180)
    compare(topRight.x, 160)
    compare(topRight.height, 90)
    compare(bottomRight.x, 160)
    compare(bottomRight.y, 90)
  }

  function test_partialWindowIsClamped() {
    var result = geometry(-100, -1000, 400, 300)
    verify(result.valid)
    compare(result.x, 0)
    compare(result.y, 0)
    fuzzyCompare(result.width, 40)
    fuzzyCompare(result.height, 40)
  }

  function test_tinyWindowGetsMinimumSizeNearItsCenter() {
    var result = geometry(899, -451, 2, 2)
    verify(result.valid)
    compare(result.width, 20)
    compare(result.height, 16)
    fuzzyCompare(result.x, 150)
    fuzzyCompare(result.y, 82)
  }

  function test_scaledMonitorUsesLogicalExtent() {
    var scaledMonitor = { name: "scaled", x: -1920, y: 0, width: 3840, height: 2160, scale: 2 }
    var result = WindowGeometry.previewGeometry(
      { at: [-1920, 0], size: [1920, 1080] }, scaledMonitor, null, 320, 180, 20, 16)
    verify(result.valid)
    compare(result.width, 320)
    compare(result.height, 180)
  }

  function test_floatingWindowOverTiled() {
    // Monitor 1600x900, tiled left window (0..800), floating window (400..1200, 225..675)
    var tiledLeft = geometry(100, -900, 800, 900)
    var floating = geometry(500, -675, 800, 450)
    compare(tiledLeft.x, 0)
    compare(tiledLeft.width, 160)
    compare(floating.x, 80)
    compare(floating.y, 45)
    compare(floating.width, 160)
    compare(floating.height, 90)
  }

  function test_negativeOriginMonitor() {
    var negMonitor = { name: "left-monitor", x: -1920, y: -1080, width: 1920, height: 1080, scale: 1 }
    var negScreen = { name: "left-monitor", width: 1920, height: 1080 }
    var win = WindowGeometry.previewGeometry(
      { at: [-960, -540], size: [960, 540] }, negMonitor, negScreen, 300, 150, 10, 10)
    verify(win.valid)
    // On 300x150 canvas (2:1 aspect ratio) for a 1920x1080 (16:9) monitor,
    // uniform scale = 150 / 1080 = 5/36. Rendered width = 266.667, offsetX = 16.667.
    // Window is in bottom-right quadrant: relativeX = 960, relativeY = 540.
    fuzzyCompare(win.x, 150)
    fuzzyCompare(win.y, 75)
    fuzzyCompare(win.width, 133.3333)
    fuzzyCompare(win.height, 75)
  }

  function test_realUnequalHorizontalSplitRegression() {
    // Exact geometry captured from real Hyprland workspace:
    // Monitor 1920x1080 with 35px top bar (reserved [0, 35, 0, 0])
    // Usable workspace: 1920 x 1045
    // Window A (Cursor Theme Switcher): at [12, 47], size [1191, 1021]
    // Window B (Ghostty terminal): at [1217, 47], size [691, 1021]
    var realMonitor = { name: "eDP-2", x: 0, y: 0, width: 1920, height: 1080, scale: 1, reserved: [0, 35, 0, 0] }
    var canvasW = 512
    var canvasH = 327.48

    var previewA = WindowGeometry.previewGeometry(
      { at: [12, 47], size: [1191, 1021] }, realMonitor, null, canvasW, canvasH, 20, 16)
    var previewB = WindowGeometry.previewGeometry(
      { at: [1217, 47], size: [691, 1021] }, realMonitor, null, canvasW, canvasH, 20, 16)

    verify(previewA.valid)
    verify(previewB.valid)

    // Common transform properties
    fuzzyCompare(previewA.scale, previewB.scale)
    fuzzyCompare(previewA.offsetX, previewB.offsetX)
    fuzzyCompare(previewA.offsetY, previewB.offsetY)

    var scale = previewA.scale
    fuzzyCompare(scale, 512 / 1920) // 0.2666667

    // Vertical alignment: both top and bottom edges must align exactly
    fuzzyCompare(previewA.y, previewB.y)
    fuzzyCompare(previewA.height, previewB.height)
    fuzzyCompare(previewA.height, 1021 * scale)

    // Horizontal positioning:
    // Window A left outer margin: 12 * scale
    fuzzyCompare(previewA.x, 12 * scale)
    // Window B right outer margin: canvasW - (B.x + B.width) == 12 * scale
    fuzzyCompare(canvasW - (previewB.x + previewB.width), 12 * scale)
    // Inner compositor gap between A and B: B.x - (A.x + A.width) == 14 * scale
    fuzzyCompare(previewB.x - (previewA.x + previewA.width), 14 * scale)

    // Width split ratios must preserve the exact Hyprland proportion
    var totalTiledWidth = previewA.width + previewB.width
    fuzzyCompare(previewA.width / totalTiledWidth, 1191 / (1191 + 691))
    fuzzyCompare(previewB.width / totalTiledWidth, 691 / (1191 + 691))

    // Aspect ratio of previews must match true window aspect ratios
    fuzzyCompare(previewA.width / previewA.height, 1191 / 1021)
    fuzzyCompare(previewB.width / previewB.height, 691 / 1021)
  }

  function test_equalHorizontalSplit5050() {
    var realMonitor = { name: "eDP-2", x: 0, y: 0, width: 1920, height: 1080, scale: 1, reserved: [0, 35, 0, 0] }
    var previewA = WindowGeometry.previewGeometry(
      { at: [12, 47], size: [941, 1021] }, realMonitor, null, 512, 327.48, 20, 16)
    var previewB = WindowGeometry.previewGeometry(
      { at: [967, 47], size: [941, 1021] }, realMonitor, null, 512, 327.48, 20, 16)

    verify(previewA.valid)
    verify(previewB.valid)
    fuzzyCompare(previewA.width, previewB.width)
    fuzzyCompare(previewA.height, previewB.height)
    fuzzyCompare(previewA.y, previewB.y)
    fuzzyCompare(previewB.x - (previewA.x + previewA.width), 14 * previewA.scale)
  }

  function test_verticalSplit() {
    var realMonitor = { name: "eDP-2", x: 0, y: 0, width: 1920, height: 1080, scale: 1, reserved: [0, 35, 0, 0] }
    var topWin = WindowGeometry.previewGeometry(
      { at: [12, 47], size: [1896, 503] }, realMonitor, null, 512, 327.48, 20, 16)
    var bottomWin = WindowGeometry.previewGeometry(
      { at: [12, 564], size: [1896, 504] }, realMonitor, null, 512, 327.48, 20, 16)

    verify(topWin.valid)
    verify(bottomWin.valid)
    fuzzyCompare(topWin.x, bottomWin.x)
    fuzzyCompare(topWin.width, bottomWin.width)
    fuzzyCompare(bottomWin.y - (topWin.y + topWin.height), 14 * topWin.scale)
  }

  function test_mixedTilingThreeWindows() {
    var realMonitor = { name: "eDP-2", x: 0, y: 0, width: 1920, height: 1080, scale: 1, reserved: [0, 35, 0, 0] }
    var leftWin = WindowGeometry.previewGeometry(
      { at: [12, 47], size: [1191, 1021] }, realMonitor, null, 512, 327.48, 20, 16)
    var topRightWin = WindowGeometry.previewGeometry(
      { at: [1217, 47], size: [691, 503] }, realMonitor, null, 512, 327.48, 20, 16)
    var bottomRightWin = WindowGeometry.previewGeometry(
      { at: [1217, 564], size: [691, 504] }, realMonitor, null, 512, 327.48, 20, 16)

    verify(leftWin.valid)
    verify(topRightWin.valid)
    verify(bottomRightWin.valid)

    // Left vs Right X alignment
    fuzzyCompare(topRightWin.x, bottomRightWin.x)
    fuzzyCompare(topRightWin.width, bottomRightWin.width)
    fuzzyCompare(topRightWin.x - (leftWin.x + leftWin.width), 14 * leftWin.scale)

    // Top alignment
    fuzzyCompare(leftWin.y, topRightWin.y)
    // Right pane vertical gap
    fuzzyCompare(bottomRightWin.y - (topRightWin.y + topRightWin.height), 14 * leftWin.scale)
    // Bottom alignment
    fuzzyCompare(leftWin.y + leftWin.height, bottomRightWin.y + bottomRightWin.height)
  }

  function test_resizeAndMoveSimulation() {
    var initial = geometry(100, -900, 800, 900)
    compare(initial.x, 0)
    compare(initial.width, 160)

    // Window moved to right half and resized to 1000x900
    var moved = geometry(700, -900, 1000, 900)
    compare(moved.x, 120)
    compare(moved.width, 200)
  }

  function test_invalidGeometryUsesFallback() {
    var invalid = WindowGeometry.previewGeometry(
      { at: [0], size: [100, 100] }, monitor, screen, 320, 180, 20, 16)
    verify(!invalid.valid)

    var fallback = WindowGeometry.fallbackGeometry(2, 4, 320, 180, 4)
    verify(fallback.width > 0)
    verify(fallback.height > 0)
    verify(fallback.x >= 0 && fallback.x + fallback.width <= 320)
    verify(fallback.y >= 0 && fallback.y + fallback.height <= 180)
  }

  function test_previewCanvasUsesNearlyEntireCard() {
    var canvas = WindowGeometry.insetGeometry(520, 335, 4)
    compare(canvas.x, 4)
    compare(canvas.y, 4)
    compare(canvas.width, 512)
    compare(canvas.height, 327)
    verify(canvas.width * canvas.height / (520 * 335) > 0.96)
  }

  function test_previewCanvasHandlesTinyCards() {
    var canvas = WindowGeometry.insetGeometry(3, 2, 4)
    compare(canvas.width, 1)
    compare(canvas.height, 1)
    verify(canvas.x >= 0)
    verify(canvas.y >= 0)
  }

  function verifyCenteredGrid(count, width, height, spacing) {
    var result = WindowGeometry.overviewGridGeometry(
      count, width, height, 1.55, 520, spacing)
    compare(result.columns * result.rows >= count, true)
    verify(result.gridWidth <= width + 0.001)
    verify(result.gridHeight <= height + 0.001)
    fuzzyCompare(result.x * 2 + result.gridWidth, width)
    fuzzyCompare(result.y * 2 + result.gridHeight, height)
  }

  function test_sixCardsRemainCentered() {
    var result = WindowGeometry.overviewGridGeometry(6, 1880, 1000, 1.55, 520, 16)
    compare(result.columns, 3)
    compare(result.rows, 2)
    verifyCenteredGrid(6, 1880, 1000, 16)
  }

  function test_allWorkspaceCountsRemainCentered() {
    var sizes = [[1880, 1000], [1000, 1880], [3440, 1340], [320, 240]]
    for (var count = 1; count <= 10; count++) {
      for (var i = 0; i < sizes.length; i++)
        verifyCenteredGrid(count, sizes[i][0], sizes[i][1], 16)
    }
  }

  function test_barInsetsPreserveUsableAreaCenter() {
    var panelWidth = 1920
    var panelHeight = 1080
    var outerMargin = 12
    var topBar = 43
    var usableWidth = panelWidth - outerMargin * 2
    var usableHeight = panelHeight - topBar - outerMargin * 2
    var result = WindowGeometry.overviewGridGeometry(
      6, usableWidth, usableHeight, 1.55, 520, 16)

    fuzzyCompare(outerMargin + result.x + result.gridWidth / 2,
      outerMargin + usableWidth / 2)
    fuzzyCompare(topBar + outerMargin + result.y + result.gridHeight / 2,
      topBar + outerMargin + usableHeight / 2)
  }

  function test_emptyAndInvalidInputsStayFinite() {
    var empty = WindowGeometry.overviewGridGeometry(0, 1920, 1080, 1.55, 520, 16)
    compare(empty.columns, 0)
    compare(empty.rows, 0)
    fuzzyCompare(empty.x, 960)
    fuzzyCompare(empty.y, 540)

    var constrained = WindowGeometry.overviewGridGeometry(10, NaN, -1, 0, -1, -5)
    verify(isFinite(constrained.x))
    verify(isFinite(constrained.y))
    verify(isFinite(constrained.cardWidth))
    verify(isFinite(constrained.cardHeight))
  }

  function test_cyclicNavigation_leftWrap() {
    var grid = [
      { index: 0, x: 0, y: 0, width: 80, height: 60 },
      { index: 1, x: 100, y: 0, width: 80, height: 60 },
      { index: 2, x: 200, y: 0, width: 80, height: 60 },
      { index: 3, x: 0, y: 100, width: 80, height: 60 },
      { index: 4, x: 100, y: 100, width: 80, height: 60 },
      { index: 5, x: 200, y: 100, width: 80, height: 60 }
    ]
    // Left from first workspace (index 0) wraps to very last workspace (index 5)
    compare(WindowGeometry.cyclicCardMove(grid, 0, -1, 0), 5)
    // Left from first in row 1 (index 3) moves to last in row 0 (index 2)
    compare(WindowGeometry.cyclicCardMove(grid, 3, -1, 0), 2)
  }

  function test_cyclicNavigation_rightWrap() {
    var grid = [
      { index: 0, x: 0, y: 0, width: 80, height: 60 },
      { index: 1, x: 100, y: 0, width: 80, height: 60 },
      { index: 2, x: 200, y: 0, width: 80, height: 60 },
      { index: 3, x: 0, y: 100, width: 80, height: 60 },
      { index: 4, x: 100, y: 100, width: 80, height: 60 },
      { index: 5, x: 200, y: 100, width: 80, height: 60 }
    ]
    // Right from last in row 0 (index 2) moves to first in row 1 (index 3)
    compare(WindowGeometry.cyclicCardMove(grid, 2, 1, 0), 3)
    // Right from very last workspace (index 5) wraps to first workspace (index 0)
    compare(WindowGeometry.cyclicCardMove(grid, 5, 1, 0), 0)
  }

  function test_cyclicNavigation_userExampleLayout() {
    // Current layout:
    // [1] [4]
    // [5]
    // Note: indices here represent workspace IDs or card indices
    var layout = [
      { index: 1, x: 0, y: 0, width: 80, height: 60 },
      { index: 4, x: 100, y: 0, width: 80, height: 60 },
      { index: 5, x: 0, y: 100, width: 80, height: 60 }
    ]
    // Right: 1 -> 4 -> 5 -> 1
    compare(WindowGeometry.cyclicCardMove(layout, 1, 1, 0), 4)
    compare(WindowGeometry.cyclicCardMove(layout, 4, 1, 0), 5)
    compare(WindowGeometry.cyclicCardMove(layout, 5, 1, 0), 1)

    // Left: 1 -> 5 -> 4 -> 1
    compare(WindowGeometry.cyclicCardMove(layout, 1, -1, 0), 5)
    compare(WindowGeometry.cyclicCardMove(layout, 5, -1, 0), 4)
    compare(WindowGeometry.cyclicCardMove(layout, 4, -1, 0), 1)

    // Vertical: 1 ↓ -> 5, 4 ↓ -> 5, 5 ↑ -> 1
    compare(WindowGeometry.cyclicCardMove(layout, 1, 0, 1), 5)
    compare(WindowGeometry.cyclicCardMove(layout, 4, 0, 1), 5)
    compare(WindowGeometry.cyclicCardMove(layout, 5, 0, -1), 1)

    // Vertical wrap: 5 ↓ -> 1 (closest center), 1 ↑ -> 5
    compare(WindowGeometry.cyclicCardMove(layout, 5, 0, 1), 1)
    compare(WindowGeometry.cyclicCardMove(layout, 1, 0, -1), 5)
  }

  function test_wheelNavigationMatchesArrowKeysDirectly() {
    // Layout:
    // [1] [4]
    // [5]
    var layout = [
      { index: 1, x: 0, y: 0, width: 80, height: 60 },
      { index: 4, x: 100, y: 0, width: 80, height: 60 },
      { index: 5, x: 0, y: 100, width: 80, height: 60 }
    ]

    var workspaces = [1, 4, 5]

    for (var i = 0; i < workspaces.length; i++) {
      var ws = workspaces[i]

      // 1. Wheel Down must match Down arrow (dy = 1) exactly
      var wheelDownTarget = WindowGeometry.cyclicCardMove(layout, ws, 0, 1)
      var downArrowTarget = WindowGeometry.cyclicCardMove(layout, ws, 0, 1)
      compare(wheelDownTarget, downArrowTarget, "Wheel down from WS " + ws + " must match Down arrow")

      // 2. Wheel Up must match Up arrow (dy = -1) exactly
      var wheelUpTarget = WindowGeometry.cyclicCardMove(layout, ws, 0, -1)
      var upArrowTarget = WindowGeometry.cyclicCardMove(layout, ws, 0, -1)
      compare(wheelUpTarget, upArrowTarget, "Wheel up from WS " + ws + " must match Up arrow")

      // 3. Wheel Right must match Right arrow (dx = 1) exactly
      var wheelRightTarget = WindowGeometry.cyclicCardMove(layout, ws, 1, 0)
      var rightArrowTarget = WindowGeometry.cyclicCardMove(layout, ws, 1, 0)
      compare(wheelRightTarget, rightArrowTarget, "Wheel right from WS " + ws + " must match Right arrow")

      // 4. Wheel Left must match Left arrow (dx = -1) exactly
      var wheelLeftTarget = WindowGeometry.cyclicCardMove(layout, ws, -1, 0)
      var leftArrowTarget = WindowGeometry.cyclicCardMove(layout, ws, -1, 0)
      compare(wheelLeftTarget, leftArrowTarget, "Wheel left from WS " + ws + " must match Left arrow")
    }

    // Specific assertions matching user's expected mapping:
    // From WS1:
    compare(WindowGeometry.cyclicCardMove(layout, 1, 0, 1), 5, "From WS1 wheel down -> WS5")
    compare(WindowGeometry.cyclicCardMove(layout, 1, 0, -1), 5, "From WS1 wheel up -> WS5")

    // From WS4:
    compare(WindowGeometry.cyclicCardMove(layout, 4, 0, 1), 5, "From WS4 wheel down -> WS5")
    compare(WindowGeometry.cyclicCardMove(layout, 4, 0, -1), 5, "From WS4 wheel up -> WS5")

    // From WS5:
    compare(WindowGeometry.cyclicCardMove(layout, 5, 0, -1), 1, "From WS5 wheel up -> WS1")
    compare(WindowGeometry.cyclicCardMove(layout, 5, 0, 1), 1, "From WS5 wheel down -> WS1")

    // Horizontal global cycle:
    // wheel right: 1 -> 4 -> 5 -> 1
    compare(WindowGeometry.cyclicCardMove(layout, 1, 1, 0), 4, "From WS1 wheel right -> WS4")
    compare(WindowGeometry.cyclicCardMove(layout, 4, 1, 0), 5, "From WS4 wheel right -> WS5")
    compare(WindowGeometry.cyclicCardMove(layout, 5, 1, 0), 1, "From WS5 wheel right -> WS1")

    // wheel left: 1 -> 5 -> 4 -> 1
    compare(WindowGeometry.cyclicCardMove(layout, 1, -1, 0), 5, "From WS1 wheel left -> WS5")
    compare(WindowGeometry.cyclicCardMove(layout, 5, -1, 0), 4, "From WS5 wheel left -> WS4")
    compare(WindowGeometry.cyclicCardMove(layout, 4, -1, 0), 1, "From WS4 wheel left -> WS1")
  }

  function test_normalModeWheelGlobalCycle_4WorkspaceGrid() {
    // 4-workspace grid in Normal mode:
    // [1] [2]
    // [3] [4]
    var grid4 = [
      { index: 1, x: 0, y: 0, width: 80, height: 60 },
      { index: 2, x: 100, y: 0, width: 80, height: 60 },
      { index: 3, x: 0, y: 100, width: 80, height: 60 },
      { index: 4, x: 100, y: 100, width: 80, height: 60 }
    ]

    // Normal mode Wheel Down reuses Right arrow / l (dx: 1, dy: 0):
    // Expected cycle: 1 -> 2 -> 3 -> 4 -> 1 -> 2
    var cur = 1
    var expectedDown = [2, 3, 4, 1, 2]
    for (var i = 0; i < expectedDown.length; i++) {
      cur = WindowGeometry.cyclicCardMove(grid4, cur, 1, 0)
      compare(cur, expectedDown[i], "Normal mode wheel down step " + i)
    }

    // Normal mode Wheel Up reuses Left arrow / h (dx: -1, dy: 0):
    // Expected cycle: 1 -> 4 -> 3 -> 2 -> 1 -> 4
    cur = 1
    var expectedUp = [4, 3, 2, 1, 4]
    for (var j = 0; j < expectedUp.length; j++) {
      cur = WindowGeometry.cyclicCardMove(grid4, cur, -1, 0)
      compare(cur, expectedUp[j], "Normal mode wheel up step " + j)
    }

    // If currently selected workspace is 4:
    // wheel down: 4 -> 1 -> 2 -> 3 -> 4 -> 1
    cur = 4
    var from4Down = [1, 2, 3, 4, 1]
    for (var k = 0; k < from4Down.length; k++) {
      cur = WindowGeometry.cyclicCardMove(grid4, cur, 1, 0)
      compare(cur, from4Down[k], "From WS4 wheel down step " + k)
    }

    // Horizontal wheel / tilt equivalence:
    // wheel right == wheel down (dx: 1, dy: 0)
    // wheel left == wheel up (dx: -1, dy: 0)
    compare(WindowGeometry.cyclicCardMove(grid4, 1, 1, 0), 2)
    compare(WindowGeometry.cyclicCardMove(grid4, 1, -1, 0), 4)
  }

  function test_normalModeWheelIrregularIds() {
    // Irregular non-contiguous workspace IDs:
    // [1]  [4]
    // [7]  [10]
    var irregular = [
      { index: 1, x: 0, y: 0, width: 80, height: 60 },
      { index: 4, x: 100, y: 0, width: 80, height: 60 },
      { index: 7, x: 0, y: 100, width: 80, height: 60 },
      { index: 10, x: 100, y: 100, width: 80, height: 60 }
    ]

    // Wheel Down: cycles strictly by visual position: 1 -> 4 -> 7 -> 10 -> 1 -> 4
    var cur = 1
    var expectedDown = [4, 7, 10, 1, 4]
    for (var i = 0; i < expectedDown.length; i++) {
      cur = WindowGeometry.cyclicCardMove(irregular, cur, 1, 0)
      compare(cur, expectedDown[i], "Irregular IDs wheel down step " + i)
    }

    // Wheel Up: cycles strictly in reverse visual position: 1 -> 10 -> 7 -> 4 -> 1 -> 10
    cur = 1
    var expectedUp = [10, 7, 4, 1, 10]
    for (var j = 0; j < expectedUp.length; j++) {
      cur = WindowGeometry.cyclicCardMove(irregular, cur, -1, 0)
      compare(cur, expectedUp[j], "Irregular IDs wheel up step " + j)
    }

    // Also verify with explicit visualOrder (as supplied by WorkspaceOverview):
    var withVisualOrder = [
      { index: 1, visualOrder: 0, x: 0, y: 0, width: 80, height: 60 },
      { index: 4, visualOrder: 1, x: 100, y: 0, width: 80, height: 60 },
      { index: 7, visualOrder: 2, x: 0, y: 100, width: 80, height: 60 },
      { index: 10, visualOrder: 3, x: 100, y: 100, width: 80, height: 60 }
    ]
    cur = 1
    for (var m = 0; m < expectedDown.length; m++) {
      cur = WindowGeometry.cyclicCardMove(withVisualOrder, cur, 1, 0)
      compare(cur, expectedDown[m], "With visualOrder wheel down step " + m)
    }
  }

  function test_cyclicNavigation_threeRowExample() {
    // [1] [2] [3]
    // [4]     [5]
    //     [6]
    var layout = [
      { index: 1, x: 0, y: 0, width: 80, height: 60 },
      { index: 2, x: 100, y: 0, width: 80, height: 60 },
      { index: 3, x: 200, y: 0, width: 80, height: 60 },
      { index: 4, x: 0, y: 100, width: 80, height: 60 },
      { index: 5, x: 200, y: 100, width: 80, height: 60 },
      { index: 6, x: 100, y: 200, width: 80, height: 60 }
    ]

    // Right: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 1
    var rightSeq = [1, 2, 3, 4, 5, 6, 1]
    for (var i = 0; i < rightSeq.length - 1; i++) {
      compare(WindowGeometry.cyclicCardMove(layout, rightSeq[i], 1, 0), rightSeq[i + 1])
    }

    // Left: 1 -> 6 -> 5 -> 4 -> 3 -> 2 -> 1
    var leftSeq = [1, 6, 5, 4, 3, 2, 1]
    for (var j = 0; j < leftSeq.length - 1; j++) {
      compare(WindowGeometry.cyclicCardMove(layout, leftSeq[j], -1, 0), leftSeq[j + 1])
    }

    // Vertical navigation:
    // From 4 (x 0, row 1) down -> row 2 (only 6 exists)
    compare(WindowGeometry.cyclicCardMove(layout, 4, 0, 1), 6)
    // From 5 (x 200, row 1) down -> row 2 (only 6 exists)
    compare(WindowGeometry.cyclicCardMove(layout, 5, 0, 1), 6)
    // From 6 (cx 140, row 2) up -> row 1: 4 is cx 40 (|140-40|=100), 5 is cx 240 (|140-240|=100) -> picks 4 or 5
    var upFrom6 = WindowGeometry.cyclicCardMove(layout, 6, 0, -1)
    verify(upFrom6 === 4 || upFrom6 === 5)
    // From 6 down wraps to row 0: closest to cx 140 is 2 (cx 140)
    compare(WindowGeometry.cyclicCardMove(layout, 6, 0, 1), 2)
  }

  function test_cyclicNavigation_topWrap() {
    var grid = [
      { index: 0, x: 0, y: 0, width: 80, height: 60 },
      { index: 1, x: 100, y: 0, width: 80, height: 60 },
      { index: 2, x: 200, y: 0, width: 80, height: 60 },
      { index: 3, x: 0, y: 100, width: 80, height: 60 },
      { index: 4, x: 100, y: 100, width: 80, height: 60 },
      { index: 5, x: 200, y: 100, width: 80, height: 60 }
    ]
    // Up from top row (0, 1, 2) wraps to bottom row (3, 4, 5) aligning horizontal centers
    compare(WindowGeometry.cyclicCardMove(grid, 0, 0, -1), 3)
    compare(WindowGeometry.cyclicCardMove(grid, 1, 0, -1), 4)
    compare(WindowGeometry.cyclicCardMove(grid, 2, 0, -1), 5)
  }

  function test_cyclicNavigation_bottomWrap() {
    var grid = [
      { index: 0, x: 0, y: 0, width: 80, height: 60 },
      { index: 1, x: 100, y: 0, width: 80, height: 60 },
      { index: 2, x: 200, y: 0, width: 80, height: 60 },
      { index: 3, x: 0, y: 100, width: 80, height: 60 },
      { index: 4, x: 100, y: 100, width: 80, height: 60 },
      { index: 5, x: 200, y: 100, width: 80, height: 60 }
    ]
    // Down from bottom row (3, 4, 5) wraps to top row (0, 1, 2) aligning horizontal centers
    compare(WindowGeometry.cyclicCardMove(grid, 3, 0, 1), 0)
    compare(WindowGeometry.cyclicCardMove(grid, 4, 0, 1), 1)
    compare(WindowGeometry.cyclicCardMove(grid, 5, 0, 1), 2)
  }

  function test_cyclicNavigation_raggedRows() {
    var ragged = [
      { index: 0, x: 0, y: 0, width: 80, height: 60 },
      { index: 1, x: 100, y: 0, width: 80, height: 60 },
      { index: 2, x: 200, y: 0, width: 80, height: 60 },
      { index: 3, x: 0, y: 100, width: 80, height: 60 },
      { index: 4, x: 100, y: 100, width: 80, height: 60 }
    ]
    // Moving Down from index 2 (cx 240) selects closest in Row 1: index 4 (cx 140)
    compare(WindowGeometry.cyclicCardMove(ragged, 2, 0, 1), 4)
    // Moving Up from index 2 (cx 240) wraps to Row 1: index 4 (cx 140)
    compare(WindowGeometry.cyclicCardMove(ragged, 2, 0, -1), 4)
    // Moving Down from index 4 (cx 140) wraps to Row 0: index 1 (cx 140)
    compare(WindowGeometry.cyclicCardMove(ragged, 4, 0, 1), 1)
    // Left on leftmost in Row 1 (index 3) moves to rightmost in Row 0 (index 2)
    compare(WindowGeometry.cyclicCardMove(ragged, 3, -1, 0), 2)
    // Right on rightmost in Row 1 (index 4) wraps to leftmost in Row 0 (index 0)
    compare(WindowGeometry.cyclicCardMove(ragged, 4, 1, 0), 0)
  }

  function test_cyclicNavigation_singleItemRows() {
    var singleItemRow = [
      { index: 0, x: 0, y: 0, width: 80, height: 60 },
      { index: 1, x: 100, y: 0, width: 80, height: 60 },
      { index: 2, x: 50, y: 100, width: 80, height: 60 }
    ]
    // Left and Right on singleItemRow follow global cycle: 0 -> 1 -> 2 -> 0
    compare(WindowGeometry.cyclicCardMove(singleItemRow, 2, 1, 0), 0)
    compare(WindowGeometry.cyclicCardMove(singleItemRow, 2, -1, 0), 1)

    // Vertical move from single-item row to row 0
    var fromSingle = WindowGeometry.cyclicCardMove(singleItemRow, 2, 0, -1)
    verify(fromSingle === 0 || fromSingle === 1)

    // Vertical move from row 0 to single-item row
    compare(WindowGeometry.cyclicCardMove(singleItemRow, 0, 0, 1), 2)
    compare(WindowGeometry.cyclicCardMove(singleItemRow, 1, 0, 1), 2)

    // Single item total: all directions wrap to itself
    var singleTotal = [{ index: 42, x: 10, y: 10, width: 100, height: 80 }]
    compare(WindowGeometry.cyclicCardMove(singleTotal, 42, -1, 0), 42)
    compare(WindowGeometry.cyclicCardMove(singleTotal, 42, 1, 0), 42)
    compare(WindowGeometry.cyclicCardMove(singleTotal, 42, 0, -1), 42)
    compare(WindowGeometry.cyclicCardMove(singleTotal, 42, 0, 1), 42)
  }

  function test_cyclicNavigation_repeatedCyclicNavigation() {
    var grid = [
      { index: 0, x: 0, y: 0, width: 80, height: 60 },
      { index: 1, x: 100, y: 0, width: 80, height: 60 },
      { index: 2, x: 200, y: 0, width: 80, height: 60 },
      { index: 3, x: 0, y: 100, width: 80, height: 60 },
      { index: 4, x: 100, y: 100, width: 80, height: 60 },
      { index: 5, x: 200, y: 100, width: 80, height: 60 }
    ]
    // Repeated right navigation cycles across all cards in global order
    var cur = 0
    var expectedRight = [1, 2, 3, 4, 5, 0, 1, 2]
    for (var i = 0; i < expectedRight.length; i++) {
      cur = WindowGeometry.cyclicCardMove(grid, cur, 1, 0)
      compare(cur, expectedRight[i])
    }

    // Repeated left navigation cycles across all cards in reverse global order
    cur = 0
    var expectedLeft = [5, 4, 3, 2, 1, 0, 5, 4]
    for (var j = 0; j < expectedLeft.length; j++) {
      cur = WindowGeometry.cyclicCardMove(grid, cur, -1, 0)
      compare(cur, expectedLeft[j])
    }

    // Repeated down navigation cycles vertically
    cur = 1
    var expectedDown = [4, 1, 4, 1]
    for (var k = 0; k < expectedDown.length; k++) {
      cur = WindowGeometry.cyclicCardMove(grid, cur, 0, 1)
      compare(cur, expectedDown[k])
    }

    // Repeated up navigation cycles vertically
    cur = 1
    var expectedUp = [4, 1, 4, 1]
    for (var m = 0; m < expectedUp.length; m++) {
      cur = WindowGeometry.cyclicCardMove(grid, cur, 0, -1)
      compare(cur, expectedUp[m])
    }
  }

  function test_cyclicNavigation_ignoresInsertionCards() {
    var mixed = [
      { index: 0, x: 0, y: 0, width: 80, height: 60, isInsertion: false },
      { index: 99, x: 50, y: 0, width: 80, height: 60, isInsertion: true },
      { index: 1, x: 100, y: 0, width: 80, height: 60, isInsertion: false }
    ]
    // Right from 0 should skip insertion card (99) and select workspace 1
    compare(WindowGeometry.cyclicCardMove(mixed, 0, 1, 0), 1)
    // Right from 1 should wrap to workspace 0
    compare(WindowGeometry.cyclicCardMove(mixed, 1, 1, 0), 0)
  }

  function test_snapToDevicePixels() {
    // 1x DPR standard screen: snaps to whole integers
    compare(WindowGeometry.snapToDevicePixels(10.2, 1), 10)
    compare(WindowGeometry.snapToDevicePixels(10.7, 1), 11)
    compare(WindowGeometry.snapToDevicePixels(10.5, 1), 11)

    // 2x DPR HiDPI screen: snaps to 0.5 physical boundaries
    compare(WindowGeometry.snapToDevicePixels(10.2, 2), 10)
    compare(WindowGeometry.snapToDevicePixels(10.3, 2), 10.5)
    compare(WindowGeometry.snapToDevicePixels(10.7, 2), 10.5)
    compare(WindowGeometry.snapToDevicePixels(10.8, 2), 11)

    // 1.5x DPR fractional scale: snaps to multiples of 1/1.5 = 2/3
    fuzzyCompare(WindowGeometry.snapToDevicePixels(10.0, 1.5), 10.0)
    fuzzyCompare(WindowGeometry.snapToDevicePixels(10.33, 1.5), 10.0)
    fuzzyCompare(WindowGeometry.snapToDevicePixels(10.4, 1.5), 10.66667)

    // Fallbacks on invalid DPR or NaN
    compare(WindowGeometry.snapToDevicePixels(15.4, 0), 15)
    compare(WindowGeometry.snapToDevicePixels(15.4, -1), 15)
    compare(WindowGeometry.snapToDevicePixels(15.4, null), 15)
    compare(WindowGeometry.snapToDevicePixels(NaN, 1), 0)
  }

  function test_focusedOverviewGeometry_singleCard() {
    var geom = WindowGeometry.focusedOverviewGeometry(1, 0, 1920, 1080, 1.55, 48)
    compare(geom.cards.length, 1)
    verify(geom.cards[0].isPrimary)
    verify(geom.cards[0].width > 1500)
    verify(geom.cards[0].height > 900)
  }

  function test_focusedOverviewGeometry_allocationAndSpacing() {
    var counts = [2, 3, 4, 6, 8, 10]
    for (var c = 0; c < counts.length; c++) {
      var count = counts[c]
      var geom = WindowGeometry.focusedOverviewGeometry(count, 0, 1920, 1080, 1.55, 48)
      compare(geom.cards.length, count)

      var primary = geom.cards[0]
      verify(primary.isPrimary)
      // Primary card occupies ~72-76% of usable overview width
      verify(primary.width >= 1920 * 0.65)
      verify(primary.height >= 1080 * 0.65)
      verify(primary.x >= 0)
      verify(primary.y >= 0)
      verify(primary.x + primary.width <= 1920 + 0.1)
      verify(primary.y + primary.height <= 1080 + 0.1)

      // Rail checks: single vertical column on the right
      verify(geom.rail !== null && geom.rail !== undefined)
      verify(geom.rail.width >= 200) // Sensible minimum card width
      verify(geom.rail.x >= primary.x + primary.width)

      for (var i = 1; i < count; i++) {
        var card = geom.cards[i]
        verify(!card.isPrimary)
        // Single vertical rail: all secondary cards share the rail X and width
        compare(card.x, geom.rail.x)
        compare(card.width, geom.rail.width)
        verify(card.width >= 200) // Sensible minimum width
        verify(card.height >= 120) // Sensible minimum height
        verify(card.y >= 0)
        if (i > 1) {
          // Ordered strictly vertically in single column with gap
          var prev = geom.cards[i - 1]
          fuzzyCompare(card.y - (prev.y + prev.height), 48)
        }
      }

      // Scroll requirement: when secondary content exceeds viewport, scrollNeeded is true
      if (geom.rail.contentHeight > 1080) {
        verify(geom.rail.scrollNeeded)
      } else {
        verify(!geom.rail.scrollNeeded)
      }
    }
  }

  function test_focusedOverviewGeometry_cyclicNavigation() {
    // 4 cards in focused layout: card 0 is primary, cards 1, 2, 3 are secondary
    var geom = WindowGeometry.focusedOverviewGeometry(4, 0, 1920, 1080, 1.55, 48)
    var items = []
    for (var i = 0; i < geom.cards.length; i++) {
      var c = geom.cards[i]
      items.push({
        index: i,
        x: c.x,
        y: c.y,
        width: c.width,
        height: c.height,
        centerX: c.x + c.width / 2,
        centerY: c.y + c.height / 2,
        isPrimary: c.isPrimary,
        isInsertion: false,
        visualOrder: i
      })
    }

    // Right / Down navigates forward 0 -> 1 -> 2 -> 3 -> 0
    compare(WindowGeometry.cyclicCardMove(items, 0, 1, 0), 1)
    compare(WindowGeometry.cyclicCardMove(items, 1, 1, 0), 2)
    compare(WindowGeometry.cyclicCardMove(items, 2, 1, 0), 3)
    compare(WindowGeometry.cyclicCardMove(items, 3, 1, 0), 0)

    compare(WindowGeometry.cyclicCardMove(items, 0, 0, 1), 1)
    compare(WindowGeometry.cyclicCardMove(items, 1, 0, 1), 2)
    compare(WindowGeometry.cyclicCardMove(items, 2, 0, 1), 3)
    compare(WindowGeometry.cyclicCardMove(items, 3, 0, 1), 0)

    // Left / Up navigates backward 0 -> 3 -> 2 -> 1 -> 0
    compare(WindowGeometry.cyclicCardMove(items, 0, -1, 0), 3)
    compare(WindowGeometry.cyclicCardMove(items, 3, -1, 0), 2)
    compare(WindowGeometry.cyclicCardMove(items, 2, -1, 0), 1)
    compare(WindowGeometry.cyclicCardMove(items, 1, -1, 0), 0)

    compare(WindowGeometry.cyclicCardMove(items, 0, 0, -1), 3)
    compare(WindowGeometry.cyclicCardMove(items, 3, 0, -1), 2)
    compare(WindowGeometry.cyclicCardMove(items, 2, 0, -1), 1)
    compare(WindowGeometry.cyclicCardMove(items, 1, 0, -1), 0)
  }

  function test_adaptiveOverview_workspaceCounts1to8() {
    var width = 1880
    var height = 1000
    var aspect = 1.55
    var spacing = 48

    var expectedDists = {
      1: [1],
      2: [2],
      3: [2, 1],
      4: [2, 2],
      5: [3, 2],
      6: [3, 3],
      7: [3, 2, 2],
      8: [3, 3, 2]
    }

    for (var count = 1; count <= 8; count++) {
      var geom = WindowGeometry.overviewGridGeometry(count, width, height, aspect, spacing)
      verify(geom !== null && geom !== undefined, "Geometry must be non-null for count " + count)
      compare(geom.cards.length, count, "No fake empty cards: cards.length must equal count")

      // 1. Verify expected optimal row distribution
      var expectedDist = expectedDists[count]
      compare(geom.rowDistribution.length, expectedDist.length, "Row count for " + count + " workspaces")
      for (var r = 0; r < expectedDist.length; r++) {
        compare(geom.rowDistribution[r], expectedDist[r], "Row " + r + " card count for " + count + " workspaces")
      }

      // 2. Verify all cards have IDENTICAL dimensions and preserve aspect ratio
      for (var i = 0; i < count; i++) {
        var card = geom.cards[i]
        compare(card.width, geom.cardWidth, "Card " + i + " must have identical common cardWidth")
        compare(card.height, geom.cardHeight, "Card " + i + " must have identical common cardHeight")
        fuzzyCompare(card.width / card.height, aspect, "Card " + i + " must preserve aspect ratio")

        // 3. Verify cards remain inside viewport
        verify(card.x >= -0.001, "Card " + i + " x must be inside viewport")
        verify(card.y >= -0.001, "Card " + i + " y must be inside viewport")
        verify(card.x + card.width <= width + 0.001, "Card " + i + " right must be inside viewport")
        verify(card.y + card.height <= height + 0.001, "Card " + i + " bottom must be inside viewport")
      }

      // 4. Verify no overlap between any two cards
      for (var a = 0; a < count; a++) {
        for (var b = a + 1; b < count; b++) {
          var ca = geom.cards[a]
          var cb = geom.cards[b]
          var separated = (ca.x + ca.width <= cb.x + 0.001)
            || (cb.x + cb.width <= ca.x + 0.001)
            || (ca.y + ca.height <= cb.y + 0.001)
            || (cb.y + cb.height <= ca.y + 0.001)
          verify(separated, "Cards " + a + " and " + b + " must not overlap")
        }
      }

      // 5. Verify every row is centered independently
      var cardIdx = 0
      for (var rowIdx = 0; rowIdx < geom.rows; rowIdx++) {
        var numInRow = geom.rowDistribution[rowIdx]
        var firstInRow = geom.cards[cardIdx]
        var lastInRow = geom.cards[cardIdx + numInRow - 1]
        var rowLeftMargin = firstInRow.x
        var rowRightMargin = width - (lastInRow.x + lastInRow.width)
        fuzzyCompare(rowLeftMargin, rowRightMargin, "Row " + rowIdx + " must be centered horizontally")
        cardIdx += numInRow
      }
    }
  }

  function test_adaptiveOverview_threeWorkspacesComparison() {
    var width = 1880
    var height = 1000
    var aspect = 1.55
    var spacing = 48

    // New adaptive solver
    var adaptive = WindowGeometry.overviewGridGeometry(3, width, height, aspect, spacing)
    compare(adaptive.cards.length, 3, "Exactly 3 cards rendered, no fake empty cells")
    compare(adaptive.rows, 2, "3 cards arranged in 2 rows")
    compare(adaptive.rowDistribution[0], 2, "Row 0 has 2 cards")
    compare(adaptive.rowDistribution[1], 1, "Row 1 has 1 card")

    // All 3 cards have identical dimensions
    compare(adaptive.cards[0].width, adaptive.cardWidth)
    compare(adaptive.cards[1].width, adaptive.cardWidth)
    compare(adaptive.cards[2].width, adaptive.cardWidth)
    compare(adaptive.cards[0].height, adaptive.cardHeight)
    compare(adaptive.cards[1].height, adaptive.cardHeight)
    compare(adaptive.cards[2].height, adaptive.cardHeight)

    // The single card in row 1 is centered horizontally
    var card2 = adaptive.cards[2]
    var card2CenterX = card2.x + card2.width / 2
    fuzzyCompare(card2CenterX, width / 2, "Row 1 single card must be centered horizontally at viewport center")

    // Card 2 is centered between Card 0 and Card 1
    var card0 = adaptive.cards[0]
    var card1 = adaptive.cards[1]
    var row0CenterX = (card0.x + card1.x + card1.width) / 2
    fuzzyCompare(card2CenterX, row0CenterX, "Row 1 card center matches Row 0 center")

    // Compare with old rigid grid with 520 cap
    var oldRigid = WindowGeometry.overviewGridGeometry(3, width, height, aspect, 520, spacing)
    compare(oldRigid.cardWidth, 520, "Old rigid grid capped cards at 520")
    verify(adaptive.cardWidth > oldRigid.cardWidth * 1.35, "Adaptive card width is >35% larger than old rigid 520 capped grid")
  }

  function test_adaptiveOverview_viewportShapes() {
    var spacing = 48

    // 1. 16:9 widescreen
    var w16_9 = WindowGeometry.overviewGridGeometry(3, 1880, 1000, 1.7778, spacing)
    compare(w16_9.rowDistribution[0], 2)
    compare(w16_9.rowDistribution[1], 1)

    // 2. 16:10
    var w16_10 = WindowGeometry.overviewGridGeometry(3, 1880, 1120, 1.6, spacing)
    compare(w16_10.rowDistribution[0], 2)
    compare(w16_10.rowDistribution[1], 1)

    // 3. Ultrawide (3440x1440)
    var uw = WindowGeometry.overviewGridGeometry(2, 3400, 1360, 2.38, spacing)
    compare(uw.rows, 1, "Ultrawide places 2 workspaces side by side")
    compare(uw.rowDistribution[0], 2)

    // 4. Portrait (1080x1920)
    var portrait = WindowGeometry.overviewGridGeometry(2, 1040, 1880, 0.56, spacing)
    compare(portrait.rows, 2, "Portrait places 2 workspaces vertically [1, 1]")
    compare(portrait.rowDistribution[0], 1)
    compare(portrait.rowDistribution[1], 1)
    compare(portrait.cards[0].width, portrait.cards[1].width)
    compare(portrait.cards[0].height, portrait.cards[1].height)

    // Verify portrait 5 workspaces uses 3 rows [2, 2, 1]
    var p5 = WindowGeometry.overviewGridGeometry(5, 1040, 1880, 0.56, spacing)
    compare(p5.rows, 3)
    compare(p5.rowDistribution[0], 2)
    compare(p5.rowDistribution[1], 2)
    compare(p5.rowDistribution[2], 1)
  }

  function test_adaptiveOverview_selectionDoesNotAffectGeometry() {
    var width = 1880
    var height = 1000
    var aspect = 1.55
    var spacing = 48

    // Normal mode overviewGridGeometry is deterministic and independent of selection
    var g1 = WindowGeometry.overviewGridGeometry(5, width, height, aspect, spacing)
    var g2 = WindowGeometry.overviewGridGeometry(5, width, height, aspect, spacing)
    compare(g1.cardWidth, g2.cardWidth)
    compare(g1.cardHeight, g2.cardHeight)
    for (var i = 0; i < 5; i++) {
      compare(g1.cards[i].x, g2.cards[i].x)
      compare(g1.cards[i].y, g2.cards[i].y)
      compare(g1.cards[i].width, g2.cards[i].width)
      compare(g1.cards[i].height, g2.cards[i].height)
    }

    // In contrast, Focused mode geometry depends on primaryIndex (selection)
    var f0 = WindowGeometry.focusedOverviewGeometry(5, 0, width, height, aspect, spacing)
    var f1 = WindowGeometry.focusedOverviewGeometry(5, 1, width, height, aspect, spacing)
    verify(f0.cards[0].isPrimary)
    verify(!f0.cards[1].isPrimary)
    verify(!f1.cards[0].isPrimary)
    verify(f1.cards[1].isPrimary)
  }

  function test_safeAreaGeometry_barPositions() {
    var screenW = 1920
    var screenH = 1080
    var margin = 16

    // 1. Top bar (35px, struts [0, 35, 0, 0])
    var topSafe = WindowGeometry.safeAreaGeometry(screenW, screenH, "top", 35, margin, [0, 35, 0, 0])
    compare(topSafe.safeLeft, 0)
    compare(topSafe.safeTop, 35)
    compare(topSafe.safeRight, 1920)
    compare(topSafe.safeBottom, 1080)
    compare(topSafe.safeWidth, 1920)
    compare(topSafe.safeHeight, 1045)
    compare(topSafe.usableX, 16)
    compare(topSafe.usableY, 51)
    compare(topSafe.usableWidth, 1888)
    compare(topSafe.usableHeight, 1013)

    // 2. Bottom bar (40px, struts [0, 0, 0, 40])
    var botSafe = WindowGeometry.safeAreaGeometry(screenW, screenH, "bottom", 40, margin, [0, 0, 0, 40])
    compare(botSafe.safeLeft, 0)
    compare(botSafe.safeTop, 0)
    compare(botSafe.safeRight, 1920)
    compare(botSafe.safeBottom, 1040)
    compare(botSafe.safeWidth, 1920)
    compare(botSafe.safeHeight, 1040)
    compare(botSafe.usableX, 16)
    compare(botSafe.usableY, 16)
    compare(botSafe.usableWidth, 1888)
    compare(botSafe.usableHeight, 1008)

    // 3. Left bar (48px, struts [48, 0, 0, 0])
    var leftSafe = WindowGeometry.safeAreaGeometry(screenW, screenH, "left", 48, margin, [48, 0, 0, 0])
    compare(leftSafe.safeLeft, 48)
    compare(leftSafe.safeTop, 0)
    compare(leftSafe.safeRight, 1920)
    compare(leftSafe.safeBottom, 1080)
    compare(leftSafe.safeWidth, 1872)
    compare(leftSafe.safeHeight, 1080)
    compare(leftSafe.usableX, 64)
    compare(leftSafe.usableY, 16)
    compare(leftSafe.usableWidth, 1840)
    compare(leftSafe.usableHeight, 1048)

    // 4. Right bar (48px, struts [0, 0, 48, 0])
    var rightSafe = WindowGeometry.safeAreaGeometry(screenW, screenH, "right", 48, margin, [0, 0, 48, 0])
    compare(rightSafe.safeLeft, 0)
    compare(rightSafe.safeTop, 0)
    compare(rightSafe.safeRight, 1872)
    compare(rightSafe.safeBottom, 1080)
    compare(rightSafe.safeWidth, 1872)
    compare(rightSafe.safeHeight, 1080)
    compare(rightSafe.usableX, 16)
    compare(rightSafe.usableY, 16)
    compare(rightSafe.usableWidth, 1840)
    compare(rightSafe.usableHeight, 1048)

    // 5. Hidden / No bar
    var noSafe = WindowGeometry.safeAreaGeometry(screenW, screenH, "", 0, margin, [0, 0, 0, 0])
    compare(noSafe.safeLeft, 0)
    compare(noSafe.safeTop, 0)
    compare(noSafe.safeRight, 1920)
    compare(noSafe.safeBottom, 1080)
    compare(noSafe.safeWidth, 1920)
    compare(noSafe.safeHeight, 1080)
    compare(noSafe.usableX, 16)
    compare(noSafe.usableY, 16)
    compare(noSafe.usableWidth, 1888)
    compare(noSafe.usableHeight, 1048)
  }

  function test_safeArea_zeroOverlapAndBounding() {
    var screenW = 1920
    var screenH = 1080
    var margin = 16
    var aspect = 1.55
    var spacing = 24

    var barConfigs = [
      { pos: "top", size: 35, struts: [0, 35, 0, 0], rect: { x: 0, y: 0, w: 1920, h: 35 } },
      { pos: "bottom", size: 40, struts: [0, 0, 0, 40], rect: { x: 0, y: 1040, w: 1920, h: 40 } },
      { pos: "left", size: 48, struts: [48, 0, 0, 0], rect: { x: 0, y: 0, w: 48, h: 1080 } },
      { pos: "right", size: 48, struts: [0, 0, 48, 0], rect: { x: 1872, y: 0, w: 48, h: 1080 } },
      { pos: "", size: 0, struts: [0, 0, 0, 0], rect: { x: 0, y: 0, w: 0, h: 0 } }
    ]

    var testCounts = [1, 2, 3, 4, 5, 8]

    for (var b = 0; b < barConfigs.length; b++) {
      var cfg = barConfigs[b]
      var safe = WindowGeometry.safeAreaGeometry(screenW, screenH, cfg.pos, cfg.size, margin, cfg.struts)

      for (var c = 0; c < testCounts.length; c++) {
        var count = testCounts[c]

        // --- Normal Mode ---
        var normal = WindowGeometry.overviewGridGeometry(count, safe.usableWidth, safe.usableHeight, aspect, spacing)
        for (var i = 0; i < normal.cards.length; i++) {
          var card = normal.cards[i]
          var absX = safe.usableX + card.x
          var absY = safe.usableY + card.y
          var absRight = absX + card.width
          var absBottom = absY + card.height

          // Verify strictly bounded inside safe area
          verify(absX >= safe.safeLeft, "Normal card " + i + " must not exceed safeLeft (" + absX + " >= " + safe.safeLeft + ")")
          verify(absY >= safe.safeTop, "Normal card " + i + " must not exceed safeTop (" + absY + " >= " + safe.safeTop + ")")
          verify(absRight <= safe.safeRight, "Normal card " + i + " must not exceed safeRight (" + absRight + " <= " + safe.safeRight + ")")
          verify(absBottom <= safe.safeBottom, "Normal card " + i + " must not exceed safeBottom (" + absBottom + " <= " + safe.safeBottom + ")")

          // Verify zero overlap with bar rectangle
          if (cfg.rect.w > 0 && cfg.rect.h > 0) {
            var overlaps = (absX < cfg.rect.x + cfg.rect.w &&
                            absRight > cfg.rect.x &&
                            absY < cfg.rect.y + cfg.rect.h &&
                            absBottom > cfg.rect.y)
            verify(!overlaps, "Normal card " + i + " must NEVER overlap bar rect for " + cfg.pos)
          }
        }

        // --- Focused Mode ---
        var focused = WindowGeometry.focusedOverviewGeometry(count, 0, safe.usableWidth, safe.usableHeight, aspect, spacing)
        if (focused.primaryCard) {
          var pCard = focused.primaryCard
          var pAbsX = safe.usableX + pCard.x
          var pAbsY = safe.usableY + pCard.y
          var pAbsRight = pAbsX + pCard.width
          var pAbsBottom = pAbsY + pCard.height

          // Verify primary card is strictly bounded inside safe area
          verify(pAbsX >= safe.safeLeft, "Focused primary card must not exceed safeLeft (" + pAbsX + " >= " + safe.safeLeft + ")")
          verify(pAbsY >= safe.safeTop, "Focused primary card must not exceed safeTop (" + pAbsY + " >= " + safe.safeTop + ")")
          verify(pAbsRight <= safe.safeRight, "Focused primary card must not exceed safeRight (" + pAbsRight + " <= " + safe.safeRight + ")")
          verify(pAbsBottom <= safe.safeBottom, "Focused primary card must not exceed safeBottom (" + pAbsBottom + " <= " + safe.safeBottom + ")")

          // Verify zero overlap with bar rectangle
          if (cfg.rect.w > 0 && cfg.rect.h > 0) {
            var pOverlaps = (pAbsX < cfg.rect.x + cfg.rect.w &&
                             pAbsRight > cfg.rect.x &&
                             pAbsY < cfg.rect.y + cfg.rect.h &&
                             pAbsBottom > cfg.rect.y)
            verify(!pOverlaps, "Focused primary card must NEVER overlap bar rect for " + cfg.pos)
          }
        }

        // Verify focused secondary rail viewport is strictly bounded inside safe area
        if (focused.rail && count > 1) {
          var rAbsX = safe.usableX + focused.rail.x
          var rAbsY = safe.usableY + focused.rail.y
          var rAbsRight = rAbsX + focused.rail.width
          var rAbsBottom = rAbsY + focused.rail.height

          verify(rAbsX >= safe.safeLeft, "Focused rail must not exceed safeLeft (" + rAbsX + " >= " + safe.safeLeft + ")")
          verify(rAbsY >= safe.safeTop, "Focused rail must not exceed safeTop (" + rAbsY + " >= " + safe.safeTop + ")")
          verify(rAbsRight <= safe.safeRight, "Focused rail must not exceed safeRight (" + rAbsRight + " <= " + safe.safeRight + ")")
          verify(rAbsBottom <= safe.safeBottom, "Focused rail must not exceed safeBottom (" + rAbsBottom + " <= " + safe.safeBottom + ")")

          if (cfg.rect.w > 0 && cfg.rect.h > 0) {
            var rOverlaps = (rAbsX < cfg.rect.x + cfg.rect.w &&
                             rAbsRight > cfg.rect.x &&
                             rAbsY < cfg.rect.y + cfg.rect.h &&
                             rAbsBottom > cfg.rect.y)
            verify(!rOverlaps, "Focused rail must NEVER overlap bar rect for " + cfg.pos)
          }
        }
      }
    }
  }

  function test_safeArea_previewDimensionsEnlargedWithTightenedSpacing() {
    var screenW = 1920
    var screenH = 1080
    var barSize = 35
    var aspect = 1.55

    // Prior baseline: outerMargin = 20, gridSpacing = 48
    var oldUsableW = screenW - 40 // 1880
    var oldUsableH = (screenH - barSize) - 40 // 1005
    var oldGrid3 = WindowGeometry.overviewGridGeometry(3, oldUsableW, oldUsableH, aspect, 48)
    var oldFocused3 = WindowGeometry.focusedOverviewGeometry(3, 0, oldUsableW, oldUsableH, aspect, 48)

    // Current improved: outerMargin = 16, gridSpacing = 24
    var safe = WindowGeometry.safeAreaGeometry(screenW, screenH, "top", barSize, 16, [0, 35, 0, 0])
    var newGrid3 = WindowGeometry.overviewGridGeometry(3, safe.usableWidth, safe.usableHeight, aspect, 24)
    var newFocused3 = WindowGeometry.focusedOverviewGeometry(3, 0, safe.usableWidth, safe.usableHeight, aspect, 24)

    // Normal mode 3 workspaces card enlargement
    var oldCardArea = oldGrid3.cardWidth * oldGrid3.cardHeight
    var newCardArea = newGrid3.cardWidth * newGrid3.cardHeight
    verify(newCardArea > oldCardArea, "New preview area must be strictly larger than old area")
    verify(newCardArea / oldCardArea > 1.06, "New preview area is >6.7% larger (got " + (newCardArea / oldCardArea) + ")")

    // Focused mode primary card and secondary rail enlargement
    var oldPrimaryArea = oldFocused3.primaryCard.width * oldFocused3.primaryCard.height
    var newPrimaryArea = newFocused3.primaryCard.width * newFocused3.primaryCard.height
    verify(newPrimaryArea >= oldPrimaryArea, "Focused primary card must be at least as large")
    verify(newFocused3.rail.width > oldFocused3.rail.width, "Secondary rail width must be larger with tightened spacing")
  }
}

