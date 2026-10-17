.pragma library
function entries(toplevels) {
  var rows = [], seen = {}
  for (var i = 0; i < toplevels.length && rows.length < 2048; i++) {
    var top = toplevels[i]
    if (!top) continue
    var ipc = top.lastIpcObject || {}
    var address = String(top.address || ipc.address || "").toLowerCase()
    if (!address || seen[address]) continue
    seen[address] = true
    var app = String((top.wayland && top.wayland.appId) || ipc.class || ipc.initialClass || "")
    var title = String(top.title || ipc.title || app || "Window")
    rows.push({address:address, title:title.slice(0,4096), app:app.slice(0,512),
      workspace:top.workspace ? String(top.workspace.name || top.workspace.id) : ""})
  }
  return rows
}
function filter(rows, query) {
  var terms = String(query || "").slice(0,256).toLowerCase().trim().split(/\s+/).filter(function(t) { return t.length > 0 })
  return rows.filter(function(row) {
    var text = (row.title + " " + row.app).toLowerCase()
    return terms.every(function(term) { return text.indexOf(term) >= 0 })
  }).sort(function(a,b) {
    var titleOrder = a.title.toLowerCase().localeCompare(b.title.toLowerCase())
    return titleOrder || a.address.localeCompare(b.address)
  }).slice(0,200)
}
function selectionIndex(rows, address) {
  for (var i = 0; i < rows.length; i++) if (rows[i].address === address) return i
  return 0
}
