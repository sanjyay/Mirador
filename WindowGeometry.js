.pragma library

function finiteNumber(value) {
  var number = Number(value)
  return isFinite(number) ? number : NaN
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(value, maximum))
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

// Fit a complete workspace grid inside the bar-aware usable rectangle and
// return offsets that center it exactly. Trying every possible column count
// avoids aspect-ratio heuristics that become unbalanced for counts such as six
// or on portrait/ultrawide outputs.
function overviewGridGeometry(count, areaWidth, areaHeight, aspectRatio,
                              maximumCardWidth, spacing) {
  var safeCount = Math.max(0, Math.floor(finiteNumber(count) || 0))
  var safeWidth = Math.max(1, finiteNumber(areaWidth) || 1)
  var safeHeight = Math.max(1, finiteNumber(areaHeight) || 1)
  var safeAspect = Math.max(0.01, finiteNumber(aspectRatio) || 1)
  var safeMaximumWidth = Math.max(1, finiteNumber(maximumCardWidth) || safeWidth)
  var gap = Math.max(0, finiteNumber(spacing) || 0)

  if (safeCount === 0) {
    return { columns: 0, rows: 0, cardWidth: 0, cardHeight: 0,
      gridWidth: 0, gridHeight: 0, x: safeWidth / 2, y: safeHeight / 2 }
  }

  var best = null
  for (var columns = 1; columns <= safeCount; columns++) {
    var rows = Math.ceil(safeCount / columns)
    var widthAvailable = safeWidth - gap * (columns - 1)
    var heightAvailable = safeHeight - gap * (rows - 1)
    if (widthAvailable <= 0 || heightAvailable <= 0) continue

    var cardWidth = Math.min(
      safeMaximumWidth,
      widthAvailable / columns,
      heightAvailable / rows * safeAspect)
    if (!isFinite(cardWidth) || cardWidth <= 0) continue

    var cardHeight = cardWidth / safeAspect
    var gridWidth = cardWidth * columns + gap * (columns - 1)
    var gridHeight = cardHeight * rows + gap * (rows - 1)
    var candidate = {
      columns: columns,
      rows: rows,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      x: (safeWidth - gridWidth) / 2,
      y: (safeHeight - gridHeight) / 2
    }

    // Largest readable cards win. For effectively equal sizes, prefer the
    // arrangement closest to square, then fewer rows for stable landscape
    // layouts.
    var balance = Math.abs(columns - rows)
    var bestBalance = best ? Math.abs(best.columns - best.rows) : Infinity
    if (!best || cardWidth > best.cardWidth + 0.001
        || (Math.abs(cardWidth - best.cardWidth) <= 0.001
          && (balance < bestBalance
            || (balance === bestBalance && rows < best.rows))))
      best = candidate
  }

  return best || { columns: 1, rows: safeCount, cardWidth: 1,
    cardHeight: 1 / safeAspect, gridWidth: 1,
    gridHeight: safeCount / safeAspect + gap * (safeCount - 1),
    x: (safeWidth - 1) / 2,
    y: (safeHeight - (safeCount / safeAspect + gap * (safeCount - 1))) / 2 }
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
// - Left on leftmost workspace wraps to rightmost in the same row.
// - Right on rightmost workspace wraps to leftmost in the same row.
// - Up from top row wraps to bottom row.
// - Down from bottom row wraps to top row.
// - Vertical movement chooses the workspace whose horizontal center is closest
//   to the current workspace.
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

    validItems.push({
      item: it,
      index: it.index !== undefined ? it.index : i,
      x: x,
      y: y,
      width: w,
      height: h,
      centerX: cx,
      centerY: cy
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

  // Sort primarily top-to-bottom, secondarily left-to-right
  validItems.sort(function(a, b) {
    if (Math.abs(a.centerY - b.centerY) > 1) {
      return a.centerY - b.centerY
    }
    return a.centerX - b.centerX
  })

  // Group items into visual rows based on rendered vertical geometry
  var rows = []
  for (var i = 0; i < validItems.length; i++) {
    var item = validItems[i]
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

  // Sort rows top-to-bottom
  rows.sort(function(a, b) { return a.centerY - b.centerY })

  // Within each row, sort items left-to-right
  for (var r = 0; r < rows.length; r++) {
    rows[r].items.sort(function(a, b) { return a.centerX - b.centerX })
  }

  // Locate current row and column indices
  var currentRowIndex = -1
  var currentColIndex = -1
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].items.length; c++) {
      if (rows[r].items[c] === currentItem) {
        currentRowIndex = r
        currentColIndex = c
        break
      }
    }
    if (currentRowIndex !== -1) break
  }

  if (currentRowIndex === -1) {
    currentRowIndex = 0
    currentColIndex = 0
  }

  // Horizontal cyclic navigation within the same row
  if (dx !== 0) {
    var rowItems = rows[currentRowIndex].items
    var rowLen = rowItems.length
    if (rowLen <= 1) return rowItems[0].index

    var nextCol = currentColIndex
    if (dx < 0) {
      nextCol = (currentColIndex - 1 + rowLen) % rowLen
    } else if (dx > 0) {
      nextCol = (currentColIndex + 1) % rowLen
    }
    return rowItems[nextCol].index
  }

  // Vertical cyclic navigation with horizontal center proximity matching
  if (dy !== 0) {
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
