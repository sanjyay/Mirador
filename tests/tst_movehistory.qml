import QtQuick 2.15
import QtTest 1.3
import "../MoveHistory.js" as History
TestCase {
 name:"MoveHistory"
 function test_record() {
  compare(History.record("0xabc",1,2,"1"),{address:"0xabc",sourceId:1,targetId:2,sourceTarget:"1"})
  compare(History.record("bad",1,2,"1"),null)
  compare(History.record("0xabc",1,1,"1"),null)
  compare(History.record("0xabc",NaN,2,"1"),null)
  compare(History.record("0xabc",-3,2,"name:project").sourceTarget,"name:project")
 }
 function test_revalidateCurrentMembership() {
  var move=History.record("0xabc",1,2,"1")
  verify(History.canUndo(move,{address:"0xabc",workspace:{id:2}}))
  verify(!History.canUndo(move,{address:"0xdef",workspace:{id:2}}))
  verify(!History.canUndo(move,{address:"0xabc",workspace:{id:3}}))
  verify(!History.canUndo(move,null));verify(!History.canUndo(null,{}))
 }
}
