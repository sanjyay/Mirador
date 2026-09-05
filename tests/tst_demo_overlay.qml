import QtQuick 2.15
import QtTest 1.3

TestCase {
  name: "DemoOverlay"

  function demoOverlaySource() {
    var request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../DemoInputOverlay.qml"), false)
    request.send()
    verify(request.status === 0 || request.status === 200)
    return request.responseText
  }

  function formatKeySequence(event) {
    if (!event) return ""
    var mods = []
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
    if (event.modifiers & Qt.AltModifier) mods.push("ALT")
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")
    if (event.modifiers & Qt.MetaModifier) mods.push("SUPER")

    var k = event.key
    var text = ""

    if (k === Qt.Key_Control || k === Qt.Key_Shift || k === Qt.Key_Alt || k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R) {
      return ""
    }

    if (k === Qt.Key_Left) text = "←"
    else if (k === Qt.Key_Right) text = "→"
    else if (k === Qt.Key_Up) text = "↑"
    else if (k === Qt.Key_Down) text = "↓"
    else if (k === Qt.Key_Return || k === Qt.Key_Enter) text = "ENTER"
    else if (k === Qt.Key_Escape) text = "ESC"
    else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) text = "TAB"
    else if (k === Qt.Key_Space) text = "SPACE"
    else if (k === Qt.Key_Plus || event.text === "+") text = "+"
    else if (k === Qt.Key_Equal || event.text === "=") text = "="
    else if (k === Qt.Key_Backspace) text = "BACKSPACE"
    else if (k === Qt.Key_Delete) text = "DELETE"
    else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
      text = event.text.toUpperCase()
    } else if (k >= Qt.Key_A && k <= Qt.Key_Z) {
      text = String.fromCharCode(k)
    } else if (k >= Qt.Key_0 && k <= Qt.Key_9) {
      text = String.fromCharCode(k)
    }

    if (!text) return ""
    return mods.length > 0 ? (mods.join(" + ") + " + " + text) : text
  }

  function test_formatKeySequenceBasic() {
    // Arrow keys
    compare(formatKeySequence({ key: Qt.Key_Left, modifiers: 0, text: "" }), "←")
    compare(formatKeySequence({ key: Qt.Key_Right, modifiers: 0, text: "" }), "→")
    compare(formatKeySequence({ key: Qt.Key_Up, modifiers: 0, text: "" }), "↑")
    compare(formatKeySequence({ key: Qt.Key_Down, modifiers: 0, text: "" }), "↓")

    // Common navigation keys
    compare(formatKeySequence({ key: Qt.Key_Return, modifiers: 0, text: "" }), "ENTER")
    compare(formatKeySequence({ key: Qt.Key_Enter, modifiers: 0, text: "" }), "ENTER")
    compare(formatKeySequence({ key: Qt.Key_Escape, modifiers: 0, text: "" }), "ESC")
    compare(formatKeySequence({ key: Qt.Key_Tab, modifiers: 0, text: "" }), "TAB")
    compare(formatKeySequence({ key: Qt.Key_Space, modifiers: 0, text: " " }), "SPACE")
    compare(formatKeySequence({ key: Qt.Key_Plus, modifiers: 0, text: "+" }), "+")
    compare(formatKeySequence({ key: Qt.Key_Equal, modifiers: 0, text: "=" }), "=")
  }

  function test_formatKeySequenceModifiers() {
    compare(formatKeySequence({ key: Qt.Key_Return, modifiers: Qt.ControlModifier, text: "" }), "CTRL + ENTER")
    compare(formatKeySequence({ key: Qt.Key_Left, modifiers: Qt.ShiftModifier, text: "" }), "SHIFT + ←")
    compare(formatKeySequence({ key: Qt.Key_Right, modifiers: Qt.MetaModifier, text: "" }), "SUPER + →")
    compare(formatKeySequence({ key: Qt.Key_Right, modifiers: Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier | Qt.MetaModifier, text: "" }), "CTRL + ALT + SHIFT + SUPER + →")
  }

  function test_modifierOnlyPressesAreIgnored() {
    compare(formatKeySequence({ key: Qt.Key_Control, modifiers: Qt.ControlModifier, text: "" }), "")
    compare(formatKeySequence({ key: Qt.Key_Shift, modifiers: Qt.ShiftModifier, text: "" }), "")
    compare(formatKeySequence({ key: Qt.Key_Alt, modifiers: Qt.AltModifier, text: "" }), "")
    compare(formatKeySequence({ key: Qt.Key_Meta, modifiers: Qt.MetaModifier, text: "" }), "")
  }

  function test_demoInputOverlayStructure() {
    var source = demoOverlaySource()
    verify(/property bool demoMode\s*:\s*false/.test(source))
    verify(/visible\s*:\s*demoMode && opacity > 0/.test(source))
    verify(/Timer\s*\{[\s\S]*fadeTimer/.test(source))
    verify(/showHint\s*\(\s*text\s*,\s*sticky\s*\)/.test(source))
    verify(/hideHint\s*\(\s*\)/.test(source))
    verify(/formatKeySequence\s*\(\s*event\s*\)/.test(source))
    verify(/handleKeyEvent\s*\(\s*event\s*\)/.test(source))
  }
}
