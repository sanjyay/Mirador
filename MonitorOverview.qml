import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import "MonitorModel.js" as MonitorModel
import "WindowGeometry.js" as WindowGeometry
PanelWindow {
  id: root
  required property var overview
  required property var modelData
  screen: modelData
  visible: overview.opened && overview.preferences.allMonitors && modelData !== null
  anchors { top:true; bottom:true; left:true; right:true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omarchy-workspace-overview-secondary"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  readonly property var monitor: {
    var values=Hyprland.monitors ? Hyprland.monitors.values : []
    for (var i=0;i<values.length;i++) if (values[i].name===root.modelData.name) return values[i]
    return null
  }
  readonly property var workspaces: {
    var values=Hyprland.workspaces ? Hyprland.workspaces.values : []
    return values.filter(function(ws) { return !overview.isSpecialWorkspace(ws) && MonitorModel.belongs(ws,root.monitor) }).sort(function(a,b){return a.id-b.id})
  }
  readonly property real dpr: modelData ? modelData.devicePixelRatio : 1
  readonly property var reserved: monitor && monitor.lastIpcObject ? monitor.lastIpcObject.reserved : []
  readonly property var safe: WindowGeometry.safeAreaGeometry(width,height,"top",0,Style.space(40),reserved)
  readonly property var viewport: WindowGeometry.snapRectToDevicePixels({x:safe.usableX,y:safe.usableY,width:safe.usableWidth,height:safe.usableHeight},dpr,true)
  readonly property var layout: WindowGeometry.overviewMonitorGridGeometry(
    workspaces.map(function(){return WindowGeometry.workspaceAspectRatio(root.monitor,root.modelData)}),
    workspaces.map(function(){return root.modelData.name}),viewport.width,Math.max(1,viewport.height-Style.space(36)),Style.space(20),4)
  OverviewBackdrop { anchors.fill:parent; dimming:overview.preferences.backdropDim; blurWallpaper:overview.preferences.backdropBlur }
  MouseArea { anchors.fill:parent; onClicked:overview.dismiss() }
  Text {
    x:root.viewport.x;y:root.viewport.y;width:root.viewport.width
    text:root.modelData.name+" · Click a window or workspace"
    textFormat:Text.PlainText;color:Commons.Color.foreground
    font.family:Style.font.family;font.pixelSize:Style.font.body
  }
  MonitorDropTargets {
    z:195
    overview:root.overview
    x:root.viewport.x;y:root.viewport.y+root.viewport.height-height;width:root.viewport.width
  }
  Item {
    x:root.viewport.x;y:root.viewport.y+Style.space(36)
    width:root.viewport.width;height:Math.max(1,root.viewport.height-Style.space(36))
    Repeater {
      model:root.workspaces
      WorkspaceCard {
        required property var modelData
        required property int index
        readonly property var cell: root.layout.cards[index] || ({x:0,y:0,width:1,height:1})
        x:WindowGeometry.snapToDevicePixels(cell.x,root.dpr);y:WindowGeometry.snapToDevicePixels(cell.y,root.dpr)
        width:WindowGeometry.snapToDevicePixels(cell.width,root.dpr);height:WindowGeometry.snapToDevicePixels(cell.height,root.dpr)
        workspaceId:modelData.id;workspace:modelData;overview:root.overview
        physicsEnabled:false
        overlayBadge:true
        focused:root.monitor && root.monitor.activeWorkspace && root.monitor.activeWorkspace.id===modelData.id
        livePreviews:root.visible && root.overview.livePreviewsReady
        draggedToplevel:root.overview.draggedToplevel
        onWorkspaceActivated:function(occupied){root.overview.activateWorkspace(workspace,workspaceId,occupied)}
        onWindowActivated:function(top){root.overview.activateWindow(top)}
        onWindowDragStarted:function(top){root.overview.beginWindowDrag(top)}
        onWindowDragFinished:function(top){root.overview.endWindowDrag(top)}
        onWindowDropped:function(top){root.overview.moveWindowToWorkspace(top,workspaceId)}
      }
    }
  }
}
