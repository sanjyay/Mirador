import QtQuick 2.15
import QtTest 1.3

TestCase {
  id: testCase
  name: "SettingsPanel"
  width: 540; height: 500
  visible: true
  when: windowShown
  property var panel: null
  SignalSpy { id: saves; target: testCase.panel; signalName: "applyRequested" }
  SignalSpy { id: cancels; target: testCase.panel; signalName: "cancelled" }
  function initTestCase() {
    var request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../SettingsPanel.qml"), false)
    request.send()
    verify(request.status === 0 || request.status === 200)
    // Run the production dialog and keyboard handlers with lightweight paint
    // fixtures, since qs.Commons/Ui require the running desktop shell.
    var source = request.responseText.replace(/^import qs\..*\n/gm, "")
      .replace("import QtQuick", 'import QtQuick 2.15\nimport "' + Qt.resolvedUrl("fixtures/settings") + '" as Fixtures')
      .replace(/Commons\.Color\./g, "Fixtures.Color.")
      .replace(/Style\./g, "Fixtures.Style.")
      .replace(/\bButton\s*\{/g, "Fixtures.Button {")
    panel = Qt.createQmlObject(source, testCase, Qt.resolvedUrl("../SettingsPanel.qml"))
    panel.width = 500
    panel.height = 400
    panel.visible = false
  }
  function cleanupTestCase() { if (panel) panel.destroy() }
  function init() {
    panel.visible = false
    panel.busy = false
    panel.height = 400
    panel.errorText = ""
    panel.preferences = {cycleUI:"full",modifier:"super",backdropDim:0.5,backdropBlur:false,future:42}
    panel.visible = true
    panel.forceActiveFocus()
    saves.clear(); cancels.clear()
  }
  function press(key, modifiers) { keyClick(key, modifiers || Qt.NoModifier) }
  function test_onlyAppearanceControlsAreExposed() {
    compare(panel.fields.map(function(field) { return field.key }), ["backdropDim", "backdropBlur"])
    compare(panel.saveRow, 2)
    compare(panel.cancelRow, 3)
  }
  function test_tabIncludesActionsAndWraps() {
    for (var i = 1; i < panel.controlCount; i++) { press(Qt.Key_Tab); compare(panel.selectedRow, i) }
    press(Qt.Key_Tab); compare(panel.selectedRow, 0)
    press(Qt.Key_Tab, Qt.ShiftModifier); compare(panel.selectedRow, panel.cancelRow)
    press(Qt.Key_Backtab); compare(panel.selectedRow, panel.saveRow)
  }
  function test_arrowsAndActionRow() {
    press(Qt.Key_Up); compare(panel.selectedRow, panel.cancelRow)
    press(Qt.Key_Left); compare(panel.selectedRow, panel.saveRow)
    press(Qt.Key_Right); compare(panel.selectedRow, panel.cancelRow)
    press(Qt.Key_Down); compare(panel.selectedRow, 0)
    press(Qt.Key_Down, Qt.ShiftModifier); compare(panel.selectedRow, 1)
  }
  function test_enterEditsFieldWithoutSaving() {
    press(Qt.Key_Return); compare(panel.draft.backdropDim, 0.75); compare(saves.count, 0)
    press(Qt.Key_Space); compare(panel.draft.backdropDim, 1); compare(saves.count, 0)
    press(Qt.Key_Left); compare(panel.draft.backdropDim, 0.75)
    compare(panel.preferences.backdropDim, 0.5)
  }
  function test_heldActivationDoesNotLeakIntoOverview() {
    panel.select(panel.saveRow)
    keyPress(Qt.Key_Return)
    wait(30)
    compare(saves.count, 0)
    keyRelease(Qt.Key_Return)
    compare(saves.count, 1)
    keyPress(Qt.Key_Escape)
    compare(cancels.count, 0)
    keyRelease(Qt.Key_Escape)
    compare(cancels.count, 1)
  }
  function test_fullDimmingCanBeSavedReopenedAndWrapped() {
    press(Qt.Key_Right); press(Qt.Key_Right)
    compare(panel.draft.backdropDim, 1)
    compare(panel.displayValue(panel.fields[0]), "100%")
    panel.select(panel.saveRow); press(Qt.Key_Return)
    compare(saves.count, 1)
    compare(saves.signalArguments[0][0].backdropDim, 1)
    panel.visible = false
    panel.preferences = saves.signalArguments[0][0]
    panel.visible = true
    compare(panel.draft.backdropDim, 1)
    press(Qt.Key_Right); compare(panel.draft.backdropDim, 0)
    press(Qt.Key_Left); compare(panel.draft.backdropDim, 1)
  }
  function test_saveUsesDraftAndPreservesUnknownPreferences() {
    press(Qt.Key_Return)
    panel.select(panel.saveRow)
    press(Qt.Key_Return)
    compare(saves.count, 1); compare(cancels.count, 0)
    compare(saves.signalArguments[0][0].backdropDim, 0.75)
    compare(saves.signalArguments[0][0].cycleUI, "full")
    compare(saves.signalArguments[0][0].modifier, "super")
    compare(saves.signalArguments[0][0].future, 42)
  }
  function test_cancelAndReopenDiscardDraft() {
    press(Qt.Key_Return)
    panel.select(panel.cancelRow); press(Qt.Key_Space)
    compare(cancels.count, 1); compare(saves.count, 0)
    panel.visible = false; panel.visible = true
    compare(panel.draft.backdropDim, 0.5); compare(panel.selectedRow, 0)
  }
  function test_escapeAndF2OnlyCancel() {
    press(Qt.Key_Escape); press(Qt.Key_F2)
    compare(cancels.count, 2); compare(saves.count, 0)
  }
  function test_busyBlocksKeysAndActionsThenRestoresFocus() {
    panel.select(panel.saveRow); panel.busy = true
    press(Qt.Key_Return); press(Qt.Key_Escape); press(Qt.Key_Tab)
    panel.activate(); panel.change(1)
    compare(saves.count, 0); compare(cancels.count, 0)
    compare(panel.selectedRow, panel.saveRow)
    panel.busy = false
    verify(panel.activeFocus)
    press(Qt.Key_Return); compare(saves.count, 1)
  }
  function test_shortcutsDoNotEditDraftOrLeaveDialog() {
    press(Qt.Key_Return, Qt.ControlModifier)
    press(Qt.Key_Right, Qt.MetaModifier)
    press(Qt.Key_Tab, Qt.AltModifier)
    compare(panel.selectedRow, 0); compare(panel.draft.backdropDim, 0.5)
    compare(saves.count, 0); compare(cancels.count, 0)
  }
  function test_clickThenKeyboardUsesSameSelection() {
    var actions = findChild(panel, "settingsActions")
    var save = actions.children[0]
    mouseClick(save, save.width / 2, save.height / 2)
    compare(saves.count, 1); compare(panel.selectedRow, panel.saveRow)
    verify(panel.activeFocus)
    press(Qt.Key_Tab); compare(panel.selectedRow, panel.cancelRow)
    press(Qt.Key_Return); compare(cancels.count, 1)
  }
  function test_smallPanelScrollsActionsIntoView() {
    panel.height = 170
    panel.select(panel.saveRow)
    wait(0)
    var scroll = findChild(panel, "settingsScroll")
    var actions = findChild(panel, "settingsActions")
    var position = actions.mapToItem(scroll, 0, 0)
    verify(position.y >= -0.1)
    verify(position.y + actions.height <= scroll.height + 0.1)
    panel.select(0); wait(0)
    verify(scroll.contentY < actions.y)
  }
  function test_saveErrorKeepsDraftAndActionReachable() {
    press(Qt.Key_Return)
    panel.select(panel.saveRow); panel.busy = true
    panel.errorText = "Could not save settings."
    panel.busy = false
    compare(panel.draft.backdropDim, 0.75)
    compare(panel.selectedRow, panel.saveRow)
    press(Qt.Key_Tab); press(Qt.Key_Return)
    compare(cancels.count, 1); compare(saves.count, 0)
  }
}
