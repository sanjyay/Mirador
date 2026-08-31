import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "WindowGeometry.js" as WindowGeometry
import "WindowModel.js" as WindowModel

BorderSurface {
  id: root

  required property int workspaceId
  property var workspace: null
  property bool focused: false
  property bool keyboardSelected: false
  property var draggedToplevel: null
  property bool livePreviews: false
  property int toplevelRevision: 0

  readonly property var effectiveToplevels: {
    // `lastIpcObject` changes after refreshToplevels() completes. Reading this
    // revision makes that asynchronous, event-driven update invalidate the
    // effective array even though the ObjectModel membership did not change.
    var revision = root.toplevelRevision
    var activeAddr = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
    return WindowModel.resolveWorkspacePreviews(
      workspace ? workspace.toplevels.values : [], activeAddr)
  }
  readonly property var toplevelModel: effectiveToplevels
  readonly property int windowCount: effectiveToplevels.length
  readonly property bool occupied: windowCount > 0

  readonly property real previewSpacing: Math.max(1, Style.spacing.xs || 2)
  readonly property var workspaceMonitor: (workspace && workspace.monitor)
    ? workspace.monitor : Hyprland.focusedMonitor

  readonly property int draggedSourceWorkspaceId: draggedToplevel && draggedToplevel.workspace
    ? Number(draggedToplevel.workspace.id) : -1
  readonly property bool validDropTarget: draggedToplevel !== null
    && String(draggedToplevel.address || "") !== ""
    && workspaceId > 0
    && draggedSourceWorkspaceId !== workspaceId
  readonly property bool dropHovered: validDropTarget && dropArea.containsDrag

  readonly property bool cardHovered: cardMouseArea.containsMouse
  readonly property bool highlighted: (cardHovered || keyboardSelected) && !focused

  // ── Border widths ─────────────────────────────────────────────────────────
  readonly property int activeBorderWidth: Math.max(Style.space(2), Style.focusBorderWidth)
  readonly property int normalBorderWidth: Math.max(1, Style.normalBorderWidth)

  // ── Border spec ────────────────────────────────────────────────────────────
  // Priority (highest first):
  //   dropHovered          → thick accent ring  (drag target confirmed)
  //   validDropTarget      → thinner accent ring (drag affordance)
  //   focused              → strong accent ring (active workspace)
  //   highlighted          → clear neutral border (hover / keyboard selection)
  //   inactive             → visible defined outline (resting card)
  readonly property var cardBorderSpec: {
    if (dropHovered)
      return Border.withWidth(
        Border.flat(Color.accent, activeBorderWidth), activeBorderWidth)
    if (validDropTarget)
      return Border.withWidth(
        Border.flat(Util.alpha(Color.accent, 0.65), normalBorderWidth), normalBorderWidth)
    if (focused)
      return Border.flat(Color.accent, activeBorderWidth)
    if (highlighted)
      return Border.flat(Util.alpha(Color.menu.border, 0.75), normalBorderWidth)
    return Border.flat(Util.alpha(Color.menu.border, 0.45), normalBorderWidth)
  }

  signal workspaceActivated(bool occupied)
  signal windowActivated(var toplevel)
  signal windowDragStarted(var toplevel)
  signal windowDragFinished(var toplevel)
  signal windowDropped(var toplevel)

  Connections {
    target: Hyprland
    function onActiveToplevelChanged() { root.toplevelRevision++ }
  }

  // Track the completion of Quickshell's compositor-data refresh for existing
  // clients. This creates no visual delegate or capture for hidden members.
  Repeater {
    model: root.workspace ? root.workspace.toplevels : []

    Item {
      required property var modelData

      Connections {
        target: modelData
        function onLastIpcObjectChanged() { root.toplevelRevision++ }
      }
    }
  }

  function screenForMonitor(monitor) {
    if (!monitor) return null
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && screens[i].name === monitor.name) return screens[i]
    }
    return null
  }

  radius: Style.cornerRadius
  // Active and highlighted workspaces get full opaque background; resting gets near-opaque
  color: (root.focused || root.highlighted)
    ? Color.menu.background
    : (occupied ? Util.alpha(Color.menu.background, 0.96) : Util.alpha(Color.menu.background, 0.88))
  borderSpec: cardBorderSpec
  clip: true
  scale: root.highlighted ? 1.008 : 1.0

  Behavior on scale {
    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
  }

  // Full-card click & hover tracking — sits below all interactive children.
  MouseArea {
    id: cardMouseArea
    anchors.fill: parent
    z: 1
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.workspaceActivated(root.occupied)
  }

  // Drag/keyboard/active fill overlay — provides surface tint during drag,
  // hover elevation, keyboard navigation, or subtle active state sheen.
  Rectangle {
    anchors.fill: parent
    z: 2
    color: root.dropHovered
      ? Style.selectedFillFor(Color.menu.text, Color.accent)
      : (root.validDropTarget
        ? Style.hoverFillFor(Color.menu.text, Color.accent)
        : (root.focused
          ? Util.alpha(Color.accent, 0.05)
          : (root.highlighted
            ? Util.alpha(Color.menu.text, 0.05)
            : Util.alpha(Color.menu.text, 0.02))))

    Behavior on color {
      ColorAnimation { duration: 100 }
    }
  }

  // ── Workspace Header ───────────────────────────────────────────────────────
  // KDE-style top area with prominent number badge.
  Item {
    id: cardHeader
    z: 30
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.topMargin: Style.spacing.sm
    anchors.leftMargin: Style.spacing.md
    height: Math.max(Style.space(22), badgeLabel.implicitHeight + Style.spacing.xs * 2)

    // Number badge
    Rectangle {
      id: badge
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      height: cardHeader.height
      width: Math.max(height, badgeLabel.implicitWidth + Style.spacing.md * 2)
      radius: Math.min(Style.cornerRadius, Style.space(6))
      color: root.focused
        ? Color.accent
        : (root.highlighted
          ? Util.alpha(Color.menu.text, 0.16)
          : Util.alpha(Color.menu.text, 0.10))
      border.width: root.focused ? 0 : 1
      border.color: root.focused
        ? "transparent"
        : (root.highlighted
          ? Util.alpha(Color.menu.border, 0.60)
          : Util.alpha(Color.menu.border, 0.38))

      Behavior on color {
        ColorAnimation { duration: 100 }
      }

      Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.workspaceId === 10 ? "0" : String(root.workspaceId)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        font.bold: true
        color: root.focused ? Color.menu.scrim : Color.menu.text
        opacity: root.focused ? 1.0 : (root.highlighted ? 0.95 : 0.85)

        Behavior on opacity {
          NumberAnimation { duration: 100 }
        }
      }
    }
  }

  // ── Preview area ───────────────────────────────────────────────────────────
  Item {
    id: previewArea
    z: 5
    anchors.top: cardHeader.bottom
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: Style.spacing.xs
    anchors.bottomMargin: Style.spacing.sm
    anchors.leftMargin: Style.spacing.sm
    anchors.rightMargin: Style.spacing.sm

    // Empty hint: subtle centred dot.
    Text {
      visible: !root.occupied
      anchors.centerIn: parent
      text: "·"
      color: Color.menu.text
      opacity: root.focused ? 0.55 : (root.highlighted ? 0.40 : 0.25)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.displayLarge
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignHCenter
    }

    Item {
      id: spatialPreview
      anchors.fill: parent

      Repeater {
        model: root.toplevelModel

        WindowPreview {
          required property var modelData
          required property int index

          readonly property var previewToplevel: modelData && modelData.toplevel ? modelData.toplevel : modelData
          readonly property var previewIpc: (modelData && modelData.lastIpcObject)
            ? modelData.lastIpcObject
            : (previewToplevel ? previewToplevel.lastIpcObject : null)

          readonly property var targetMonitor: root.workspaceMonitor || (previewToplevel && previewToplevel.monitor ? previewToplevel.monitor : Hyprland.focusedMonitor)
          readonly property var targetScreen: root.screenForMonitor(targetMonitor)

          readonly property var previewGeometry: WindowGeometry.previewGeometry(
            previewIpc,
            targetMonitor,
            targetScreen,
            spatialPreview.width,
            spatialPreview.height,
            Math.min(spatialPreview.width, Math.max(Style.space(56), spatialPreview.width * 0.15)),
            Math.min(spatialPreview.height, Math.max(Style.space(40), spatialPreview.height * 0.20)))
          readonly property var displayGeometry: previewGeometry.valid
            ? previewGeometry
            : WindowGeometry.fallbackGeometry(index, root.windowCount,
              spatialPreview.width, spatialPreview.height, root.previewSpacing)

          x: displayGeometry.x
          y: displayGeometry.y
          width: Math.max(1, displayGeometry.width)
          height: Math.max(1, displayGeometry.height)
          z: index + 1
          toplevel: previewToplevel
          isGroup: Boolean(modelData && modelData.isGroup)
          groupMembers: (modelData && modelData.members) ? modelData.members : []
          liveCaptureEnabled: root.livePreviews && root.visible && previewArea.visible
          onActivated: root.windowActivated(previewToplevel)
          onTabActivated: function(targetToplevel) { root.windowActivated(targetToplevel) }
          onDragStarted: root.windowDragStarted(previewToplevel)
          onDragFinished: root.windowDragFinished(previewToplevel)
        }
      }
    }
  }

  DropArea {
    id: dropArea
    anchors.fill: parent
    z: 20
    keys: ["omarchy-window"]
    enabled: root.validDropTarget

    onDropped: function(drop) {
      if (!root.validDropTarget || !drop.source || !drop.source.toplevel) {
        drop.accepted = false
        return
      }
      drop.acceptProposedAction()
      root.windowDropped(drop.source.toplevel)
    }
  }
}
