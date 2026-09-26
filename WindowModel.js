.pragma library

// Quote a workspace target as a Lua string literal for Quattro dispatches.
function luaStringLiteral(value) {
  return '"' + String(value).replace(/[\x00-\x1f\\"]/g, function(ch) {
    if (ch === "\\" || ch === '"') return "\\" + ch
    var decimal = String(ch.charCodeAt(0))
    return "\\" + ("000" + decimal).slice(-3)
  }) + '"'
}

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
        groupKey: "",
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
        groupKey: isRealGroup ? clientKey : "",
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

// Synchronize window preview delegates incrementally using window address / group key as identity.
// Existing delegates survive property updates without being destroyed or recreated.
function syncPreviewDelegates(container, currentMap, previews, component, options) {
  var activeMap = {}
  var values = previews || []
  var map = currentMap || {}
  var opts = options || {}

  for (var i = 0; i < values.length; i++) {
    var p = values[i]
    if (!p) continue
    var key = p.groupKey || p.address
    if (!key && p.toplevel) {
      key = toplevelAddress(p.toplevel)
    }
    if (!key) continue

    activeMap[key] = true
    var existing = map[key]
    if (existing) {
      if (typeof opts.onUpdate === "function") {
        opts.onUpdate(existing, p, i)
      } else {
        existing.itemIndex = i
        existing.modelData = p
      }
    } else {
      var initialProps = (typeof opts.initialProps === "function")
        ? opts.initialProps(p, i)
        : { modelData: p, itemIndex: i, toplevel: (p && p.toplevel ? p.toplevel : null) }

      var newDel = component.createObject(container, initialProps)
      if (newDel) {
        map[key] = newDel
      }
    }
  }

  for (var oldKey in map) {
    if (!activeMap[oldKey]) {
      var del = map[oldKey]
      if (del) {
        if (typeof opts.onDestroy === "function") {
          opts.onDestroy(del)
        }
        del.destroy()
      }
      delete map[oldKey]
    }
  }

  return map
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

// Select the window that should receive a close request for a workspace.
// excludedAddresses contains windows for which a close has already been sent;
// Quickshell's toplevel model can retain those objects briefly after Hyprland's
// close event, so they must not block successive close requests.
function selectCloseTarget(clients, activeAddress, excludedAddresses, preferredAddress) {
  var values = clients || []
  var excluded = excludedAddresses || {}
  var usable = []

  for (var i = 0; i < values.length; i++) {
    var candidate = values[i]
    var address = toplevelAddress(candidate)
    if (!candidate || !address || excluded[address]) continue
    usable.push(candidate)
  }

  if (usable.length === 0) return null

  var normActive = normalizedAddress(activeAddress)
  var normPreferred = normalizedAddress(preferredAddress)
  var previews = resolveWorkspacePreviews(usable, normActive)
  var best = null

  if (normPreferred) {
    for (var preferredIndex = 0; preferredIndex < previews.length; preferredIndex++) {
      var preferredPreview = previews[preferredIndex]
      var preferredTop = preferredPreview
        ? (preferredPreview.activeMember || preferredPreview.toplevel) : null
      if (preferredTop && toplevelAddress(preferredTop) === normPreferred) return preferredTop
    }
  }

  for (var p = 0; p < previews.length; p++) {
    var preview = previews[p]
    var candidateTop = preview ? (preview.activeMember || preview.toplevel) : null
    if (!candidateTop) continue

    if (normActive && toplevelAddress(candidateTop) === normActive) {
      return candidateTop
    }

    if (betterGroupRepresentative(candidateTop, best, normActive)) {
      best = candidateTop
    }
  }

  return best
}

// Canonical test for special workspace name strings
function isSpecialWorkspaceName(name) {
  if (typeof name !== "string") return false
  return name === "special" || name.indexOf("special:") === 0
}

// Check whether a workspace object or ID represents a special/scratchpad workspace.
// Prioritizes explicit name and type checks (e.g. "special:scratchpad", isSpecial, isScratchpad)
// while retaining negative IDs as compositor fallback metadata only when name is omitted.
function isSpecialWorkspace(ws) {
  if (ws === null || ws === undefined) return false
  if (typeof ws === "string") return isSpecialWorkspaceName(ws)
  if (typeof ws === "object") {
    if (ws.isSpecial !== undefined && ws.isSpecial !== null) return Boolean(ws.isSpecial)
    if (ws.isScratchpad !== undefined && ws.isScratchpad !== null) return Boolean(ws.isScratchpad)
    var name = String(ws.name || "")
    if (name === "special" || name.indexOf("special:") === 0) return true
    if (name.length > 0) return false
    var idNum = Number(ws.id)
    if (!isNaN(idNum) && idNum < 0) return true
    return false
  }
  if (typeof ws === "number") return ws < 0
  return false
}

// Keep a named workspace's stable dispatch name for cycle cancellation.
// Hyprland assigns ordinary named workspaces negative internal IDs.
function restoreWorkspaceTarget(ws) {
  if (!ws || isSpecialWorkspace(ws)) return 1
  var id = Number(ws.id)
  if (isFinite(id) && id > 0) return id
  var name = String(ws.name || "")
  if (name) return name.indexOf("name:") === 0 ? name : "name:" + name
  return 1
}

// Extract the target name for Hyprland dispatchers (e.g. "scratchpad" for togglespecialworkspace)
function specialWorkspaceName(ws) {
  if (ws === null || ws === undefined) return "scratchpad"
  if (typeof ws === "string") {
    if (ws.indexOf("special:") === 0) return ws.slice(8)
    if (ws === "special") return ""
    return ws
  }
  if (ws.specialName) return String(ws.specialName)
  var name = String(ws.name || "")
  if (name.indexOf("special:") === 0) return name.slice(8)
  if (name === "special") return ""
  return name || "scratchpad"
}

// Compute the badge display label for any workspace card ("S" for scratchpads, "0" for 10, or custom name)
function workspaceBadgeText(workspaceId, isScratchpad, wsOrName) {
  if (isScratchpad) return "S"
  if (wsOrName) {
    if (typeof wsOrName === "string" && wsOrName.length > 0) {
      if (wsOrName === "special" || wsOrName.indexOf("special:") === 0) return "S"
      var nameNum = Number(wsOrName)
      if (nameNum === 10) return "0"
      return wsOrName
    }
    if (typeof wsOrName === "object") {
      if (isSpecialWorkspace(wsOrName)) return "S"
      if (wsOrName.name && wsOrName.name !== String(wsOrName.id)) {
        var objNameNum = Number(wsOrName.name)
        if (objNameNum === 10) return "0"
        return String(wsOrName.name)
      }
    }
  }
  var idNum = Number(workspaceId)
  if (idNum === 10) return "0"
  if (!isNaN(idNum) && idNum > 0) return String(idNum)
  if (typeof workspaceId === "string" && !isSpecialWorkspaceName(workspaceId)) return workspaceId
  if (idNum < 0 && (!wsOrName || isSpecialWorkspace(wsOrName))) return "S"
  return String(workspaceId !== undefined && workspaceId !== null ? workspaceId : "")
}

// Find the index in cardModel corresponding to a target workspace number, name, or scratchpad
function findWorkspaceCardIndex(cardModel, target) {
  if (!cardModel || cardModel.length === 0) return -1

  var targetStr = String(target !== undefined && target !== null ? target : "")
  var targetNum = typeof target === "number" ? target : parseInt(target, 10)

  // 1. Special scratchpad target matching (e.g. "scratchpad", "special", "special:music", or -1)
  var isGenericScratch = (target === "scratchpad" || target === "special" || target === -1)
  var isNamedSpecial = isSpecialWorkspaceName(targetStr) || targetStr.indexOf("special:") === 0

  if (isNamedSpecial) {
    var specTargetName = specialWorkspaceName(targetStr)
    for (var sn = 0; sn < cardModel.length; sn++) {
      var snItem = cardModel[sn]
      if (typeof snItem === "object" && Boolean(snItem.isScratchpad)) {
        var snWsId = snItem.workspaceId
        if (snWsId === target || snWsId === targetStr) return sn
        if (specialWorkspaceName(snItem) === specTargetName) return sn
        if (snItem.workspace && specialWorkspaceName(snItem.workspace) === specTargetName) return sn
        if (specialWorkspaceName(snWsId) === specTargetName) return sn
      }
    }
  }

  for (var sp = 0; sp < cardModel.length; sp++) {
    var spItem = cardModel[sp]
    if (typeof spItem === "object" && Boolean(spItem.isScratchpad)) {
      if (specialWorkspaceName(spItem) === targetStr) return sp
      if (spItem.workspace && specialWorkspaceName(spItem.workspace) === targetStr) return sp
    }
  }

  if (isGenericScratch) {
    for (var s = 0; s < cardModel.length; s++) {
      var sItem = cardModel[s]
      var sWsId = typeof sItem === "object" ? sItem.workspaceId : sItem
      var isScratch = (typeof sItem === "object" && Boolean(sItem.isScratchpad))
        || (typeof sWsId === "number" && sWsId < 0 && (!sItem || sItem.isScratchpad !== false))
      if (isScratch) return s
    }
    return -1
  }

  // 2. Direct name match (e.g. "DP-1:1", "Web", or "code")
  if (typeof target === "string" && isNaN(targetNum)) {
    for (var n = 0; n < cardModel.length; n++) {
      var nItem = cardModel[n]
      if (typeof nItem === "object" && !nItem.isInsertion) {
        var strWsId = nItem.workspaceId
        var nName = String(nItem.workspaceName || nItem.name || "")
        if (strWsId === target || nName === target) return n
      } else if (nItem === target) {
        return n
      }
    }
  }

  if (isNaN(targetNum)) return -1

  // 3. Direct workspaceId match (skipping insertion targets)
  for (var i = 0; i < cardModel.length; i++) {
    var item = cardModel[i]
    var wsId = typeof item === "object" ? item.workspaceId : item
    var isIns = typeof item === "object" && Boolean(item.isInsertion)
    if (!isIns && wsId === targetNum) return i
  }

  // 4. Named workspace suffix match (e.g. target 1 matches "DP-1:1")
  if (targetNum >= 0 && targetNum <= 10) {
    var numSuffix = ":" + (targetNum === 0 ? "10" : targetNum)
    for (var m = 0; m < cardModel.length; m++) {
      var mItem = cardModel[m]
      if (typeof mItem === "object" && !mItem.isInsertion && !mItem.isScratchpad) {
        var mName = String(mItem.workspaceName || mItem.name || "")
        if (mName === String(targetNum) || (mName.length >= numSuffix.length && mName.indexOf(numSuffix) === mName.length - numSuffix.length)) {
          return m
        }
      }
    }
  }

  // 5. Key 0 maps to workspace 10, but if 10 is missing, check if workspace 0 exists
  if (targetNum === 10) {
    for (var j = 0; j < cardModel.length; j++) {
      var it0 = cardModel[j]
      var id0 = typeof it0 === "object" ? it0.workspaceId : it0
      var isI0 = typeof it0 === "object" && Boolean(it0.isInsertion)
      if (!isI0 && id0 === 0) return j
    }
  }

  // 5. Conversely, if 0 was passed and missing, check if workspace 10 exists
  if (targetNum === 0) {
    for (var k = 0; k < cardModel.length; k++) {
      var it10 = cardModel[k]
      var id10 = typeof it10 === "object" ? it10.workspaceId : it10
      var isI10 = typeof it10 === "object" && Boolean(it10.isInsertion)
      if (!isI10 && id10 === 10) return k
    }
  }

  return -1
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
