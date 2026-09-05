.pragma library

function finiteNumber(value) {
  var number = Number(value)
  return isFinite(number) ? number : NaN
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(value, maximum))
}

// Snap a coordinate or dimension to the nearest physical device pixel to ensure
// crisp rendering and eliminate bilinear subpixel interpolation blur.
function snapToDevicePixels(value, dpr) {
  var num = finiteNumber(value)
  if (isNaN(num)) return 0
  var scale = (finiteNumber(dpr) > 0) ? Number(dpr) : 1.0
  return Math.round(num * scale) / scale
}

// Return a nearly edge-to-edge canvas without ever producing negative sizes
// on extremely small cards. Workspace badges and window title pills overlay
// this rectangle and therefore do not reduce it.
function insetGeometry(width, height, requestedInset) {
  var safeWidth = Math.max(1, finiteNumber(width) || 1)
  var safeHeight = Math.max(1, finiteNumber(height) || 1)
  var inset = Math.max(0, finiteNumber(requestedInset) || 0)
  var x = Math.min(inset, Math.max(0, (safeWidth - 1) / 2))
  var y = Math.min(inset, Math.max(0, (safeHeight - 1) / 2))

  return {
    x: x,
    y: y,
    width: Math.max(1, safeWidth - x * 2),
    height: Math.max(1, safeHeight - y * 2)
  }
}

// Compute the safe viewport geometry by subtracting the reserved bar area
// from the screen/monitor bounds for any bar position ('top', 'bottom', 'left', 'right').
// Guarantees that cards and chrome never overlap the bar region in any direction.
function safeAreaGeometry(screenWidth, screenHeight, barPosition, barSize, outerMargin, reservedStruts) {
  var safeW = Math.max(1, finiteNumber(screenWidth) || 1)
  var safeH = Math.max(1, finiteNumber(screenHeight) || 1)
  var pos = String(barPosition || "").toLowerCase().trim()
  var bSize = Math.max(0, Math.min(Math.min(safeW, safeH) / 2, finiteNumber(barSize) || 0))
  var margin = Math.max(0, finiteNumber(outerMargin) || 0)

  var safeLeft = 0
  var safeTop = 0
  var safeRight = safeW
  var safeBottom = safeH

  if (pos === "top") {
    safeTop = bSize
  } else if (pos === "bottom") {
    safeBottom = Math.max(safeTop, safeH - bSize)
  } else if (pos === "left") {
    safeLeft = bSize
  } else if (pos === "right") {
    safeRight = Math.max(safeLeft, safeW - bSize)
  }

  if (reservedStruts && reservedStruts.length >= 4) {
    var rL = Math.max(0, finiteNumber(reservedStruts[0]) || 0)
    var rT = Math.max(0, finiteNumber(reservedStruts[1]) || 0)
    var rR = Math.max(0, finiteNumber(reservedStruts[2]) || 0)
    var rB = Math.max(0, finiteNumber(reservedStruts[3]) || 0)
    if (rL > safeLeft) safeLeft = rL
    if (rT > safeTop) safeTop = rT
    if (safeW - rR < safeRight) safeRight = Math.max(safeLeft, safeW - rR)
    if (safeH - rB < safeBottom) safeBottom = Math.max(safeTop, safeH - rB)
  }

  var safeViewportWidth = Math.max(1, safeRight - safeLeft)
  var safeViewportHeight = Math.max(1, safeBottom - safeTop)

  // Usable area after applying breathing margin inside the safe viewport
  var usableX = safeLeft + margin
  var usableY = safeTop + margin
  var usableWidth = Math.max(1, safeViewportWidth - margin * 2)
  var usableHeight = Math.max(1, safeViewportHeight - margin * 2)

  return {
    screenWidth: safeW,
    screenHeight: safeH,
    barPosition: pos,
    barSize: bSize,
    outerMargin: margin,
    safeLeft: safeLeft,
    safeTop: safeTop,
    safeRight: safeRight,
    safeBottom: safeBottom,
    safeWidth: safeViewportWidth,
    safeHeight: safeViewportHeight,
    usableX: usableX,
    usableY: usableY,
    usableWidth: usableWidth,
    usableHeight: usableHeight
  }
}

