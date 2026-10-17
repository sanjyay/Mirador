import QtQuick 2.15
import QtTest 1.3
import "../MonitorModel.js" as MonitorModel
TestCase {
 name:"MonitorModel"
 function test_membership() {
  verify(MonitorModel.belongs({lastIpcObject:{monitor:"DP-1"}},{name:"DP-1",id:2}))
  verify(MonitorModel.belongs({monitorID:2},{name:"DP-1",id:2}))
  verify(!MonitorModel.belongs({monitor:"DP-2"},{name:"DP-1",id:2}))
  verify(!MonitorModel.belongs(null,{name:"DP-1"}))
 }
 function test_dropDestination() {
  compare(MonitorModel.destination({monitor:0,workspace:{id:1}},{id:1,activeWorkspace:{id:3}}),3)
  compare(MonitorModel.destination({monitor:1},{id:1,activeWorkspace:{id:3}}),null)
  compare(MonitorModel.destination({monitor:0},{id:1,activeWorkspace:{id:-1}}),null)
  compare(MonitorModel.destination(null,{id:1,activeWorkspace:{id:3}}),null)
 }
 function test_secondary() {
  compare(MonitorModel.secondary([{name:"A"},{name:"B"},null],{name:"A"}).map(function(s){return s.name}),["B"])
  compare(MonitorModel.secondary([],null).length,0)
 }
}
