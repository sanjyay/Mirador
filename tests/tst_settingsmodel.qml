import QtQuick 2.15
import QtTest 1.3
import "../SettingsModel.js" as SettingsModel
TestCase {
  name: "SettingsModel"
  function test_invalidDocuments() {
    compare(SettingsModel.parse("broken"), null)
    compare(SettingsModel.parse("[]"), null)
    compare(SettingsModel.parse("null"), null)
    compare(SettingsModel.parse(new Array(65538).join("x")), null)
  }
  function test_defaultsAndPreservedValues() {
    var value = SettingsModel.parse('{"cycleUI":"carousel","modifier":"alt","future":42}')
    compare(value.cycleUI, "carousel")
    compare(value.modifier, "alt")
    compare(value.future, 42)
    compare(SettingsModel.normalized({cycleUI:"bad", modifier:"bad"}).cycleUI, "full")
    compare(SettingsModel.normalized({}).modifier, "super")
  }
  function test_backdropValidation() {
    compare(SettingsModel.normalized({backdropDim:2}).backdropDim, 1)
    compare(SettingsModel.parse('{"backdropDim":1}').backdropDim, 1)
    compare(SettingsModel.normalized({backdropDim:-1}).backdropDim, 0)
    compare(SettingsModel.normalized({backdropDim:"bad"}).backdropDim, 0.5)
    compare(SettingsModel.normalized({backdropBlur:"true"}).backdropBlur, false)
    compare(SettingsModel.normalized({backdropBlur:true}).backdropBlur, true)
  }
  function test_cycleChoicesWrap() {
    compare(SettingsModel.next("full", ["full","carousel","compact"], -1), "compact")
    compare(SettingsModel.next("compact", ["full","carousel","compact"], 1), "full")
  }
}
