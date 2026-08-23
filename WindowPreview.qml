import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  required property var toplevel

  readonly property var waylandToplevel: toplevel ? toplevel.wayland : null
  readonly property bool activatable: waylandToplevel !== null || (toplevel && String(toplevel.address || "") !== "")
  readonly property bool movable: toplevel !== null && String(toplevel.address || "") !== ""
  readonly property bool dragging: dragProxy.dragSessionActive
  readonly property string appId: waylandToplevel ? String(waylandToplevel.appId || "") : ""
  readonly property string title: toplevel ? String(toplevel.title || appId || "Window") : "Window"
  readonly property var desktopEntry: {
    if (!appId) return null
    return DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId)
  }
  readonly property string iconSource: {
    if (!desktopEntry || !desktopEntry.icon) return ""
    return Quickshell.iconPath(desktopEntry.icon, true)
  }
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
  readonly property bool showTitlePill: width >= Style.space(72)
    && height >= naturalPillHeight * 1.8

  property bool liveCaptureEnabled: false

  signal activated()
  signal dragStarted(var toplevel)
  signal dragFinished(var toplevel)

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
    clip: true

    ScreencopyView {
      id: preview
      anchors.centerIn: parent
      captureSource: root.waylandToplevel
      live: root.liveCaptureEnabled
      paintCursor: false
      width: {
        if (!hasContent || sourceSize.width <= 0 || sourceSize.height <= 0) return parent.width
        return Math.min(parent.width, parent.height * sourceSize.width / sourceSize.height)
      }
      height: {
        if (!hasContent || sourceSize.width <= 0 || sourceSize.height <= 0) return parent.height
        return Math.min(parent.height, parent.width * sourceSize.height / sourceSize.width)
      }
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

  // Interaction chrome is temporary: there is no permanent inner frame
  // competing with the workspace card's outer border.
  Rectangle {
    anchors.fill: parent
    z: 5
    color: "transparent"
    border.width: previewHover.hovered || root.dragging
      ? Math.max(1, Style.normalBorderWidth) : 0
    border.color: root.dragging ? Color.accent : Util.alpha(Color.menu.text, 0.58)
    radius: root.radius
  }

  // Compact, content-driven metadata floats over the screencopy and never
  // changes imageArea or spatial geometry. Plain visual children do not
  // intercept the root's tap/drag handlers.
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
