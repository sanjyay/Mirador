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
    compare(SettingsModel.normalized({backdropDim:2}).backdropDim, 0.85)
    compare(SettingsModel.normalized({backdropDim:-1}).backdropDim, 0)
    compare(SettingsModel.normalized({backdropDim:"bad"}).backdropDim, 0.5)
    compare(SettingsModel.normalized({backdropBlur:"true"}).backdropBlur, false)
    compare(SettingsModel.normalized({backdropBlur:true}).backdropBlur, true)
  }
  function test_layoutOptions() {
    compare(SettingsModel.normalized({layoutDensity:"unknown"}).layoutDensity, "compact")
    compare(SettingsModel.spacingScale("compact"), 1)
    compare(SettingsModel.spacingScale("comfortable"), 1.25)
    compare(SettingsModel.spacingScale("airy"), 1.5)
    verify(SettingsModel.neighborOpacity("quiet") < SettingsModel.neighborOpacity("normal"))
    verify(SettingsModel.neighborOpacity("strong") > SettingsModel.neighborOpacity("normal"))
  }
  function test_reducedMotionDurations() {
    compare(SettingsModel.motionDuration(true, 150), 0)
    compare(SettingsModel.motionDuration(false, 150), 150)
    compare(SettingsModel.motionDuration(false, -1), 0)
    compare(SettingsModel.motionDuration(false, NaN), 0)
    compare(SettingsModel.normalized({reducedMotion:"true"}).reducedMotion, false)
    compare(SettingsModel.normalized({reducedMotion:true}).reducedMotion, true)
  }
  function test_cycleChoicesWrap() {
    compare(SettingsModel.next("full", ["full","carousel","compact"], -1), "compact")
    compare(SettingsModel.next("compact", ["full","carousel","compact"], 1), "full")
  }
}
