import QtQuick 2.15
import QtTest 1.3
import "../WindowActions.js" as Actions
TestCase {
 name:"WindowActions"
 function row(address,x,y,ws) {return {address:address,at:[x,y],size:[100,100],workspace:{id:ws},floating:false}}
 function test_neighborsAndWorkspaceBoundary() {
  var rows=[row("a",0,0,1),row("b",120,0,1),row("c",0,120,1),row("d",110,0,2)]
  compare(Actions.neighbor(rows,"a",1,0).address,"b")
  compare(Actions.neighbor(rows,"a",0,1).address,"c")
  compare(Actions.neighbor(rows,"a",-1,0),null)
  compare(Actions.neighbor(rows,"missing",1,0),null)
  compare(Actions.neighbor(rows,"a",1,1),null)
 }
 function test_exclusions() {
  ["floating","pinned","fullscreen"].forEach(function(key) {
   var b=row("b",120,0,1);b[key]=true
   compare(Actions.neighbor([row("a",0,0,1),b],"a",1,0),null)
  })
  var grouped=row("a",0,0,1);grouped.grouped=["a","b"];verify(!Actions.eligible(grouped))
  var invalid=row("a",NaN,0,1);verify(!Actions.eligible(invalid))
 }
}
