import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "WindowGeometry.js" as WindowGeometry

BorderSurface {
  id: root

  required property int workspaceId
  property var workspace: null
  property bool focused: false
  property bool addWorkspace: false
  property bool keyboardSelected: false
  property var draggedToplevel: null
  property bool livePreviews: false

  readonly property var toplevelModel: workspace ? workspace.toplevels : []
  readonly property int windowCount: workspace ? workspace.toplevels.values.length : 0
  readonly property bool occupied: windowCount > 0

  readonly property real previewInset: Math.max(2,
    Math.min(4, Number(Style.spacing.xs) || 2))
  readonly property real previewSpacing: Math.max(1, Style.spacing.xs || 2)
  readonly property var previewCanvasGeometry: WindowGeometry.insetGeometry(
    width, height, previewInset)
  readonly property var workspaceMonitor: (workspace && workspace.monitor)
    ? workspace.monitor : Hyprland.focusedMonitor

  readonly property int draggedSourceWorkspaceId: draggedToplevel && draggedToplevel.workspace
    ? Number(draggedToplevel.workspace.id) : -1
  readonly property bool validDropTarget: draggedToplevel !== null
    && String(draggedToplevel.address || "") !== ""
    && workspaceId > 0 && workspaceId <= 10
    && draggedSourceWorkspaceId !== workspaceId
  readonly property bool dropHovered: validDropTarget && dropArea.containsDrag

  // ── Border widths ─────────────────────────────────────────────────────────
  // All states share the same 1-px physical width. The hierarchy is expressed
  // entirely through colour opacity, which is easier to reason about.
  // (Drop states keep a slightly thicker ring to clearly communicate drag.)
  readonly property int activeBorderWidth: Math.max(Style.space(2), Style.focusBorderWidth)
  readonly property int normalBorderWidth: Math.max(1, Style.normalBorderWidth)

  // ── Border spec ────────────────────────────────────────────────────────────
  // Priority (highest first):
  //   dropHovered          → thick accent ring  (drag target confirmed)
  //   validDropTarget      → thinner accent ring (drag affordance)
  //   focused              → accent ring         ← WINS over keyboardSelected
  //   focused+kbSelected   → accent ring (same)  ← no separate treatment needed
  //   keyboardSelected     → dim accent ring     (navigator cursor)
  //   occupied/inactive    → nearly invisible    (does not compete)
  //   empty/inactive       → fully invisible     (pure canvas)
  readonly property var cardBorderSpec: {
    if (dropHovered)
      return Border.withWidth(
        Border.flat(Color.accent, activeBorderWidth), activeBorderWidth)
    if (validDropTarget)
      return Border.withWidth(
        Border.flat(Util.alpha(Color.accent, 0.55), normalBorderWidth), normalBorderWidth)
    if (focused)
      // Accent at full opacity — the strongest signal in the overview.
      return Border.flat(Color.accent, activeBorderWidth)
    if (keyboardSelected)
      // Keyboard cursor: same accent colour but appreciably dimmer so that
      // the active workspace always reads as stronger.
      return Border.flat(Util.alpha(Color.accent, 0.45), normalBorderWidth)
    // Inactive (occupied or empty): border fades to near-invisible so active
    // card is the only one whose frame the eye perceives.
    return Border.flat(Util.alpha(Color.menu.border, 0.12), normalBorderWidth)
  }

  signal workspaceActivated()
  signal windowActivated(var toplevel)
  signal windowDragStarted(var toplevel)
  signal windowDragFinished(var toplevel)
  signal windowDropped(var toplevel)

  function screenForMonitor(monitor) {
    if (!monitor) return null
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && screens[i].name === monitor.name) return screens[i]
    }
    return null
  }

  radius: Style.cornerRadius
  // Keep backgrounds consistent — the border is the primary indicator.
  // Active workspace is fully opaque; others are slightly translucent.
  // Avoid a brightly filled background so the border does the work.
  color: occupied || focused
    ? Color.menu.background
    : Util.alpha(Color.menu.background, 0.72)
  borderSpec: cardBorderSpec
  clip: true

  // Full-card click — sits below all interactive children.
  MouseArea {
    anchors.fill: parent
    z: 1
    cursorShape: Qt.PointingHandCursor
    onClicked: root.workspaceActivated()
  }

  // Drag/keyboard fill overlay — provides a surface-level tint during drag
  // and keyboard navigation. Focused workspace does NOT get an extra fill;
  // the accent border alone is the active indicator.
  Rectangle {
    anchors.fill: parent
    z: 2
    color: root.dropHovered
      ? Style.selectedFillFor(Color.menu.text, Color.accent)
      : (root.validDropTarget || root.keyboardSelected
        ? Style.hoverFillFor(Color.menu.text, Color.accent)
        : "transparent")

    Behavior on color {
      ColorAnimation { duration: 80 }
    }
  }

  // ── Preview area ───────────────────────────────────────────────────────────
  Item {
    id: previewArea
    visible: !root.addWorkspace
    z: 5
    x: root.previewCanvasGeometry.x
    y: root.previewCanvasGeometry.y
    width: root.previewCanvasGeometry.width
    height: root.previewCanvasGeometry.height

    // Empty hint: barely-visible centred dot.
    Text {
      visible: !root.occupied
      anchors.centerIn: parent
      text: "·"
      color: Color.menu.text
      opacity: root.focused ? 0.50 : 0.22
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

          readonly property var previewGeometry: WindowGeometry.previewGeometry(
            modelData ? modelData.lastIpcObject : null,
            modelData && modelData.monitor ? modelData.monitor : root.workspaceMonitor,
            root.screenForMonitor(modelData && modelData.monitor
              ? modelData.monitor : root.workspaceMonitor),
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
          toplevel: modelData
          liveCaptureEnabled: root.livePreviews && root.visible && previewArea.visible
          onActivated: root.windowActivated(modelData)
          onDragStarted: root.windowDragStarted(modelData)
          onDragFinished: root.windowDragFinished(modelData)
        }
      }
    }

    // ── Workspace number badge ─────────────────────────────────────────────
    // Small overlay in the top-left. It consumes no preview geometry. The
    // number is always large and bold enough
    // to read at a glance. Active state: accent-filled pill with bright digit.
    // Inactive: dark translucent pill with readable digit.
    Rectangle {
      id: badge
      z: 30
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.topMargin: Style.spacing.xs
      anchors.leftMargin: Style.spacing.xs
      width: badgeLabel.implicitWidth + Style.spacing.md * 2
      height: badgeLabel.implicitHeight + Style.spacing.xs * 2
      radius: height / 2
      color: root.focused
        ? Color.accent
        : (root.keyboardSelected
          ? Util.alpha(Color.menu.text, 0.18)
          : Util.alpha(Color.menu.background, 0.72))

      Behavior on color {
        ColorAnimation { duration: 80 }
      }

      Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.workspaceId === 10 ? "0" : String(root.workspaceId)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        font.bold: true
        // On the accent pill use the overview scrim background as contrast;
        // otherwise use menu.text at varying opacity.
        color: root.focused ? Color.menu.scrim : Color.menu.text
        opacity: root.focused ? 1.0 : (root.occupied || root.keyboardSelected ? 0.90 : 0.55)

        Behavior on opacity {
          NumberAnimation { duration: 80 }
        }
      }
    }
  }

  // ── Add-workspace card ─────────────────────────────────────────────────────
  Text {
    visible: root.addWorkspace
    anchors.centerIn: parent
    z: 3
    text: "+"
    color: Color.menu.text
    opacity: root.dropHovered ? 1 : 0.58
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.displayLarge
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
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
