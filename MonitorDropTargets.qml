import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
Item {
  id:root
  required property var overview
  readonly property var monitors: Hyprland.monitors ? Hyprland.monitors.values : []
  visible: overview.opened && overview.draggedToplevel !== null && monitors.length>1
  height:Style.space(54)
  Row {
    anchors.fill:parent;spacing:Style.space(8)
    Repeater {
      model:root.monitors
      Rectangle {
        id:target
        required property var modelData
        width:Math.max(1,(root.width-Style.space(8)*(root.monitors.length-1))/Math.max(1,root.monitors.length))
        height:root.height
        color:drop.containsDrag ? Commons.Color.accent : Commons.Color.background
        border.width:Style.normalBorderWidth;border.color:Commons.Color.accent
        Text {
          anchors { fill:parent;margins:Style.space(8) }
          text:"Move to "+target.modelData.name+" · workspace "+(target.modelData.activeWorkspace ? target.modelData.activeWorkspace.name : "?")
          textFormat:Text.PlainText;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter
          color:drop.containsDrag ? Commons.Color.background : Commons.Color.foreground
          font.family:Style.font.family;font.pixelSize:Style.font.body
        }
        DropArea {
          id:drop;anchors.fill:parent;keys:["omarchy-window"]
          onDropped:function(event) {
            if (!event.source || !event.source.toplevel) {event.accepted=false;return}
            if (root.overview.moveWindowToMonitor(event.source.toplevel,target.modelData.name)) event.acceptProposedAction()
            else event.accepted=false
          }
        }
      }
    }
  }
}
