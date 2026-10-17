.pragma library
function belongs(workspace,monitor) {
  if (!workspace || !monitor) return false
  var ipc=workspace.lastIpcObject || workspace
  var value=ipc.monitor
  if (value && typeof value==="object") return value.name===monitor.name || (value.id!==undefined && value.id===monitor.id)
  return value===monitor.name || (ipc.monitorID!==undefined && Number(ipc.monitorID)===Number(monitor.id))
}
function secondary(screens,target) {
  return (screens || []).filter(function(screen) { return screen && screen.name && (!target || screen.name!==target.name) })
}