// Helper to generate balanced row distributions for count items into R rows.
// For example, count = 5, R = 2 produces [[3, 2], [2, 3]].
function getBalancedRowDistributions(count, R) {
  var kHigh = Math.ceil(count / R)
  var kLow = Math.floor(count / R)
  var h = count - kLow * R
  var l = R - h

  if (h === 0) {
    var single = []
    for (var i = 0; i < R; i++) single.push(kLow)
    return [single]
  }

  // Priority order:
  // 1. Top-heavy: h high rows, then l low rows (e.g. [2, 1], [3, 2], [3, 2, 2])
  // 2. Symmetric / centered distributions
  // 3. Bottom-heavy: l low rows, then h high rows (e.g. [1, 2], [2, 3], [2, 2, 3])
  var results = []
  var seen = {}

  function permute(remainingHigh, remainingLow, current) {
    if (remainingHigh === 0 && remainingLow === 0) {
      var key = current.join(",")
      if (!seen[key]) {
        seen[key] = true
        results.push(current.slice())
      }
      return
    }
    if (remainingHigh > 0) {
      current.push(kHigh)
      permute(remainingHigh - 1, remainingLow, current)
      current.pop()
    }
    if (remainingLow > 0) {
      current.push(kLow)
      permute(remainingHigh, remainingLow - 1, current)
      current.pop()
    }
  }

  permute(h, l, [])
  return results
}

