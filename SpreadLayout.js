.pragma library
function layout(rectangles, width, height, requestedGap, dpr) {
  var count = rectangles.length
  var ratio = typeof dpr === "number" && isFinite(dpr) && dpr > 0 ? dpr : 1
  var w = Math.max(1/ratio, isFinite(width) ? width : 1)
  var h = Math.max(1/ratio, isFinite(height) ? height : 1)
  if (!count) return {items:[],columns:0,rows:0}
  var average = 0
  rectangles.forEach(function(r) { average += r && r.width > 0 && r.height > 0 ? Math.max(0.2,Math.min(5,r.width/r.height)) : 16/9 })
  average /= count
  var guess = Math.max(1,Math.min(count,Math.round(Math.sqrt(count*w/h/average))))
  var candidates = [1,count,Math.max(1,guess-1),guess,Math.min(count,guess+1)]
  var best = null, bestScore = -1
  candidates.forEach(function(columns) {
    var rows = Math.ceil(count/columns)
    var gap = Math.max(0, Math.min(Number(requestedGap)||0,w/(columns*3),h/(rows*3)))
    var cellW = (w-gap*(columns-1))/columns
    var cellH = (h-gap*(rows-1))/rows
    var labelHeight = Math.min(28,cellH*0.25)
    var score = 0
    rectangles.forEach(function(rect) {
      var rw = rect && rect.width > 0 ? rect.width : 640
      var rh = rect && rect.height > 0 ? rect.height : 360
      var scale = Math.min(1,cellW/rw,Math.max(1/ratio,cellH-labelHeight)/rh)
      score += rw*rh*scale*scale
    })
    if (score > bestScore) { bestScore=score; best={columns:columns,rows:rows,gap:gap,cellW:cellW,cellH:cellH,labelHeight:labelHeight} }
  })
  function snap(v) { return Math.floor(Math.max(0,v)*ratio+0.000001)/ratio }
  var items = rectangles.map(function(rect,index) {
    var row=Math.floor(index/best.columns), col=index%best.columns
    var rowCount=Math.min(best.columns,count-row*best.columns)
    var rowWidth=rowCount*best.cellW+(rowCount-1)*best.gap
    var x=snap((w-rowWidth)/2+col*(best.cellW+best.gap))
    var y=snap(row*(best.cellH+best.gap))
    var cw=Math.max(1/ratio,snap(Math.min(best.cellW,w-x)))
    var ch=Math.max(1/ratio,snap(Math.min(best.cellH,h-y)))
    var rw=rect && rect.width>0 ? rect.width : 640
    var rh=rect && rect.height>0 ? rect.height : 360
    var scale=Math.min(1,cw/rw,Math.max(1/ratio,ch-best.labelHeight)/rh)
    var pw=Math.max(1/ratio,snap(rw*scale)), ph=Math.max(1/ratio,snap(rh*scale))
    return {x:x,y:y,width:cw,height:ch,centerX:x+cw/2,centerY:y+ch/2,
      previewX:snap((cw-pw)/2),previewY:snap(Math.max(0,(ch-best.labelHeight-ph)/2)),
      previewWidth:pw,previewHeight:ph,labelHeight:best.labelHeight}
  })
  return {items:items,columns:best.columns,rows:best.rows}
}
