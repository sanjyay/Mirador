.pragma library

function normalizedAddress(value) {
  var address = String(value || "").trim().toLowerCase()
  if (!address.match(/^(0x)?[0-9a-f]+$/)) return ""
  return address.indexOf("0x") === 0 ? address : "0x" + address
}

function ipcObject(toplevel) {
  return toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : null
}

function toplevelAddress(toplevel) {
  var ipc = ipcObject(toplevel)
  return normalizedAddress((toplevel && toplevel.address) || (ipc && ipc.address))
}

function groupAddresses(toplevel) {
  var ipc = ipcObject(toplevel)
  // QVariantList values from Qt are array-like but are not guaranteed to pass
  // JavaScript's Array.isArray(), unlike the plain arrays used by unit tests.
  var grouped = ipc && ipc.grouped && typeof ipc.grouped.length === "number"
    ? ipc.grouped : []
  if (grouped.length === 0) return []

  var addresses = []
  for (var i = 0; i < grouped.length; i++) {
    var address = normalizedAddress(grouped[i])
    if (address && addresses.indexOf(address) === -1) addresses.push(address)
  }

  var ownAddress = toplevelAddress(toplevel)
  if (ownAddress && addresses.indexOf(ownAddress) === -1) addresses.push(ownAddress)
  return ownAddress && addresses.length >= 2 ? addresses : []
}

function componentRoot(parents, address) {
  var root = address
  while (parents[root] && parents[root] !== root) root = parents[root]
  while (parents[address] && parents[address] !== address) {
    var next = parents[address]
    parents[address] = root
    address = next
  }
  return root
}

function unionAddresses(parents, left, right) {
  if (!parents[left]) parents[left] = left
  if (!parents[right]) parents[right] = right
  var leftRoot = componentRoot(parents, left)
  var rightRoot = componentRoot(parents, right)
  if (leftRoot !== rightRoot) parents[rightRoot] = leftRoot
}

function betterGroupRepresentative(candidate, current, activeAddress) {
  if (!current) return true

  var candidateIpc = ipcObject(candidate) || {}
  var currentIpc = ipcObject(current) || {}

  // 1. Hidden state: hidden === true (e.g. minimized/hidden window) is strongly deprioritized
  var candidateHidden = candidateIpc.hidden === true
  var currentHidden = currentIpc.hidden === true
  if (!candidateHidden && currentHidden) return true
  if (candidateHidden && !currentHidden) return false

  // 2. Active window address match: if Hyprland's current active window belongs to the group, it wins
  var normActive = normalizedAddress(activeAddress)
  if (normActive) {
    var candidateAddr = toplevelAddress(candidate)
    var currentAddr = toplevelAddress(current)
    if (candidateAddr === normActive && currentAddr !== normActive) return true
    if (candidateAddr !== normActive && currentAddr === normActive) return false
  }

  // 3. acceptsInput check: in Hyprland, active group tab accepts input while background tabs do not
  var candidateInput = candidateIpc.acceptsInput === true
  var currentInput = currentIpc.acceptsInput === true
  if (candidateInput && !currentInput) return true
  if (!candidateInput && currentInput) return false

  // 4. focusHistoryID check: lower ID indicates more recently focused tab
  var candidateFocus = Number(candidateIpc.focusHistoryID)
  var currentFocus = Number(currentIpc.focusHistoryID)
  var candidateHasFocus = isFinite(candidateFocus) && candidateFocus >= 0
  var currentHasFocus = isFinite(currentFocus) && currentFocus >= 0

  if (candidateHasFocus && !currentHasFocus) return true
  if (!candidateHasFocus && currentHasFocus) return false
  if (candidateHasFocus && currentHasFocus && candidateFocus !== currentFocus) {
    return candidateFocus < currentFocus
  }

  // 5. visible flag fallback
  if (candidateIpc.visible === true && currentIpc.visible !== true) return true
  if (candidateIpc.visible !== true && currentIpc.visible === true) return false

  // 6. Stable fallback
  return false
}

// Resolve workspace toplevels into structured spatial preview descriptors.
// For Hyprland groups, exactly one spatial preview is produced with isGroup: true,
// referencing the active member for screencopy/geometry and retaining all group members.
function resolveWorkspacePreviews(clients, activeAddress) {
  var values = clients || []
  var parents = {}
  var ownAddresses = []

  // Build connected components for grouped windows
  for (var i = 0; i < values.length; i++) {
    var ownAddress = toplevelAddress(values[i])
    var addresses = groupAddresses(values[i])
    ownAddresses[i] = ownAddress
    if (addresses.length < 2) continue
    for (var addressIndex = 0; addressIndex < addresses.length; addressIndex++) {
      unionAddresses(parents, ownAddress, addresses[addressIndex])
    }
  }

  // Group members and find best representative for each group
  var groupMembersMap = {}
  var representatives = {}
  var keys = []

  for (var candidateIndex = 0; candidateIndex < values.length; candidateIndex++) {
    var candidateAddress = ownAddresses[candidateIndex]
    var key = candidateAddress && parents[candidateAddress]
      ? componentRoot(parents, candidateAddress) : ""
    keys[candidateIndex] = key

    if (key) {
      if (!groupMembersMap[key]) groupMembersMap[key] = []
      groupMembersMap[key].push(values[candidateIndex])
      if (betterGroupRepresentative(values[candidateIndex], representatives[key], activeAddress)) {
        representatives[key] = values[candidateIndex]
      }
    }
  }

  var result = []
  var seenKeys = {}

  for (var j = 0; j < values.length; j++) {
    var clientKey = keys[j]
    var client = values[j]

    if (!clientKey) {
      // Normal ungrouped window or null
      result.push({
        type: "window",
        isGroup: false,
        toplevel: client,
        activeMember: client,
        members: client ? [client] : [],
        memberCount: client ? 1 : 0,
        address: toplevelAddress(client),
        lastIpcObject: ipcObject(client),
        monitor: client ? client.monitor : null,
        wayland: client ? client.wayland : null,
        title: client ? (client.title || "") : ""
      })
    } else if (!seenKeys[clientKey]) {
      seenKeys[clientKey] = true
      var rep = representatives[clientKey] || client
      var members = groupMembersMap[clientKey] || [rep]
      var isRealGroup = members.length > 1

      result.push({
        type: isRealGroup ? "group" : "window",
        isGroup: isRealGroup,
        toplevel: rep,
        activeMember: rep,
        members: members,
        memberCount: members.length,
        address: toplevelAddress(rep),
        lastIpcObject: ipcObject(rep),
        monitor: rep ? rep.monitor : null,
        wayland: rep ? rep.wayland : null,
        title: rep ? (rep.title || "") : ""
      })
    }
  }

  return result
}

// Return active member toplevels for callers expecting plain client arrays.
function visibleWorkspaceWindows(clients, activeAddress) {
  var previews = resolveWorkspacePreviews(clients, activeAddress)
  var result = []
  for (var i = 0; i < previews.length; i++) {
    result.push(previews[i] ? previews[i].toplevel : null)
  }
  return result
}
