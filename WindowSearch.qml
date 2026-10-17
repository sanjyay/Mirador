import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "SearchModel.js" as SearchModel

FocusScope {
  id: root
  property var entries: []
  property string query: ""
  property string selectedAddress: ""
  property int currentIndex: 0
  readonly property var results: SearchModel.filter(entries, query)
  signal activated(string address)
  signal dismissed()
  onVisibleChanged: if (visible) {
    searchInput.text = ""
    root.query = ""
    root.selectedAddress = ""
    root.currentIndex = 0
    searchInput.forceActiveFocus()
  }
  onResultsChanged: {
    currentIndex = SearchModel.selectionIndex(results, selectedAddress)
    selectedAddress = results.length ? results[currentIndex].address : ""
  }
  function moveSelection(direction) {
    if (!results.length) return
    currentIndex = (currentIndex + direction + results.length) % results.length
    selectedAddress = results[currentIndex].address
    resultList.positionViewAtIndex(currentIndex, ListView.Contain)
  }
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) root.dismissed()
    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) root.moveSelection(1)
    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) root.moveSelection(-1)
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (results.length) root.activated(results[currentIndex].address)
    } else return
    event.accepted = true
  }
  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background
    border.width: Math.max(1, Style.normalBorderWidth)
    border.color: Commons.Color.menu.border
    MouseArea { anchors.fill: parent }
  }
  ColumnLayout {
    anchors { fill: parent; margins: Style.space(20) }
    spacing: Style.space(12)
    Text {
      Layout.fillWidth: true
      text: "Search open windows"
      textFormat: Text.PlainText
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
    }
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: Style.space(40)
      color: Commons.Color.menu.background
      border.width: 1
      border.color: Commons.Color.accent
      TextInput {
        id: searchInput
        anchors { fill: parent; margins: Style.space(10) }
        color: Commons.Color.foreground
        selectionColor: Commons.Color.accent
        selectedTextColor: Commons.Color.menu.scrim
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        maximumLength: 256
        clip: true
        Accessible.name: "Application name or window title"
        onTextChanged: { root.selectedAddress = ""; root.query = text }
        Text {
          anchors.fill: parent
          visible: searchInput.text.length === 0
          text: "Application name or window title…"
          textFormat: Text.PlainText
          color: Commons.Color.menu.text
          opacity: 0.65
          font: searchInput.font
        }
      }
    }
    ListView {
      id: resultList
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      model: root.results
      spacing: Style.space(4)
      boundsBehavior: Flickable.StopAtBounds
      delegate: Rectangle {
        required property var modelData
        required property int index
        width: resultList.width
        height: Style.space(56)
        color: index === root.currentIndex ? Style.selectedFillFor(Commons.Color.menu.text, Commons.Color.accent) : "transparent"
        border.width: index === root.currentIndex ? 1 : 0
        border.color: Commons.Color.accent
        Column {
          anchors { fill: parent; margins: Style.space(8) }
          spacing: Style.space(3)
          Text {
            width: parent.width
            text: modelData.title
            textFormat: Text.PlainText
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: modelData.app + (modelData.workspace ? " · Workspace " + modelData.workspace : "")
            textFormat: Text.PlainText
            color: Commons.Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: { root.currentIndex = index; root.selectedAddress = modelData.address }
          onClicked: root.activated(modelData.address)
        }
      }
      Text {
        anchors.centerIn: parent
        visible: root.results.length === 0
        text: "No matching windows"
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }
    Text {
      Layout.fillWidth: true
      text: root.results.length + (root.results.length === 1 ? " result" : " results") + " · ↑ ↓ Select · Enter Open · Esc Cancel"
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Commons.Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }
  implicitHeight: Style.space(140) + Math.min(8, Math.max(1, results.length)) * Style.space(60)
}
