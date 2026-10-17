.pragma library
function remember(history,id) {
  if (typeof id!=="number" || !isFinite(id) || id===0) return history.slice()
  return [id].concat(history.filter(function(value){return value!==id})).slice(0,128)
}
function ordered(existing,history) {
  var result=[]
  history.concat(existing).forEach(function(id) {
    if (existing.indexOf(id)>=0 && result.indexOf(id)<0) result.push(id)
  })
  return result
}
function next(existing,history,current,direction) {
  var values=ordered(existing,history)
  if (!values.length) return null
  var index=values.indexOf(current)
  if (index<0) return values[0]
  return values[(index+(direction<0 ? values.length-1 : 1))%values.length]
}
