import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool demoMode: false
  property string currentText: ""
  property bool isSticky: false

  visible: demoMode && opacity > 0
  opacity: 0.0

  implicitWidth: container.implicitWidth
  implicitHeight: container.implicitHeight

  // Non-interactive HUD: never consume mouse / pointer clicks or focus
  focus: false

  Behavior on opacity {
    NumberAnimation { duration: root.opacity > 0 ? 80 : 200; easing.type: Easing.OutQuad }
  }

  Timer {
    id: fadeTimer
    interval: 850
    repeat: false
    onTriggered: {
      if (!root.isSticky) {
        root.opacity = 0.0
      }
    }
  }

  function showHint(text, sticky) {
    if (!root.demoMode || !text) return
    root.currentText = String(text)
    root.isSticky = Boolean(sticky)
    root.opacity = 1.0
    fadeTimer.restart()
  }

  function hideHint() {
    root.isSticky = false
    root.opacity = 0.0
    fadeTimer.stop()
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

    // Ignore modifier-only key presses
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

  function handleKeyEvent(event) {
    if (!root.demoMode) return
    var formatted = formatKeySequence(event)
    if (formatted) {
      showHint(formatted, false)
    }
  }

  Rectangle {
    id: container
    anchors.centerIn: parent
    implicitWidth: label.implicitWidth + Style.space(32)
    implicitHeight: Math.max(Style.space(36), label.implicitHeight + Style.space(16))
    radius: Math.min(Style.cornerRadius, Style.space(8))
    color: Util.alpha(Color.menu.background, 0.92)
    border.width: Math.max(1, Style.normalBorderWidth)
    border.color: Util.alpha(Color.menu.text, 0.22)

    Text {
      id: label
      anchors.centerIn: parent
      text: root.currentText
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      font.bold: true
      color: Color.menu.text
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }
}
