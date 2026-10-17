import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

FocusScope {
  id: root
  property var shortcuts: []
  signal dismissed()
  onVisibleChanged: if (visible) { scroll.contentY = 0; forceActiveFocus() }
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape || event.key === Qt.Key_F1) root.dismissed()
    else if (event.key === Qt.Key_Down) scroll.contentY = Math.min(Math.max(0, scroll.contentHeight - scroll.height), scroll.contentY + Style.space(40))
    else if (event.key === Qt.Key_Up) scroll.contentY = Math.max(0, scroll.contentY - Style.space(40))
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
    id: scroll
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: content.implicitHeight + Style.space(40)
    boundsBehavior: Flickable.StopAtBounds
    Column {
      id: content
      x: Style.space(20); y: Style.space(20)
      width: Math.max(1, scroll.width - Style.space(40))
      spacing: Style.space(14)
      Text {
        text: "Mirador shortcuts"
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
      }
      Repeater {
        model: root.shortcuts
        Column {
          required property var modelData
          width: content.width
          spacing: Style.space(3)
          Text {
            width: parent.width
            text: modelData.key
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Commons.Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
          Text {
            width: parent.width
            text: modelData.action
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }
      Button { text: "Close · Esc"; onClicked: root.dismissed() }
    }
  }
  implicitHeight: content.implicitHeight + Style.space(40)
}