// Adaptive equal-size overview layout solver for Normal overview mode.
// Solves: "What is the largest common workspace-card size that allows all workspaces to fit on screen?"
// Subject to:
// - every card has the same width
// - every card has the same height
// - workspace aspect ratio is preserved
// - all cards remain inside the usable viewport
// - reasonable spacing remains
// - rows are centered independently
// - no overlap
// - no fake empty workspace cells
function overviewGridGeometry(count, areaWidth, areaHeight, aspectRatio,
                              maximumCardWidth, spacing) {
  var effectiveSpacing = spacing
  var effectiveMaxWidth = maximumCardWidth
  if (arguments.length === 5) {
    effectiveSpacing = maximumCardWidth
    effectiveMaxWidth = null
  }

  var safeCount = Math.max(0, Math.floor(finiteNumber(count) || 0))
  var safeWidth = Math.max(1, finiteNumber(areaWidth) || 1)
  var safeHeight = Math.max(1, finiteNumber(areaHeight) || 1)
  var safeAspect = Math.max(0.01, finiteNumber(aspectRatio) || 1)
  var gap = Math.max(0, finiteNumber(effectiveSpacing) || 0)
  var safeMaximumWidth = (effectiveMaxWidth !== undefined && effectiveMaxWidth !== null && finiteNumber(effectiveMaxWidth) > 0)
    ? Math.max(1, finiteNumber(effectiveMaxWidth))
    : safeWidth

  if (safeCount === 0) {
    return {
      columns: 0,
      rows: 0,
      cardWidth: 0,
      cardHeight: 0,
      gridWidth: 0,
      gridHeight: 0,
      x: safeWidth / 2,
      y: safeHeight / 2,
      rowDistribution: [],
      cards: []
    }
  }

  if (safeCount === 1) {
    var singleW = Math.min(safeMaximumWidth, safeWidth, safeHeight * safeAspect)
    var singleH = singleW / safeAspect
    var singleX = (safeWidth - singleW) / 2
    var singleY = (safeHeight - singleH) / 2
    return {
      columns: 1,
      rows: 1,
      cardWidth: singleW,
      cardHeight: singleH,
      gridWidth: singleW,
      gridHeight: singleH,
      x: singleX,
      y: singleY,
      rowDistribution: [1],
      cards: [{
        index: 0,
        x: singleX,
        y: singleY,
        width: singleW,
        height: singleH,
        row: 0,
        col: 0
      }]
    }
  }

  var best = null
  var targetAspect = safeWidth / safeHeight

  // Evaluate candidate row counts from 1 up to safeCount
  for (var R = 1; R <= safeCount; R++) {
    var dists = getBalancedRowDistributions(safeCount, R)
    for (var d = 0; d < dists.length; d++) {
      var dist = dists[d]
      var Cmax = 0
      for (var k = 0; k < dist.length; k++) {
        if (dist[k] > Cmax) Cmax = dist[k]
      }
      var widthAvailable = safeWidth - gap * (Cmax - 1)
      var heightAvailable = safeHeight - gap * (R - 1)
      if (widthAvailable <= 0 || heightAvailable <= 0) continue

      var cardW = Math.min(
        safeMaximumWidth,
        widthAvailable / Cmax,
        (heightAvailable / R) * safeAspect)
      if (!isFinite(cardW) || cardW <= 0) continue

      var cardH = cardW / safeAspect
      var cardArea = cardW * cardH
      var gridW = Cmax * cardW + gap * (Cmax - 1)
      var gridH = R * cardH + gap * (R - 1)
      var gridAspect = gridW / gridH
      var aspectDiff = Math.abs(gridAspect - targetAspect)

      var candidate = {
        columns: Cmax,
        rows: R,
        rowDistribution: dist,
        cardWidth: cardW,
        cardHeight: cardH,
        cardArea: cardArea,
        gridWidth: gridW,
        gridHeight: gridH,
        x: (safeWidth - gridW) / 2,
        y: (safeHeight - gridH) / 2,
        aspectDiff: aspectDiff
      }

      // Objective: largest common card area wins
      if (!best || cardW > best.cardWidth + 0.001) {
        best = candidate
      } else if (Math.abs(cardW - best.cardWidth) <= 0.001) {
        // Tie breakers:
        // 1. Better screen shape match (aspectDiff)
        // 2. Fewer rows for stable landscape layouts
        if (candidate.aspectDiff < best.aspectDiff - 0.01) {
          best = candidate
        } else if (Math.abs(candidate.aspectDiff - best.aspectDiff) <= 0.01 && candidate.rows < best.rows) {
          best = candidate
        }
      }
    }
  }

  if (!best) {
    var fallbackDist = [safeCount]
    var fallbackH = safeCount / safeAspect + gap * (safeCount - 1)
    return {
      columns: 1,
      rows: safeCount,
      cardWidth: 1,
      cardHeight: 1 / safeAspect,
      gridWidth: 1,
      gridHeight: fallbackH,
      x: (safeWidth - 1) / 2,
      y: (safeHeight - fallbackH) / 2,
      rowDistribution: fallbackDist,
      cards: []
    }
  }

  // Populate individual card geometries with independent row centering
  var cards = []
  var curY = best.y
  var cardIdx = 0
  for (var r = 0; r < best.rows; r++) {
    var countInRow = best.rowDistribution[r]
    var rowW = countInRow * best.cardWidth + gap * (countInRow - 1)
    var rowX = (safeWidth - rowW) / 2
    for (var c = 0; c < countInRow; c++) {
      cards.push({
        index: cardIdx++,
        x: rowX + c * (best.cardWidth + gap),
        y: curY,
        width: best.cardWidth,
        height: best.cardHeight,
        row: r,
        col: c
      })
    }
    curY += best.cardHeight + gap
  }
  best.cards = cards

  return best
}

