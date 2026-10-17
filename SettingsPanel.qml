import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "SettingsModel.js" as SettingsModel

FocusScope {
  id: root
  property var preferences: ({})
  property var draft: SettingsModel.normalized(preferences)
  property int selectedRow: 0
  property string errorText: ""
  signal applyRequested(var settings)
  signal cancelled()
  onVisibleChanged: if (visible) {
    draft = SettingsModel.normalized(preferences)
    selectedRow = 0
    forceActiveFocus()
  }
  function change(direction) {
    var updated = SettingsModel.normalized(draft)
    if (selectedRow === 0)
      updated.cycleUI = SettingsModel.next(updated.cycleUI, ["full", "carousel", "compact"], direction)
    else
      updated.modifier = SettingsModel.next(updated.modifier, ["super", "alt", "ctrl"], direction)
    draft = updated
  }
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape || event.key === Qt.Key_F2) root.cancelled()
    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) selectedRow = 1 - selectedRow
    else if (event.key === Qt.Key_Left) change(-1)
    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Space) change(1)
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.applyRequested(draft)
    else return
    event.accepted = true
  }
  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background
    border.width: Math.max(1, Style.normalBorderWidth)
    border.color: Commons.Color.menu.border
    MouseArea { anchors.fill: parent }
  }
  Column {
    id: content
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space(20) }
    spacing: Style.space(14)
    Text {
      text: "Mirador settings"
      textFormat: Text.PlainText
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
    }
    Text {
      width: parent.width
      text: "Cycle preferences apply when the opening shortcut does not specify an override."
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    Repeater {
      model: ["Cycle presentation", "Cycle modifier"]
      Button {
        required property string modelData
        required property int index
        width: content.width
        leftAlign: true
        hasCursor: root.selectedRow === index
        text: modelData + ": " + (index === 0 ? root.draft.cycleUI : root.draft.modifier)
        onClicked: { root.selectedRow = index; root.change(1) }
      }
    }
    Text {
      width: parent.width
      text: root.errorText || "↑ ↓ Select   ← → Change   Enter Save   Esc Cancel"
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    Row {
      spacing: Style.space(10)
      Button { text: "Save"; onClicked: root.applyRequested(root.draft) }
      Button { text: "Cancel"; onClicked: root.cancelled() }
    }
  }
  implicitHeight: content.implicitHeight + Style.space(40)
}
