import QtQuick
import qs.Commons
import qs.Commons as Commons
import "SpreadLayout.js" as SpreadLayout
import "WindowGeometry.js" as WindowGeometry
FocusScope {
  id: root
  required property var overview
  property var toplevel: null
  signal dismissed()
  signal activated()
  onVisibleChanged: if (visible) forceActiveFocus()
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape || event.text.toLowerCase() === "z") root.dismissed()
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (root.toplevel) root.activated() }
    else return
    event.accepted=true
  }
  Rectangle { anchors.fill: parent; color: Commons.Color.background; MouseArea { anchors.fill: parent; onClicked: root.dismissed() } }
  readonly property var arranged: SpreadLayout.layout(
    [WindowGeometry.clientGeometry(root.toplevel ? root.toplevel.lastIpcObject : null)],
    overview.gridViewport.width, Math.max(1,overview.gridViewport.height-Style.space(40)),0,overview.gridDpr).items[0]
  Text {
    x: overview.gridViewport.x; y: overview.gridViewport.y
    width: overview.gridViewport.width
    text: root.toplevel ? preview.title : "This window has closed"
    textFormat: Text.PlainText; elide: Text.ElideRight
    color: Commons.Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.heading
  }
  WindowPreview {
    id: preview
    x: overview.gridViewport.x+root.arranged.previewX
    y: overview.gridViewport.y+Style.space(40)+root.arranged.previewY
    width: root.arranged.previewWidth; height: root.arranged.previewHeight
    visible: root.toplevel !== null
    toplevel: root.toplevel
    dragEnabled: false
    liveCaptureEnabled: root.visible && overview.opened && overview.livePreviewsReady
    keyboardSelected: true
    animatedAffordances: overview.motionEnabled
    onActivated: root.activated()
  }
  Text {
    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Style.space(8) }
    text: "Enter / click Open window · Z / Escape Return"
    textFormat: Text.PlainText
    color: Commons.Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
  }
}
