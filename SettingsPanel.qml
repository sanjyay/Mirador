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
  readonly property var fields: [
    {key:"cycleUI", label:"Cycle presentation", choices:["full","carousel","compact"]},
    {key:"modifier", label:"Cycle modifier", choices:["super","alt","ctrl"]},
    {key:"backdropDim", label:"Backdrop dimming", choices:[0,0.25,0.5,0.75]},
    {key:"backdropBlur", label:"Blur wallpaper backdrop", choices:[false,true]},
    {key:"showWindowIdentity", label:"Window names and icons", choices:[false,true]},
    {key:"layoutDensity", label:"Preview spacing", choices:["compact","comfortable","airy"]},
    {key:"neighborEmphasis", label:"Carousel neighbors", choices:["quiet","normal","strong"]},
    {key:"showShortcutHints", label:"Shortcut footer", choices:[false,true]},
    {key:"reducedMotion", label:"Reduced motion", choices:[false,true]}
  ]
  function displayValue(field) {
    var value = draft[field.key]
    if (typeof value === "boolean") return value ? "On" : "Off"
    if (field.key === "backdropDim") return Math.round(value * 100) + "%"
    return String(value)
  }
  property string errorText: ""
  signal applyRequested(var settings)
  signal cancelled()
  onVisibleChanged: if (visible) {
    draft = SettingsModel.normalized(preferences)
    selectedRow = 0
    settingsScroll.contentY = 0
    forceActiveFocus()
  }
  onSelectedRowChanged: Qt.callLater(ensureRowVisible)
  function ensureRowVisible() {
    var row = fieldsRepeater.itemAt(selectedRow)
    if (!row) return
    var top = row.mapToItem(settingsScroll.contentItem, 0, 0).y
    if (top < settingsScroll.contentY) settingsScroll.contentY = top
    else if (top + row.height > settingsScroll.contentY + settingsScroll.height)
      settingsScroll.contentY = top + row.height - settingsScroll.height
  }
  function change(direction) {
    var updated = SettingsModel.normalized(draft)
    var field = fields[selectedRow]
    updated[field.key] = SettingsModel.next(updated[field.key], field.choices, direction)
    draft = updated
  }
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape || event.key === Qt.Key_F2) root.cancelled()
    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) selectedRow = (selectedRow + (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? fields.length - 1 : 1)) % fields.length
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
  Flickable {
    id: settingsScroll
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: content.implicitHeight + Style.space(40)
    boundsBehavior: Flickable.StopAtBounds
    Column {
    id: content
    x: Style.space(20)
    y: Style.space(20)
    width: Math.max(1, settingsScroll.width - Style.space(40))
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
      id: fieldsRepeater
      model: root.fields
      Button {
        required property var modelData
        required property int index
        width: content.width
        leftAlign: true
        hasCursor: root.selectedRow === index
        text: modelData.label + ": " + root.displayValue(modelData)
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
  }
  implicitHeight: content.implicitHeight + Style.space(40)
}