// Fit a focused workspace layout where the primary selected workspace occupies
// the majority of the screen (65-75% area), and remaining workspaces form an
// adaptive secondary rail/grid on the right.
function focusedOverviewGeometry(count, primaryIndex, areaWidth, areaHeight,
                                 aspectRatio, spacing) {
  var safeCount = Math.max(0, Math.floor(finiteNumber(count) || 0))
  var safeWidth = Math.max(1, finiteNumber(areaWidth) || 1)
  var safeHeight = Math.max(1, finiteNumber(areaHeight) || 1)
  var safeAspect = Math.max(0.01, finiteNumber(aspectRatio) || 1)
  var gap = Math.max(0, finiteNumber(spacing) || 0)
  var primIdx = safeCount > 0 ? Math.max(0, Math.min(safeCount - 1, Math.floor(finiteNumber(primaryIndex) || 0))) : 0

  if (safeCount === 0) {
    return { primaryIndex: -1, cards: [] }
  }

  if (safeCount === 1) {
    var singleW = Math.min(safeWidth, safeHeight * safeAspect)
    var singleH = singleW / safeAspect
    return {
      primaryIndex: 0,
      cards: [{
        index: 0,
        isPrimary: true,
        x: (safeWidth - singleW) / 2,
        y: (safeHeight - singleH) / 2,
        width: singleW,
        height: singleH
      }]
    }
  }

  var secCount = safeCount - 1
  // Single vertical rail layout:
  // Primary card targets 72-76% of usable width (capped by aspect ratio & safeHeight).
  // The secondary rail occupies the remaining horizontal width as a single column.
  var primRatio = 0.74
  var primW = Math.min(safeWidth * primRatio, safeHeight * safeAspect)
  var primH = primW / safeAspect
  if (primH > safeHeight) {
    primH = safeHeight
    primW = primH * safeAspect
  }

  var secAvailW = safeWidth - primW - gap
  // Enforce sensible minimum secondary card width/height
  var minSecW = Math.min(220, safeWidth * 0.22)
  if (secAvailW < minSecW && safeWidth > minSecW + 200) {
    secAvailW = minSecW
    primW = Math.min(safeWidth - secAvailW - gap, safeHeight * safeAspect)
    primH = primW / safeAspect
  }

  var secCardW = Math.max(1, secAvailW)
  var secCardH = Math.max(1, secCardW / safeAspect)

  var totalW = primW + gap + secCardW
  var startX = (safeWidth - totalW) / 2
  var primY = (safeHeight - primH) / 2

  var secXStart = startX + primW + gap

  // Total content height of the secondary column
  var totalSecContentH = secCount > 0 ? (secCardH * secCount + gap * (secCount - 1)) : 0
  var railVisibleH = safeHeight

  // If content fits within safeHeight, center it vertically in the rail;
  // otherwise, start at 0 so it scrolls downward.
  var secContentStartY = totalSecContentH <= safeHeight ? (safeHeight - totalSecContentH) / 2 : 0

  var cards = []
  for (var i = 0; i < safeCount; i++) {
    cards.push(null)
  }

  cards[primIdx] = {
    index: primIdx,
    isPrimary: true,
    x: startX,
    y: primY,
    width: primW,
    height: primH,
    railContentY: 0
  }

  var secIdx = 0
  for (var j = 0; j < safeCount; j++) {
    if (j === primIdx) continue
    var contentY = secContentStartY + secIdx * (secCardH + gap)
    cards[j] = {
      index: j,
      isPrimary: false,
      x: secXStart,
      y: contentY,
      width: secCardW,
      height: secCardH,
      railIndex: secIdx,
      railContentY: contentY
    }
    secIdx++
  }

  return {
    primaryIndex: primIdx,
    cards: cards,
    primaryCard: cards[primIdx],
    rail: {
      x: secXStart,
      y: 0,
      width: secCardW,
      height: railVisibleH,
      contentHeight: totalSecContentH,
      scrollNeeded: totalSecContentH > railVisibleH
    }
  }
}

// Hyprland reports client positions in global compositor coordinates. Monitor
// x/y share that coordinate space, while the monitor mode dimensions need to
// be converted to logical dimensions on scaled outputs. A matching QScreen is
// preferred for the logical extent because it also accounts for transforms.
function logicalMonitorGeometry(monitor, screen) {
  if (!monitor) return null

  var x = finiteNumber(monitor.x)
  var y = finiteNumber(monitor.y)
  var scale = finiteNumber(monitor.scale)
  var width = screen && screen.name === monitor.name
    ? finiteNumber(screen.width) : finiteNumber(monitor.width) / (scale > 0 ? scale : 1)
  var height = screen && screen.name === monitor.name
    ? finiteNumber(screen.height) : finiteNumber(monitor.height) / (scale > 0 ? scale : 1)

  if (!isFinite(x) || !isFinite(y) || !isFinite(width) || !isFinite(height)
      || width <= 0 || height <= 0)
    return null

  return { x: x, y: y, width: width, height: height }
}

