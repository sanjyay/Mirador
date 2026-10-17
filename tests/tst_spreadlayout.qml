import QtQuick 2.15
import QtTest 1.3
import "../SpreadLayout.js" as SpreadLayout
TestCase {
  name:"SpreadLayout"
  function test_layoutMatrix() {
    [1,2,3,7,20,50].forEach(function(count) {
      [[320,240],[1920,1080],[800,1600],[3440,1440]].forEach(function(size) {
        [1,1.25,2].forEach(function(dpr) {
          var rects=[]
          for(var i=0;i<count;i++) rects.push({width:i%2?800:1920,height:i%2?1200:1080})
          var layout=SpreadLayout.layout(rects,size[0],size[1],24,dpr)
          compare(layout.items.length,count)
          layout.items.forEach(function(a,index) {
            verify(a.x>=0 && a.y>=0)
            verify(a.x+a.width<=size[0]+0.001 && a.y+a.height<=size[1]+0.001)
            verify(a.previewWidth<=a.width+0.001 && a.previewHeight<=a.height+0.001)
            verify(Math.abs(a.previewWidth*dpr-Math.round(a.previewWidth*dpr))<0.001)
            for(var j=index+1;j<count;j++) {
              var b=layout.items[j]
              verify(a.x+a.width<=b.x+0.001 || b.x+b.width<=a.x+0.001 || a.y+a.height<=b.y+0.001 || b.y+b.height<=a.y+0.001)
            }
          })
        })
      })
    })
  }
  function test_emptyAndInvalidGeometry() {
    compare(SpreadLayout.layout([],100,100,20,1).items.length,0)
    var layout=SpreadLayout.layout([null,{width:0,height:0}],320,240,20,1)
    compare(layout.items.length,2)
    verify(layout.items[0].previewWidth>0)
  }
}
