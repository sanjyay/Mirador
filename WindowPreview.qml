import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "WindowModel.js" as WindowModel

Rectangle {
  id: root

  required property var toplevel
  property bool isGroup: false
  property var groupMembers: []

  readonly property var waylandToplevel: toplevel ? toplevel.wayland : null
  readonly property bool activatable: waylandToplevel !== null || (toplevel && String(toplevel.address || "") !== "")
  readonly property bool movable: toplevel !== null && String(toplevel.address || "") !== ""
  readonly property bool dragging: dragProxy.dragSessionActive
  readonly property string appId: root.appIdFor(toplevel)
  readonly property string title: root.titleFor(toplevel)
  readonly property string iconSource: root.iconFor(toplevel)

  readonly property real pillHorizontalPadding: Math.max(Style.spacing.sm,
    Style.spacing.controlPaddingX)
  readonly property real pillVerticalPadding: Math.max(2,
    Math.min(Style.spacing.xs, Style.spacing.controlPaddingY))
  readonly property real pillEdgeInset: Math.max(2, Style.spacing.xs)
  readonly property real pillIconSize: Math.min(Style.font.icon,
    Style.font.bodySmall * 1.25)
  readonly property real naturalPillHeight: Math.max(
    titleMetrics.height, iconSource !== "" ? pillIconSize : 0)
    + pillVerticalPadding * 2

  readonly property bool showGroupTabs: root.isGroup
    && root.groupMembers
    && root.groupMembers.length > 1
    && width >= Style.space(60)
    && height >= naturalPillHeight * 1.8
  readonly property bool showTitlePill: !root.showGroupTabs
    && width >= Style.space(72)
    && height >= naturalPillHeight * 1.8

  property bool liveCaptureEnabled: false

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

  radius: Style.cornerRadius
  color: Util.alpha(Color.background, 0.52)
  clip: true
  opacity: dragging ? 0.58 : 1

  Behavior on opacity {
    NumberAnimation { duration: 60 }
  }

  Item {
    id: imageArea
    anchors.fill: parent

    ScreencopyView {
      id: preview
      anchors.fill: parent
      captureSource: root.liveCaptureEnabled ? root.waylandToplevel : null
      live: root.liveCaptureEnabled
      paintCursor: false
      visible: hasContent
    }

    Image {
      visible: !preview.hasContent && source !== ""
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
    anchors.fill: parent
    z: 5
    color: "transparent"
    border.width: previewHover.hovered || root.dragging
      ? Math.max(1, Style.normalBorderWidth) : 0
    border.color: root.dragging ? Color.accent : Util.alpha(Color.menu.text, 0.58)
    radius: root.radius
  }

  // ── Group Tab Strip ────────────────────────────────────────────────────────
  Rectangle {
    id: groupTabBar
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
    color: Util.alpha(Color.menu.background, 0.88)
    border.width: 1
    border.color: Util.alpha(Color.menu.border, 0.15)
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
            ? Util.alpha(Color.accent, 0.32)
            : (tabHover.hovered ? Util.alpha(Color.menu.text, 0.08) : "transparent")

          border.width: isCurrentTab ? 1 : 0
          border.color: Util.alpha(Color.accent, 0.6)

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
              color: isCurrentTab ? Color.menu.text : Util.alpha(Color.menu.text, 0.72)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: isCurrentTab
              elide: Text.ElideRight
              maximumLineCount: 1
              verticalAlignment: Text.AlignVCenter
            }
          }

          HoverHandler {
            id: tabHover
            cursorShape: Qt.PointingHandCursor
          }

          TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
              if (!isCurrentTab) {
                root.tabActivated(modelData)
              } else {
                root.activated()
              }
            }
          }
        }
      }
    }
  }

  // ── Single Window Title Pill ───────────────────────────────────────────────
  Rectangle {
    id: titlePill
    visible: root.showTitlePill
    z: 10
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.pillEdgeInset
    width: Math.min(
      titleMetrics.width + root.pillHorizontalPadding * 2
        + (root.iconSource !== "" ? root.pillIconSize + Style.spacing.xs : 0),
      Math.max(1, root.width * 0.72),
      Math.max(1, root.width - root.pillEdgeInset * 2))
    height: root.naturalPillHeight
    radius: height / 2
    color: Util.alpha(Color.menu.background, 0.86)

    Row {
      id: titleContent
      anchors.fill: parent
      anchors.leftMargin: root.pillHorizontalPadding
      anchors.rightMargin: root.pillHorizontalPadding
      spacing: Style.spacing.xs

      Image {
        id: appIcon
        visible: source !== ""
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? root.pillIconSize : 0
        height: width
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(1, parent.width
          - (appIcon.visible ? appIcon.width + parent.spacing : 0))
        text: root.title
        textFormat: Text.PlainText
        color: Color.menu.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        maximumLineCount: 1
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  HoverHandler {
    id: previewHover
    cursorShape: root.dragging ? Qt.ClosedHandCursor
      : (root.activatable || root.movable ? Qt.PointingHandCursor : Qt.ArrowCursor)
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    enabled: root.activatable
    onTapped: root.activated()
  }

  DragHandler {
    id: previewDrag
    acceptedButtons: Qt.LeftButton
    enabled: root.movable
    target: null
    dragThreshold: Style.space(6)

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