function clientGeometry(ipcObject) {
  if (!ipcObject || !ipcObject.at || !ipcObject.size
      || ipcObject.at.length < 2 || ipcObject.size.length < 2)
    return null

  var x = finiteNumber(ipcObject.at[0])
  var y = finiteNumber(ipcObject.at[1])
  var width = finiteNumber(ipcObject.size[0])
  var height = finiteNumber(ipcObject.size[1])
  if (!isFinite(x) || !isFinite(y) || !isFinite(width) || !isFinite(height)
      || width <= 0 || height <= 0)
    return null

  return { x: x, y: y, width: width, height: height }
}

// Extract monitor reserved insets [left, top, right, bottom]
function monitorReservedInsets(monitor) {
  if (!monitor) return { left: 0, top: 0, right: 0, bottom: 0 }
  var res = monitor.reserved || (monitor.lastIpcObject ? monitor.lastIpcObject.reserved : null)
  if (res && typeof res.length === "number") {
    return {
      left: Math.max(0, finiteNumber(res[0]) || 0),
      top: Math.max(0, finiteNumber(res[1]) || 0),
      right: Math.max(0, finiteNumber(res[2]) || 0),
      bottom: Math.max(0, finiteNumber(res[3]) || 0)
    }
  }
  if (res) {
    return {
      left: Math.max(0, finiteNumber(res.left) || 0),
      top: Math.max(0, finiteNumber(res.top) || 0),
      right: Math.max(0, finiteNumber(res.right) || 0),
      bottom: Math.max(0, finiteNumber(res.bottom) || 0)
    }
  }
  return { left: 0, top: 0, right: 0, bottom: 0 }
}

// Logical monitor extent minus reserved margins (e.g. status bar).
function usableMonitorGeometry(monitor, screen) {
  var logical = logicalMonitorGeometry(monitor, screen)
  if (!logical) return null

  var reserved = monitorReservedInsets(monitor)
  var x = logical.x + reserved.left
  var y = logical.y + reserved.top
  var width = Math.max(1, logical.width - reserved.left - reserved.right)
  var height = Math.max(1, logical.height - reserved.top - reserved.bottom)

  return {
    x: x,
    y: y,
    width: width,
    height: height,
    logicalWidth: logical.width,
    logicalHeight: logical.height,
    reserved: reserved
  }
}

// Compute the shared uniform scale and centering offsets for a workspace.
function workspaceTransform(monitor, screen, areaWidth, areaHeight) {
  var usable = usableMonitorGeometry(monitor, screen)
  var targetWidth = finiteNumber(areaWidth)
  var targetHeight = finiteNumber(areaHeight)
  if (!usable || !isFinite(targetWidth) || !isFinite(targetHeight)
      || targetWidth <= 0 || targetHeight <= 0)
    return null

  var scale = Math.min(targetWidth / usable.width, targetHeight / usable.height)
  if (!isFinite(scale) || scale <= 0) return null

  var renderedWidth = usable.width * scale
  var renderedHeight = usable.height * scale
  var offsetX = (targetWidth - renderedWidth) / 2
  var offsetY = (targetHeight - renderedHeight) / 2

  return {
    scale: scale,
    originX: usable.x,
    originY: usable.y,
    usableWidth: usable.width,
    usableHeight: usable.height,
    renderedWidth: renderedWidth,
    renderedHeight: renderedHeight,
    offsetX: offsetX,
    offsetY: offsetY,
    canvasWidth: targetWidth,
    canvasHeight: targetHeight
  }
}

