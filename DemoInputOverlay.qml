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
    if (event.modifiers & Qt.MetaModifier) mods.push("SUPER")
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
    if (event.modifiers & Qt.AltModifier) mods.push("ALT")
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")

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
    else if (k === Qt.Key_Backspace) text = "BACKSPACE"
    else if (k === Qt.Key_Delete) text = "DELETE"
    else if (k === Qt.Key_Home) text = "HOME"
    else if (k === Qt.Key_End) text = "END"
    else if (k === Qt.Key_PageUp) text = "PAGE UP"
    else if (k === Qt.Key_PageDown) text = "PAGE DOWN"
    else if (k === Qt.Key_Comma || event.text === ",") text = ","
    else if (k === Qt.Key_Period || event.text === ".") text = "."
    else if (k === Qt.Key_Slash || event.text === "/") text = "/"
    else if (k === Qt.Key_Backslash || event.text === "\\") text = "\\"
    else if (k === Qt.Key_Minus || event.text === "-") text = "-"
    else if (k === Qt.Key_Equal || event.text === "=") text = "="
    else if (k === Qt.Key_Plus || event.text === "+") text = "+"
    else if (k === Qt.Key_Semicolon || event.text === ";") text = ";"
    else if (k === Qt.Key_Colon || event.text === ":") text = ":"
    else if (k === Qt.Key_Apostrophe || event.text === "'") text = "'"
    else if (k === Qt.Key_QuoteDbl || event.text === "\"") text = "\""
    else if (k === Qt.Key_BracketLeft || event.text === "[") text = "["
    else if (k === Qt.Key_BracketRight || event.text === "]") text = "]"
    else if (k === Qt.Key_BraceLeft || event.text === "{") text = "{"
    else if (k === Qt.Key_BraceRight || event.text === "}") text = "}"
    else if (k === Qt.Key_QuoteLeft || event.text === "`") text = "`"
    else if (k === Qt.Key_AsciiTilde || event.text === "~") text = "~"
    else if (k === Qt.Key_Question || event.text === "?") text = "?"
    else if (k === Qt.Key_Exclam || event.text === "!") text = "!"
    else if (k === Qt.Key_At || event.text === "@") text = "@"
    else if (k === Qt.Key_NumberSign || event.text === "#") text = "#"
    else if (k === Qt.Key_Dollar || event.text === "$") text = "$"
    else if (k === Qt.Key_Percent || event.text === "%") text = "%"
    else if (k === Qt.Key_AsciiCircum || event.text === "^") text = "^"
    else if (k === Qt.Key_Ampersand || event.text === "&") text = "&"
    else if (k === Qt.Key_Asterisk || event.text === "*") text = "*"
    else if (k === Qt.Key_ParenLeft || event.text === "(") text = "("
    else if (k === Qt.Key_ParenRight || event.text === ")") text = ")"
    else if (k === Qt.Key_Underscore || event.text === "_") text = "_"
    else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
      text = event.text.toUpperCase()
    } else if ((k >= Qt.Key_A && k <= Qt.Key_Z) || (k >= 97 && k <= 122)) {
      text = String.fromCharCode(k).toUpperCase()
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
    implicitWidth: Math.max(Style.space(48), label.implicitWidth + Style.space(32))
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
