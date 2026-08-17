.pragma library

function finiteNumber(value) {
  var number = Number(value)
  return isFinite(number) ? number : NaN
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(value, maximum))
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

// Intersect the real client with its monitor, normalize the intersection, and
// scale it into the card. Minimum sizing expands around the original center;
// overlap is deliberately allowed so the spatial arrangement remains intact.
function previewGeometry(ipcObject, monitor, screen, areaWidth, areaHeight,
                         minimumWidth, minimumHeight) {
  var client = clientGeometry(ipcObject)
  var output = logicalMonitorGeometry(monitor, screen)
  var targetWidth = finiteNumber(areaWidth)
  var targetHeight = finiteNumber(areaHeight)
  if (!client || !output || !isFinite(targetWidth) || !isFinite(targetHeight)
      || targetWidth <= 0 || targetHeight <= 0)
    return { valid: false, x: 0, y: 0, width: 0, height: 0 }

  var left = clamp(client.x - output.x, 0, output.width)
  var top = clamp(client.y - output.y, 0, output.height)
  var right = clamp(client.x + client.width - output.x, 0, output.width)
  var bottom = clamp(client.y + client.height - output.y, 0, output.height)
  if (right <= left || bottom <= top)
    return { valid: false, x: 0, y: 0, width: 0, height: 0 }

  var rawX = left / output.width * targetWidth
  var rawY = top / output.height * targetHeight
  var rawWidth = (right - left) / output.width * targetWidth
  var rawHeight = (bottom - top) / output.height * targetHeight
  var displayWidth = Math.min(targetWidth, Math.max(finiteNumber(minimumWidth) || 1, rawWidth))
  var displayHeight = Math.min(targetHeight, Math.max(finiteNumber(minimumHeight) || 1, rawHeight))
  var x = clamp(rawX + (rawWidth - displayWidth) / 2, 0, targetWidth - displayWidth)
  var y = clamp(rawY + (rawHeight - displayHeight) / 2, 0, targetHeight - displayHeight)

  return { valid: true, x: x, y: y, width: displayWidth, height: displayHeight }
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