// Project a client into the shared preview canvas using uniform aspect-ratio
// scaling and the monitor's usable workspace coordinates. Minimum sizing expands
// around the window center without altering the global transform.
function previewGeometry(ipcObject, monitor, screen, areaWidth, areaHeight,
                         minimumWidth, minimumHeight) {
  var client = clientGeometry(ipcObject)
  var transform = workspaceTransform(monitor, screen, areaWidth, areaHeight)
  if (!client || !transform)
    return { valid: false, x: 0, y: 0, width: 0, height: 0 }

  var clientLeft = client.x
  var clientTop = client.y
  var clientRight = client.x + client.width
  var clientBottom = client.y + client.height

  var workspaceLeft = transform.originX
  var workspaceTop = transform.originY
  var workspaceRight = transform.originX + transform.usableWidth
  var workspaceBottom = transform.originY + transform.usableHeight

  var left = clamp(clientLeft, workspaceLeft, workspaceRight)
  var top = clamp(clientTop, workspaceTop, workspaceBottom)
  var right = clamp(clientRight, workspaceLeft, workspaceRight)
  var bottom = clamp(clientBottom, workspaceTop, workspaceBottom)
  if (right <= left || bottom <= top)
    return { valid: false, x: 0, y: 0, width: 0, height: 0 }

  var relativeX = left - transform.originX
  var relativeY = top - transform.originY
  var relativeWidth = right - left
  var relativeHeight = bottom - top

  var rawX = transform.offsetX + relativeX * transform.scale
  var rawY = transform.offsetY + relativeY * transform.scale
  var rawWidth = relativeWidth * transform.scale
  var rawHeight = relativeHeight * transform.scale

  var minW = finiteNumber(minimumWidth) || 0
  var minH = finiteNumber(minimumHeight) || 0
  var displayWidth = Math.min(transform.canvasWidth, Math.max(minW, rawWidth))
  var displayHeight = Math.min(transform.canvasHeight, Math.max(minH, rawHeight))

  var x = clamp(rawX + (rawWidth - displayWidth) / 2, 0, transform.canvasWidth - displayWidth)
  var y = clamp(rawY + (rawHeight - displayHeight) / 2, 0, transform.canvasHeight - displayHeight)

  return {
    valid: true,
    x: x,
    y: y,
    width: displayWidth,
    height: displayHeight,
    rawX: rawX,
    rawY: rawY,
    rawWidth: rawWidth,
    rawHeight: rawHeight,
    scale: transform.scale,
    offsetX: transform.offsetX,
    offsetY: transform.offsetY
  }
}

// Malformed/unavailable IPC geometry must not make a window disappear. Keep
// such clients in a compact bottom-right grid without affecting valid clients.
function fallbackGeometry(index, count, areaWidth, areaHeight, spacing) {
  var safeCount = Math.max(1, Number(count) || 1)
  var columns = Math.max(1, Math.ceil(Math.sqrt(safeCount)))
  var rows = Math.max(1, Math.ceil(safeCount / columns))
  var gap = Math.max(0, finiteNumber(spacing) || 0)
  var regionWidth = Math.max(1, finiteNumber(areaWidth) * 0.42)
  var regionHeight = Math.max(1, finiteNumber(areaHeight) * 0.42)
  var width = Math.max(1, (regionWidth - gap * (columns - 1)) / columns)
  var height = Math.max(1, (regionHeight - gap * (rows - 1)) / rows)
  var column = Math.max(0, Number(index) || 0) % columns
  var row = Math.floor(Math.max(0, Number(index) || 0) / columns)

  return {
    valid: false,
    x: Math.max(0, finiteNumber(areaWidth) - regionWidth) + column * (width + gap),
    y: Math.max(0, finiteNumber(areaHeight) - regionHeight) + row * (height + gap),
    width: width,
    height: height
  }
}

