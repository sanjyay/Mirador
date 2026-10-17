.pragma library
function eligible(row) {
  return row && row.address && row.workspace && !row.floating && !row.pinned && !row.fullscreen
    && !(row.grouped && row.grouped.length>1) && row.at && row.size
    && row.at.every(function(v){return typeof v==="number" && isFinite(v)})
    && row.size.every(function(v){return typeof v==="number" && isFinite(v) && v>0})
}
function neighbor(rows,address,dx,dy) {
  if ((Math.abs(dx)+Math.abs(dy))!==1) return null
  var source=null
  for(var i=0;i<rows.length;i++)if(rows[i].address===address)source=rows[i]
  if(!eligible(source))return null
  var sx=source.at[0]+source.size[0]/2,sy=source.at[1]+source.size[1]/2
  var best=null,score=Infinity
  rows.forEach(function(row) {
    if(!eligible(row) || row.address===address || row.workspace.id!==source.workspace.id)return
    var x=row.at[0]+row.size[0]/2-sx,y=row.at[1]+row.size[1]/2-sy
    var forward=x*dx+y*dy
    if(forward<=0)return
    var cross=Math.abs(dx ? y : x)
    var rank=forward+cross*3
    if(rank<score){best=row;score=rank}
  })
  return best
}
