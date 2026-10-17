import QtQuick
import QtTest
import "../WorkspaceHistory.js" as History
TestCase {
 name:"WorkspaceHistory"
 function test_remember() {
  compare(History.remember([2,1,3],1),[1,2,3])
  compare(History.remember([1],NaN),[1])
  var history=[];for(var i=1;i<200;i++)history=History.remember(history,i)
  compare(history.length,128)
 }
 function test_missingAndNew() {
  compare(History.ordered([1,2,3],[8,3,1,3]),[3,1,2])
  compare(History.next([1,2,3],[2,3,1],2,1),3)
  compare(History.next([1,2,3],[2,3,1],2,-1),1)
  compare(History.next([],[],1,1),null)
 }
 function test_stableSnapshot() {
  var snapshot=[2,3,1],updated=History.remember(snapshot,1)
  compare(snapshot,[2,3,1]);compare(updated,[1,2,3])
  compare(History.next([1,2,3],snapshot,2,1),3)
 }
}
