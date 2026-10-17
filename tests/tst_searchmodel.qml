import QtQuick 2.15
import QtTest 1.3
import "../SearchModel.js" as SearchModel
TestCase {
  name: "SearchModel"
  function test_matchesTokensAndCase() {
    var rows = [{address:"1", title:"Project notes", app:"Foot"}, {address:"2", title:"Build output", app:"Foot"}]
    compare(SearchModel.filter(rows, "FOOT notes").length, 1)
    compare(SearchModel.filter(rows, "missing").length, 0)
    compare(SearchModel.filter(rows, "").length, 2)
  }
  function test_deduplicatesAndRetainsPlainTitles() {
    var top = {address:"0xabc", title:"<b>Private notes</b>", lastIpcObject:{class:"foot"}, workspace:{id:2}}
    var rows = SearchModel.entries([top,top,null])
    compare(rows.length, 1)
    compare(rows[0].title, "<b>Private notes</b>")
    compare(rows[0].workspace, "2")
  }
  function test_selectionFollowsAddress() {
    compare(SearchModel.selectionIndex([{address:"b"},{address:"a"}], "a"), 1)
    compare(SearchModel.selectionIndex([{address:"b"}], "gone"), 0)
    compare(SearchModel.selectionIndex([], "gone"), 0)
  }
  function test_resultLimit() {
    var rows = []
    for (var i=0;i<300;i++) rows.push({address:String(i),title:"Window "+i,app:"app"})
    compare(SearchModel.filter(rows, "").length, 200)
  }
}
