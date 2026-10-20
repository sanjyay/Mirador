import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "SettingsModel.js" as SettingsModel

FocusScope {
  id: root
  property var preferences: ({})
  property var draft: SettingsModel.normalized({})
  property int selectedRow: 0
  property bool busy: false
  property int armedKey: 0
  property int armedRow: -1
  readonly property int saveRow: fields.length
  readonly property int cancelRow: fields.length + 1
  readonly property int controlCount: fields.length + 2
  readonly property var fields: [
    {key:"backdropDim", label:"Backdrop dimming", choices:[0,0.25,0.5,0.75,1]},
    {key:"backdropBlur", label:"Wallpaper Background", choices:[false,true]}
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
  onVisibleChanged: {
    armedKey = 0
    armedRow = -1
    if (!visible) return
    draft = SettingsModel.normalized(preferences)
    selectedRow = 0
    forceActiveFocus()
    settingsScroll.contentY = 0
  }
  onBusyChanged: if (!busy && visible) forceActiveFocus()
  onErrorTextChanged: Qt.callLater(ensureSelectedVisible)
  onSelectedRowChanged: Qt.callLater(ensureSelectedVisible)
  onHeightChanged: Qt.callLater(ensureSelectedVisible)
  function select(row) {
    selectedRow = ((row % controlCount) + controlCount) % controlCount
    forceActiveFocus()
  }
  function ensureSelectedVisible() {
    var item = selectedRow < fields.length ? fieldsRepeater.itemAt(selectedRow) : actionButtons
    if (!item) return
    var top = item.mapToItem(settingsScroll.contentItem, 0, 0).y
    var target = settingsScroll.contentY
    if (top < target) target = top
    else if (top + item.height > target + settingsScroll.height)
      target = top + item.height - settingsScroll.height
    settingsScroll.contentY = Math.max(0, Math.min(target, Math.max(0, settingsScroll.contentHeight - settingsScroll.height)))
  }
  function activate() {
    if (busy) return
    if (selectedRow === saveRow) root.applyRequested(SettingsModel.normalized(draft))
    else if (selectedRow === cancelRow) root.cancelled()
    else change(1)
  }
  function change(direction) {
    if (busy || selectedRow < 0 || selectedRow >= fields.length) return
    var updated = SettingsModel.normalized(draft)
    var field = fields[selectedRow]
    updated[field.key] = SettingsModel.next(updated[field.key], field.choices, direction)
    draft = updated
  }
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    // Keep input inside the dialog, including while an atomic save is pending.
    event.accepted = true
    if (busy || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) return
    if (event.key === Qt.Key_Escape || event.key === Qt.Key_F2
        || event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (!event.isAutoRepeat) { armedKey = event.key; armedRow = selectedRow }
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
      select(selectedRow + (event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1))
    else if (event.key === Qt.Key_Up) select(selectedRow - 1)
    else if (event.key === Qt.Key_Down) select(selectedRow + 1)
    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
      var direction = event.key === Qt.Key_Left ? -1 : 1
      if (selectedRow < fields.length) change(direction)
      else select(selectedRow === saveRow ? cancelRow : saveRow)
    }
  }
  Keys.onReleased: function(event) {
    event.accepted = true
    if (event.isAutoRepeat || event.key !== armedKey) return
    var row = armedRow
    armedKey = 0
    armedRow = -1
    if (busy || row !== selectedRow || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) return
    // Close on release so holding Enter/Escape cannot repeat into the overview.
    if (event.key === Qt.Key_Escape || event.key === Qt.Key_F2) root.cancelled()
    else activate()
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
    objectName: "settingsScroll"
    anchors.fill: parent
    contentWidth: width
    contentHeight: content.implicitHeight + Style.space(40)
    clip: true
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
      Repeater {
        id: fieldsRepeater
        model: root.fields
        Button {
          required property var modelData
          required property int index
          width: content.width
          enabled: !root.busy
          leftAlign: true
          hasCursor: root.selectedRow === index
          text: modelData.label + ": " + root.displayValue(modelData)
          onClicked: { root.select(index); root.change(1) }
        }
      }
      Text {
        width: parent.width
        visible: root.errorText !== ""
        text: root.errorText
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Row {
        id: actionButtons
        objectName: "settingsActions"
        width: content.width
        spacing: Style.space(10)
        Button {
          width: Math.max(1, (parent.width - parent.spacing) / 2)
          enabled: !root.busy
          text: root.busy ? "Saving…" : "Save"
          hasCursor: root.selectedRow === root.saveRow
          onClicked: { root.select(root.saveRow); root.activate() }
        }
        Button {
          width: Math.max(1, (parent.width - parent.spacing) / 2)
          enabled: !root.busy
          text: "Cancel"
          hasCursor: root.selectedRow === root.cancelRow
          onClicked: { root.select(root.cancelRow); root.activate() }
        }
      }
    }
  }
  implicitHeight: content.implicitHeight + Style.space(40)
}
