import QtQuick 2.15
import QtTest 1.3
import "../ControlsModel.js" as ControlsModel
TestCase {
  name: "ControlsModel"
  function test_contexts() {
    verify(ControlsModel.footer("full", false, false).indexOf("Focus workspace") >= 0)
    verify(ControlsModel.footer("full", true, false).indexOf("Show all") >= 0)
    verify(ControlsModel.footer("carousel", false, false).indexOf("Select window") >= 0)
    verify(ControlsModel.footer("full", false, true).indexOf("Drop") >= 0)
    verify(ControlsModel.rows("carousel").length > ControlsModel.rows("compact").length)
  }
  function test_entriesAreComplete() {
    ["full","carousel","compact"].forEach(function(mode) {
      ControlsModel.rows(mode).forEach(function(row) {
        verify(row.key.length > 0)
        verify(row.action.length > 0)
      })
    })
  }
}
