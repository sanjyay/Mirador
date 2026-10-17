.pragma library
function record(address,sourceId,targetId,sourceTarget) {
  if (typeof address!=="string" || !/^0x[0-9a-f]+$/.test(address)
      || !isFinite(sourceId) || !isFinite(targetId) || sourceId===targetId
      || typeof sourceTarget!=="string" || !sourceTarget || sourceTarget.length>256) return null
  return {address:address,sourceId:Number(sourceId),targetId:Number(targetId),sourceTarget:sourceTarget}
}
function canUndo(record,client) {
  if (!record || !client || !client.workspace) return false
  var address=String(client.address || "").toLowerCase()
  if (address.indexOf("0x")!==0) address="0x"+address
  return address===record.address && Number(client.workspace.id)===record.targetId
}
