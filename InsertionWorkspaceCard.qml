import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  required property int targetWorkspaceId
  property var draggedToplevel: null
  property var overview: null

  onDropHoveredChanged: {
    if (dropHovered && root.draggedToplevel && overview) {
      overview.showDemoHint("DRAG → NEW WS " + root.targetWorkspaceId, true)
    }
  }

  readonly property bool dropHovered: dropArea.containsDrag
  readonly property int activeBorderWidth: Math.max(Style.space(2), Style.focusBorderWidth)
  readonly property int normalBorderWidth: Math.max(1, Style.normalBorderWidth)
  readonly property int cardBorderWidth: root.dropHovered ? activeBorderWidth : normalBorderWidth
  readonly property color cardBorderColor: root.dropHovered ? Color.accent : Util.alpha(Color.accent, 0.38)
  readonly property string displayLabel: targetWorkspaceId === 10 ? "0" : String(targetWorkspaceId)

  radius: Style.cornerRadius

  // Resting state: soft translucent card surface.
  // Hovered state: active accent hover tint.
  color: dropHovered
    ? Style.hoverFillFor(Color.menu.text, Color.accent)
    : Util.alpha(Color.menu.background, 0.70)

  borderSpec: Border.none()

  clip: true
  scale: dropHovered ? 1.012 : 1.0

  Behavior on scale {
    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
  }

  Behavior on color {
    ColorAnimation { duration: 100 }
  }

  signal windowDropped(var toplevel)

  // Subtle interior fill tint that deepens when hovered
  Rectangle {
    anchors.fill: parent
    z: 2
    color: root.dropHovered
      ? Style.selectedFillFor(Color.menu.text, Color.accent)
      : Util.alpha(Color.accent, 0.03)

    Behavior on color {
      ColorAnimation { duration: 100 }
    }
  }

  // ── Workspace Header ───────────────────────────────────────────────────────
  // Matches the KDE-style top area with prominent number badge in WorkspaceCard.
  Item {
    id: cardHeader
    z: 30
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.topMargin: Style.spacing.sm
    anchors.leftMargin: Style.spacing.md
    height: Math.max(Style.space(22), badgeLabel.implicitHeight + Style.spacing.xs * 2)

    Rectangle {
      id: badge
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      height: cardHeader.height
      width: Math.max(height, badgeLabel.implicitWidth + Style.spacing.md * 2)
      radius: Math.min(Style.cornerRadius, Style.space(6))
      color: root.dropHovered
        ? Color.accent
        : Util.alpha(Color.accent, 0.16)
      border.width: root.dropHovered ? 0 : 1
      border.color: root.dropHovered
        ? "transparent"
        : Util.alpha(Color.accent, 0.45)

      Behavior on color {
        ColorAnimation { duration: 100 }
      }

      Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.displayLabel
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        font.bold: true
        color: root.dropHovered ? Color.menu.scrim : Color.accent
        opacity: root.dropHovered ? 1.0 : 0.90

        Behavior on opacity {
          NumberAnimation { duration: 100 }
        }
      }
    }
  }

  // ── Preview Area Placeholder ───────────────────────────────────────────────
  // Clean centered creation cue: '+' icon and 'Drop to create WS N' label.
  Item {
    id: previewArea
    z: 10
    anchors.top: cardHeader.bottom
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: Style.spacing.xs
    anchors.bottomMargin: Style.spacing.sm
    anchors.leftMargin: Style.spacing.sm
    anchors.rightMargin: Style.spacing.sm

    Column {
      anchors.centerIn: parent
      spacing: Style.spacing.xs

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "+"
        color: root.dropHovered ? Color.accent : Color.menu.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.title
        font.bold: true
        opacity: root.dropHovered ? 1.0 : 0.65

        Behavior on opacity {
          NumberAnimation { duration: 100 }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Drop to create WS " + root.displayLabel
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        color: root.dropHovered ? Color.accent : Color.menu.text
        opacity: root.dropHovered ? 1.0 : 0.70

        Behavior on opacity {
          NumberAnimation { duration: 100 }
        }
      }
    }
  }

  // ── Drop Area ──────────────────────────────────────────────────────────────
  // The entire visible card bounds form the interactive drop target.
  DropArea {
    id: dropArea
    anchors.fill: parent
    z: 20
    keys: ["omarchy-window"]
    enabled: root.visible && root.draggedToplevel !== null

    onDropped: function(drop) {
      if (!drop.source || !drop.source.toplevel) {
        drop.accepted = false
        return
      }
      drop.acceptProposedAction()
      root.windowDropped(drop.source.toplevel)
    }
  }

  // ── Dedicated Topmost Border Overlay ────────────────────────────────────────
  // Topmost visual overlay (z: 100) ensuring insertion card border is crisp and visible.
  Rectangle {
    id: borderOverlay
    anchors.fill: parent
    z: 100
    color: "transparent"
    radius: root.radius
    border.width: root.cardBorderWidth
    border.color: root.cardBorderColor
  }
}
