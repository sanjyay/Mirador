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
    // Left on leftmost in row 0 (index 0) wraps to rightmost in row 0 (index 2)
    compare(WindowGeometry.cyclicCardMove(grid, 0, -1, 0), 2)
    // Left on leftmost in row 1 (index 3) wraps to rightmost in row 1 (index 5)
    compare(WindowGeometry.cyclicCardMove(grid, 3, -1, 0), 5)
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
    // Right on rightmost in row 0 (index 2) wraps to leftmost in row 0 (index 0)
    compare(WindowGeometry.cyclicCardMove(grid, 2, 1, 0), 0)
    // Right on rightmost in row 1 (index 5) wraps to leftmost in row 1 (index 3)
    compare(WindowGeometry.cyclicCardMove(grid, 5, 1, 0), 3)
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
    // Left on leftmost in Row 1 (index 3) wraps to rightmost in Row 1 (index 4)
    compare(WindowGeometry.cyclicCardMove(ragged, 3, -1, 0), 4)
    // Right on rightmost in Row 1 (index 4) wraps to leftmost in Row 1 (index 3)
    compare(WindowGeometry.cyclicCardMove(ragged, 4, 1, 0), 3)
  }

  function test_cyclicNavigation_singleItemRows() {
    var singleItemRow = [
      { index: 0, x: 0, y: 0, width: 80, height: 60 },
      { index: 1, x: 100, y: 0, width: 80, height: 60 },
      { index: 2, x: 50, y: 100, width: 80, height: 60 }
    ]
    // Left and Right on single-item row wrap to itself
    compare(WindowGeometry.cyclicCardMove(singleItemRow, 2, -1, 0), 2)
    compare(WindowGeometry.cyclicCardMove(singleItemRow, 2, 1, 0), 2)

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
    // Repeated right navigation cycles across row
    var cur = 0
    var expectedRight = [1, 2, 0, 1, 2, 0, 1]
    for (var i = 0; i < expectedRight.length; i++) {
      cur = WindowGeometry.cyclicCardMove(grid, cur, 1, 0)
      compare(cur, expectedRight[i])
    }

    // Repeated left navigation cycles across row
    cur = 0
    var expectedLeft = [2, 1, 0, 2, 1, 0, 2]
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
}