// ── Cyclic 2D Workspace Navigation ──────────────────────────────────────────
// Computes next selected workspace index using rendered 2D geometry with wrap-around.
//
// Rules:
// - Left / Right = one continuous global cycle across all visual rows:
//   Workspaces are ordered in visual reading order (top row left-to-right, then second row left-to-right, etc.).
//   Right advances to the next workspace in the global visual sequence; from the very last workspace, wraps to the very first.
//   Left moves to the previous workspace in the global visual sequence; from the very first workspace, wraps to the very last.
//   Left / Right do NOT wrap inside the current row.
// - Up / Down = spatial row navigation:
//   Moves between visual rows (dy > 0 next row down, dy < 0 next row up).
//   Up from top row wraps to bottom row; Down from bottom row wraps to top row.
//   Chooses the workspace in the target row whose horizontal center (centerX) is closest to the current workspace's horizontal center.
// - Operates purely on rendered geometry (x, y, width, height, centerX, centerY),
//   never on workspace IDs.
// - Ignores insertion cards (isInsertion === true) and non-workspace elements.
// - Correctly handles ragged rows and single-workspace rows.
function cyclicCardMove(items, currentIndex, dx, dy) {
  if (!items || items.length === 0) return -1

  var validItems = []
  for (var i = 0; i < items.length; i++) {
    var it = items[i]
    if (!it || it.isInsertion) continue
    var x = finiteNumber(it.x)
    var y = finiteNumber(it.y)
    var w = finiteNumber(it.width) || 0
    var h = finiteNumber(it.height) || 0
    if (isNaN(x) || isNaN(y)) continue

    var cx = (it.centerX !== undefined && !isNaN(finiteNumber(it.centerX)))
      ? finiteNumber(it.centerX) : (x + w / 2)
    var cy = (it.centerY !== undefined && !isNaN(finiteNumber(it.centerY)))
      ? finiteNumber(it.centerY) : (y + h / 2)

    var visualOrder = it.visualOrder !== undefined ? finiteNumber(it.visualOrder) : NaN
    var isPrimary = Boolean(it.isPrimary)

    validItems.push({
      item: it,
      index: it.index !== undefined ? it.index : i,
      x: x,
      y: y,
      width: w,
      height: h,
      centerX: cx,
      centerY: cy,
      visualOrder: isNaN(visualOrder) ? null : visualOrder,
      isPrimary: isPrimary
    })
  }

  if (validItems.length === 0) return -1
  if (validItems.length === 1) return validItems[0].index
  if (dx === 0 && dy === 0) return currentIndex

  var currentItem = null
  for (var i = 0; i < validItems.length; i++) {
    if (validItems[i].index === currentIndex) {
      currentItem = validItems[i]
      break
    }
  }
  if (!currentItem) {
    currentItem = validItems[0]
  }

  // 1. Horizontal navigation: one continuous global cycle
  // If items provide explicit visualOrder, respect it for the global reading cycle.
  if (dx !== 0) {
    var hasExplicitOrder = true
    for (var i = 0; i < validItems.length; i++) {
      if (validItems[i].visualOrder === null) {
        hasExplicitOrder = false
        break
      }
    }

    var orderedItems = []
    if (hasExplicitOrder) {
      orderedItems = validItems.slice().sort(function(a, b) {
        return a.visualOrder - b.visualOrder
      })
    } else {
      // Sort primarily top-to-bottom, secondarily left-to-right
      var geomSorted = validItems.slice().sort(function(a, b) {
        if (Math.abs(a.centerY - b.centerY) > 1) return a.centerY - b.centerY
        return a.centerX - b.centerX
      })

      var rGroup = []
      for (var i = 0; i < geomSorted.length; i++) {
        var itm = geomSorted[i]
        var added = false
        for (var r = 0; r < rGroup.length; r++) {
          var rCy = rGroup[r].centerY
          var rH = rGroup[r].height || itm.height || 1
          if (Math.abs(itm.centerY - rCy) < rH * 0.5) {
            rGroup[r].items.push(itm)
            var sumY = 0
            for (var k = 0; k < rGroup[r].items.length; k++) sumY += rGroup[r].items[k].centerY
            rGroup[r].centerY = sumY / rGroup[r].items.length
            added = true
            break
          }
        }
        if (!added) {
          rGroup.push({ centerY: itm.centerY, height: itm.height, items: [itm] })
        }
      }
      rGroup.sort(function(a, b) { return a.centerY - b.centerY })
      for (var r = 0; r < rGroup.length; r++) {
        rGroup[r].items.sort(function(a, b) { return a.centerX - b.centerX })
        for (var c = 0; c < rGroup[r].items.length; c++) {
          orderedItems.push(rGroup[r].items[c])
        }
      }
    }

    var currentGlobalIndex = -1
    for (var i = 0; i < orderedItems.length; i++) {
      if (orderedItems[i].index === currentItem.index) {
        currentGlobalIndex = i
        break
      }
    }
    if (currentGlobalIndex === -1) currentGlobalIndex = 0

    var total = orderedItems.length
    if (total <= 1) return orderedItems[0].index

    var nextGlobalIndex = currentGlobalIndex
    if (dx > 0) {
      nextGlobalIndex = (currentGlobalIndex + 1) % total
    } else if (dx < 0) {
      nextGlobalIndex = (currentGlobalIndex - 1 + total) % total
    }
    return orderedItems[nextGlobalIndex].index
  }

  // 2. Vertical navigation: spatial row navigation with wrapping
  if (dy !== 0) {
    // If a primary card exists alongside secondary cards (focused layout)
    var primaryItem = null
    var secondaryItems = []
    for (var i = 0; i < validItems.length; i++) {
      if (validItems[i].isPrimary) primaryItem = validItems[i]
      else secondaryItems.push(validItems[i])
    }

    if (primaryItem && secondaryItems.length > 0) {
      // In focused mode with single vertical rail, navigation moves up/down the global workspace sequence
      var hasExplicitOrder = true
      for (var i = 0; i < validItems.length; i++) {
        if (validItems[i].visualOrder === undefined || validItems[i].visualOrder === null) {
          hasExplicitOrder = false
          break
        }
      }

      var orderedItems = []
      if (hasExplicitOrder) {
        orderedItems = validItems.slice().sort(function(a, b) {
          return a.visualOrder - b.visualOrder
        })
      } else {
        orderedItems = validItems.slice().sort(function(a, b) {
          return a.index - b.index
        })
      }

      var currentGlobalIndex = -1
      for (var i = 0; i < orderedItems.length; i++) {
        if (orderedItems[i].index === currentItem.index) {
          currentGlobalIndex = i
          break
        }
      }
      if (currentGlobalIndex === -1) currentGlobalIndex = 0

      var total = orderedItems.length
      if (total <= 1) return orderedItems[0].index

      var nextGlobalIndex = currentGlobalIndex
      if (dy > 0) {
        nextGlobalIndex = (currentGlobalIndex + 1) % total
      } else if (dy < 0) {
        nextGlobalIndex = (currentGlobalIndex - 1 + total) % total
      }
      return orderedItems[nextGlobalIndex].index
    }

    // Default uniform row grouping for normal overview mode
    var geomSorted = validItems.slice().sort(function(a, b) {
      if (Math.abs(a.centerY - b.centerY) > 1) return a.centerY - b.centerY
      return a.centerX - b.centerX
    })

    var rows = []
    for (var i = 0; i < geomSorted.length; i++) {
      var item = geomSorted[i]
      var added = false
      for (var r = 0; r < rows.length; r++) {
        var rowCenterY = rows[r].centerY
        var rowHeight = rows[r].height || item.height || 1
        if (Math.abs(item.centerY - rowCenterY) < rowHeight * 0.5) {
          rows[r].items.push(item)
          var sumY = 0
          for (var k = 0; k < rows[r].items.length; k++) sumY += rows[r].items[k].centerY
          rows[r].centerY = sumY / rows[r].items.length
          added = true
          break
        }
      }
      if (!added) {
        rows.push({
          centerY: item.centerY,
          height: item.height,
          items: [item]
        })
      }
    }

    rows.sort(function(a, b) { return a.centerY - b.centerY })
    for (var r = 0; r < rows.length; r++) {
      rows[r].items.sort(function(a, b) { return a.centerX - b.centerX })
    }

    var currentRowIndex = -1
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].items.length; c++) {
        if (rows[r].items[c].index === currentItem.index) {
          currentRowIndex = r
          break
        }
      }
      if (currentRowIndex !== -1) break
    }
    if (currentRowIndex === -1) currentRowIndex = 0

    var numRows = rows.length
    if (numRows <= 1) return currentItem.index

    var targetRowIndex = currentRowIndex
    if (dy < 0) {
      targetRowIndex = (currentRowIndex - 1 + numRows) % numRows
    } else if (dy > 0) {
      targetRowIndex = (currentRowIndex + 1) % numRows
    }

    var targetRowItems = rows[targetRowIndex].items
    if (targetRowItems.length === 0) return currentItem.index

    var currentCx = currentItem.centerX
    var bestItem = targetRowItems[0]
    var bestDiff = Math.abs(bestItem.centerX - currentCx)

    for (var i = 1; i < targetRowItems.length; i++) {
      var cand = targetRowItems[i]
      var diff = Math.abs(cand.centerX - currentCx)
      if (diff < bestDiff) {
        bestDiff = diff
        bestItem = cand
      }
    }
    return bestItem.index
  }

  return currentIndex
}
