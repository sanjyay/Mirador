import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "WindowModel.js" as WindowModel

Rectangle {
  id: root

  required property var toplevel
  property Item visualParent: null
  property var physicsOverview: null
  property int hoveredTabIndex: -1
  property bool isGroup: false
  property var groupMembers: []

  readonly property var waylandToplevel: toplevel ? toplevel.wayland : null
  readonly property bool activatable: waylandToplevel !== null || (toplevel && String(toplevel.address || "") !== "")
  readonly property bool movable: toplevel !== null && String(toplevel.address || "") !== ""
  readonly property bool dragging: dragProxy.dragSessionActive
  readonly property string appId: root.appIdFor(toplevel)
  readonly property string title: root.titleFor(toplevel)
  readonly property string iconSource: root.iconFor(toplevel)

  readonly property real pillVerticalPadding: Math.max(2,
    Math.min(Style.spacing.xs, Style.spacing.controlPaddingY))
  readonly property real pillEdgeInset: Math.max(2, Style.spacing.xs)
  readonly property real pillIconSize: Math.min(Style.font.icon,
    Style.font.bodySmall * 1.25)
  readonly property real naturalPillHeight: Math.max(
    titleMetrics.height, iconSource !== "" ? pillIconSize : 0)
    + pillVerticalPadding * 2

  readonly property bool showGroupTabs: root.showLabel
    && root.isGroup
    && root.groupMembers
    && root.groupMembers.length > 1
    && width >= Style.space(60)
    && height >= naturalPillHeight * 1.8

  property bool liveCaptureEnabled: false
  property bool dragEnabled: true
  property bool closeEnabled: false
  property bool animatedAffordances: true
  property bool showLabel: true      // controls interactive grouped-window tabs
  property bool keyboardSelected: false
  property bool identityEnabled: false
  property bool showSelectionBorder: true
  property bool workspaceHighlighted: false

  signal closeRequested()
  signal activated()
  signal tabActivated(var targetToplevel)
  signal dragStarted(var toplevel)
  signal dragFinished(var toplevel)

  function appIdFor(top) {
    if (!top) return ""
    var wayland = top.wayland
    if (wayland && wayland.appId) return String(wayland.appId)
    var ipc = top.lastIpcObject
    if (ipc && ipc.initialClass) return String(ipc.initialClass)
    if (ipc && ipc.class) return String(ipc.class)
    return ""
  }

  function titleFor(top) {
    if (!top) return "Window"
    if (top.title) return String(top.title)
    var ipc = top.lastIpcObject
    if (ipc && ipc.title) return String(ipc.title)
    var id = appIdFor(top)
    return id || "Window"
  }

  function iconFor(top) {
    var id = appIdFor(top)
    if (!id) return ""
    var entry = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
    if (!entry || !entry.icon) return ""
    return Quickshell.iconPath(entry.icon, true)
  }

  function isSameToplevel(a, b) {
    if (!a || !b) return false
    if (a === b) return true
    var addrA = WindowModel.normalizedAddress((a && a.address) || (a.lastIpcObject && a.lastIpcObject.address))
    var addrB = WindowModel.normalizedAddress((b && b.address) || (b.lastIpcObject && b.lastIpcObject.address))
    return addrA !== "" && addrA === addrB
  }

  TextMetrics {
    id: titleMetrics
    text: root.title
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
  }

  property bool hasReceivedFrame: false

  Connections {
    target: preview
    function onHasContentChanged() {
      if (preview.hasContent) root.hasReceivedFrame = true
    }
  }

  onToplevelChanged: {
    root.hasReceivedFrame = false
  }

  onLiveCaptureEnabledChanged: {
    if (!root.liveCaptureEnabled) {
      root.hasReceivedFrame = false
    }
  }

  radius: Style.cornerRadius
  color: "transparent"
  clip: false

  Rectangle {
    id: visualSurface
    parent: root.visualParent || root
    x: root.visualParent ? root.x : 0
    y: root.visualParent ? root.y : 0
    width: root.width
    height: root.height
    z: root.z
    visible: root.visible
    radius: root.radius
    color: Util.alpha(Commons.Color.background, 0.52)
    clip: true
    opacity: root.dragging ? 0.58 : 1
    Behavior on opacity { enabled: root.animatedAffordances; NumberAnimation { duration: 60 } }
  }

  Item {
    id: imageArea
    parent: visualSurface
    anchors.fill: parent

    ScreencopyView {
      id: preview
      anchors.fill: parent
      captureSource: root.liveCaptureEnabled ? root.waylandToplevel : null
      live: root.liveCaptureEnabled
      paintCursor: false
      visible: hasContent || root.hasReceivedFrame
    }

    Image {
      visible: !root.hasReceivedFrame && !preview.hasContent && source !== ""
      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height) * 0.34
      height: width
      source: root.iconSource
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      opacity: 0.72
    }
  }

  // Interaction chrome
  Rectangle {
    parent: visualSurface
    anchors.fill: parent
    z: 5
    color: "transparent"
    border.width: root.keyboardSelected
      ? (root.showSelectionBorder ? Math.max(2, Style.normalBorderWidth * 2) : 0)
      : (root.workspaceHighlighted || previewHover.hovered || root.dragging ? Math.max(1, Style.normalBorderWidth) : 0)
    border.color: root.keyboardSelected || root.dragging
      ? Commons.Color.accent : Util.alpha(Commons.Color.menu.text, 0.58)
    radius: root.radius
  }

  Rectangle {
    id: identityBadge
    parent: visualSurface
    z: 15
    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: root.pillEdgeInset }
    width: Math.min(titleMetrics.width + (root.iconSource !== "" ? root.pillIconSize + Style.space(5) : 0) + Style.space(16), Math.max(1, parent.width - Style.space(12)))
    height: root.naturalPillHeight
    color: Commons.Color.menu.background
    visible: root.identityEnabled && !root.dragging
      && (previewHover.hovered || root.keyboardSelected)
      && root.width >= Style.space(80) && root.height >= height * 2
    Row {
      id: identityRow
      anchors { fill: parent; leftMargin: Style.space(8); rightMargin: Style.space(8) }
      spacing: Style.space(5)
      Image {
        id: identityIcon
        anchors.verticalCenter: parent.verticalCenter
        visible: root.iconSource !== ""
        width: visible ? root.pillIconSize : 0
        height: width
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(1, parent.width - (identityIcon.visible ? identityIcon.width + parent.spacing : 0))
        text: root.title
        textFormat: Text.PlainText
        color: Commons.Color.menu.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        maximumLineCount: 1
      }
    }
  }

  // ── Group Tab Strip ────────────────────────────────────────────────────────
  Rectangle {
    id: groupTabBar
    parent: visualSurface
    visible: root.showGroupTabs
    z: 10
    anchors.top: parent.top
    anchors.topMargin: root.pillEdgeInset
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(
      tabRow.implicitWidth + root.pillEdgeInset * 2,
      Math.max(1, root.width - root.pillEdgeInset * 2))
    height: root.naturalPillHeight + 2
    radius: Math.max(3, Style.cornerRadiusSmall || (height / 4))
    color: Util.alpha(Commons.Color.menu.background, 0.88)
    border.width: 1
    border.color: Util.alpha(Commons.Color.menu.border, 0.15)
    clip: true

    Row {
      id: tabRow
      anchors.fill: parent
      anchors.margins: 1
      spacing: 1

      Repeater {
        model: root.groupMembers

        Rectangle {
          required property var modelData
          required property int index

          readonly property bool isCurrentTab: root.isSameToplevel(modelData, root.toplevel)
          readonly property string tabTitle: root.titleFor(modelData)
          readonly property string tabIcon: root.iconFor(modelData)

          width: Math.max(1, Math.floor((tabRow.width - (root.groupMembers.length - 1) * tabRow.spacing) / Math.max(1, root.groupMembers.length)))
          height: parent.height
          radius: Math.max(2, (Style.cornerRadiusSmall || 4) - 1)
          color: isCurrentTab
            ? Util.alpha(Commons.Color.accent, 0.32)
            : (root.hoveredTabIndex === index ? Util.alpha(Commons.Color.menu.text, 0.08) : "transparent")

          border.width: isCurrentTab ? 1 : 0
          border.color: Util.alpha(Commons.Color.accent, 0.6)

          Row {
            anchors.centerIn: parent
            width: Math.min(parent.width - Style.spacing.xs * 2, implicitWidth)
            spacing: Style.spacing.xs

            Image {
              id: tabAppIcon
              visible: tabIcon !== ""
              anchors.verticalCenter: parent.verticalCenter
              width: visible ? root.pillIconSize : 0
              height: width
              source: tabIcon
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              smooth: true
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(1, parent.parent.width - Style.spacing.xs * 2
                - (tabAppIcon.visible ? tabAppIcon.width + parent.spacing : 0))
              text: tabTitle
              textFormat: Text.PlainText
              color: isCurrentTab ? Commons.Color.menu.text : Util.alpha(Commons.Color.menu.text, 0.72)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: isCurrentTab
              elide: Text.ElideRight
              maximumLineCount: 1
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }
    }
  }

  // Group tab input stays on the logical preview, even while its artwork moves.
  Row {
    x: groupTabBar.x + 1
    y: groupTabBar.y + 1
    width: groupTabBar.width - 2
    height: groupTabBar.height - 2
    spacing: 1
    clip: true
    visible: root.showGroupTabs
    z: 10
    Repeater {
      model: root.groupMembers
      Item {
        required property var modelData
        required property int index
        width: Math.max(1, Math.floor((parent.width - (root.groupMembers.length - 1)) / Math.max(1, root.groupMembers.length)))
        height: parent.height
        HoverHandler {
          cursorShape: Qt.PointingHandCursor
          onHoveredChanged: root.hoveredTabIndex = hovered ? index : -1
        }
        TapHandler {
          acceptedButtons: Qt.LeftButton
          onTapped: {
            if (!root.isSameToplevel(modelData, root.toplevel)) root.tabActivated(modelData)
            else root.activated()
          }
        }
      }
    }
  }

  Rectangle {
    id: closeButton
    z: 30
    anchors { top:parent.top; right:parent.right; margins:Style.space(6) }
    width:Style.space(32);height:width
    visible:root.closeEnabled && !root.dragging && (previewHover.hovered || root.keyboardSelected || closeMouse.containsMouse)
      && root.width>=Style.space(120) && root.height>=Style.space(70)
    color:closeMouse.containsMouse ? Commons.Color.accent : Commons.Color.background
    border.width:Style.normalBorderWidth;border.color:Commons.Color.foreground
    Text {
      anchors.centerIn:parent;text:"×";textFormat:Text.PlainText
      color:closeMouse.containsMouse ? Commons.Color.background : Commons.Color.foreground
      font.family:Style.font.family;font.pixelSize:Style.font.heading
    }
    Accessible.role:Accessible.Button
    Accessible.name:"Close "+root.title
    MouseArea {
      id:closeMouse
      anchors.fill:parent;hoverEnabled:true;preventStealing:true
      cursorShape:Qt.PointingHandCursor
      onClicked:root.closeRequested()
    }
  }
  function closeButtonContains(point) {
    return closeButton.visible && closeButton.contains(closeButton.mapFromItem(root,point.x,point.y))
  }
  HoverHandler {
    id: previewHover
    cursorShape: root.dragging ? Qt.ClosedHandCursor
      : (root.activatable || root.movable ? Qt.PointingHandCursor : Qt.ArrowCursor)
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    enabled: root.activatable
    onTapped: function(point) { if (!root.closeButtonContains(point.position)) root.activated() }
  }

  DragHandler {
    id: previewDrag
    acceptedButtons: Qt.LeftButton
    enabled: root.movable && root.dragEnabled && !root.closeButtonContains(centroid.pressPosition)
    target: null
    dragThreshold: Style.space(6)

    onCentroidChanged: {
      if (active && root.physicsOverview) {
        var p = root.mapToItem(root.physicsOverview.jiggleScene, centroid.position.x, centroid.position.y)
        root.physicsOverview.jiggleController.pointer(p.x, p.y, root.toplevel.address,
          root.toplevel.workspace ? root.toplevel.workspace.id : "")
      }
    }
    onActiveChanged: {
      if (active) {
        dragProxy.dragSessionActive = true
        root.dragStarted(root.toplevel)
      } else if (dragProxy.dragSessionActive) {
        dragProxy.Drag.drop()
        dragProxy.dragSessionActive = false
        root.dragFinished(root.toplevel)
      }
    }
  }

  Item {
    id: dragProxy
    property bool dragSessionActive: false
    property real lastX: 0
    property real lastY: 0

    x: previewDrag.active ? previewDrag.centroid.position.x : lastX
    y: previewDrag.active ? previewDrag.centroid.position.y : lastY
    width: 1
    height: 1
    onXChanged: if (previewDrag.active) lastX = x
    onYChanged: if (previewDrag.active) lastY = y
    Drag.active: dragSessionActive
    Drag.source: root
    Drag.keys: ["omarchy-window"]
    Drag.supportedActions: Qt.MoveAction
    Drag.proposedAction: Qt.MoveAction
  }
}
