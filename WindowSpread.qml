import QtQuick
import qs.Commons
import qs.Commons as Commons
import "SpreadLayout.js" as SpreadLayout
import "WindowGeometry.js" as WindowGeometry
import "WindowModel.js" as WindowModel

FocusScope {
  id: root
  required property var overview
  property var windows: []
  property string workspaceName: ""
  property int currentIndex: 0
  property string selectedAddress: ""
  signal activated(string address)
  signal dismissed()
  function topFor(entry) { return entry ? (entry.activeMember || entry.toplevel || entry) : null }
  function addressAt(index) { return WindowModel.toplevelAddress(topFor(windows[index])) }
  onWindowsChanged: {
    var next = 0
    for (var i=0;i<windows.length;i++) if (addressAt(i) === selectedAddress) next=i
    currentIndex=next
    selectedAddress=windows.length ? addressAt(currentIndex) : ""
  }
  onVisibleChanged: if (visible) { currentIndex=0; selectedAddress=windows.length ? addressAt(0) : ""; forceActiveFocus() }
  readonly property var rectangles: windows.map(function(entry) {
    var top = root.topFor(entry)
    return WindowGeometry.clientGeometry(top ? top.lastIpcObject : null)
  })
  readonly property var arranged: SpreadLayout.layout(rectangles, stage.width, stage.height, Style.space(24), overview.gridDpr)
  function move(dx,dy) {
    currentIndex=WindowGeometry.cyclicCardMove(arranged.items,currentIndex,dx,dy)
    selectedAddress=windows.length ? addressAt(currentIndex) : ""
  }
  Keys.onPressed: function(event) {
    if (overview.handleSwapKey(event,addressAt(currentIndex))) return
    if (event.key === Qt.Key_Escape || event.text === "v" || event.text === "V") root.dismissed()
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (windows.length) root.activated(addressAt(currentIndex))
    } else if (event.key === Qt.Key_Left || event.text === "h") move(-1,0)
    else if (event.key === Qt.Key_Right || event.text === "l") move(1,0)
    else if (event.key === Qt.Key_Up || event.text === "k") move(0,-1)
    else if (event.key === Qt.Key_Down || event.text === "j") move(0,1)
    else if (event.key === Qt.Key_Tab) { currentIndex=(currentIndex+1)%Math.max(1,windows.length); selectedAddress=addressAt(currentIndex) }
    else if (event.text.toLowerCase() === "z") overview.showQuickLook(addressAt(currentIndex))
    else if (event.key === Qt.Key_F1) overview.showHelp()
    else if (event.key === Qt.Key_F2) overview.showSettings()
    else if (event.text === "/") overview.showSearch()
    else return
    event.accepted=true
  }
  Rectangle { anchors.fill: parent; color: Commons.Color.background; MouseArea { anchors.fill: parent } }
  Text {
    x: overview.gridViewport.x
    y: overview.gridViewport.y
    width: overview.gridViewport.width
    text: "Workspace " + root.workspaceName + " · " + root.windows.length + " windows"
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: Commons.Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.heading
  }
  Item {
    id: stage
    x: overview.gridViewport.x
    y: overview.gridViewport.y + Style.space(40)
    width: overview.gridViewport.width
    height: Math.max(1,overview.gridViewport.height-Style.space(40))
    Repeater {
      model: root.windows
      Item {
        id: cell
        required property var modelData
        required property int index
        readonly property var geometry: root.arranged.items[index] || ({x:0,y:0,width:1,height:1,previewX:0,previewY:0,previewWidth:1,previewHeight:1,labelHeight:0})
        readonly property var previewToplevel: root.topFor(modelData)
        x: geometry.x; y: geometry.y
        width: geometry.width; height: geometry.height
        Rectangle {
          anchors.fill: parent
          color: "transparent"
          border.width: root.currentIndex === cell.index ? Math.max(1,Style.focusBorderWidth) : 0
          border.color: Commons.Color.accent
        }
        WindowPreview {
          id: windowPreview
          x: cell.geometry.previewX; y: cell.geometry.previewY
          width: cell.geometry.previewWidth; height: cell.geometry.previewHeight
          toplevel: cell.previewToplevel
          closeEnabled: overview.preferences.showCloseControls
          onCloseRequested: overview.requestPreviewClose(cell.previewToplevel)
          dragEnabled: false
          liveCaptureEnabled: root.visible && overview.opened && overview.livePreviewsReady && !overview.quickLookAddress
          keyboardSelected: root.currentIndex === cell.index
          showSelectionBorder: false
          animatedAffordances: overview.motionEnabled
          isGroup: Boolean(cell.modelData && cell.modelData.isGroup)
          groupMembers: cell.modelData && cell.modelData.members ? cell.modelData.members : []
          onActivated: root.activated(root.addressAt(cell.index))
          onTabActivated: function(top) { root.activated(WindowModel.toplevelAddress(top)) }
        }
        Text {
          anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
          width: Math.max(1,parent.width-Style.space(8))
          visible: cell.geometry.labelHeight >= implicitHeight
          text: windowPreview.title
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
        }
        MouseArea {
          anchors.fill: parent
          z: -1
          hoverEnabled: true
          onEntered: { root.currentIndex=cell.index; root.selectedAddress=root.addressAt(cell.index) }
          onClicked: root.activated(root.addressAt(cell.index))
        }
      }
    }
    Text {
      anchors.centerIn: parent
      visible: root.windows.length === 0
      text: "This workspace has no windows"
      textFormat: Text.PlainText
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }
}
