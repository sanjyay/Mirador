import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "WindowGeometry.js" as WindowGeometry
import "WindowModel.js" as WindowModel

Item {
  id: root

  required property var overview
  property bool livePreviews: false
  property int toplevelRevision: 0

  readonly property int currentIndex: overview ? overview.selectedCardIndex : 0
  readonly property var cardModel: overview ? overview.overviewCardModel : []
  readonly property int cardCount: cardModel.length

  readonly property var currentItem: (currentIndex >= 0 && currentIndex < cardCount)
    ? cardModel[currentIndex] : null
  readonly property int selectedWorkspaceId: currentItem
    ? (typeof currentItem === "object" ? currentItem.workspaceId : currentItem) : 1
  readonly property bool isScratchpad: currentItem
    ? (typeof currentItem === "object" && Boolean(currentItem.isScratchpad)) : false

  readonly property var selectedWorkspace: overview ? overview.workspaceById(selectedWorkspaceId) : null
  readonly property var selectedMonitor: (selectedWorkspace && selectedWorkspace.monitor)
    ? selectedWorkspace.monitor : Hyprland.focusedMonitor
  readonly property string monitorName: selectedMonitor ? String(selectedMonitor.name || "") : ""
  readonly property bool isMultiMonitor: {
    var scrs = Quickshell.screens ? Quickshell.screens.length : 0
    var mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values.length : 0
    return scrs > 1 || mons > 1
  }

  Connections {
    target: Hyprland
    function onActiveToplevelChanged() { root.toplevelRevision++ }
  }

  Repeater {
    model: root.selectedWorkspace ? root.selectedWorkspace.toplevels : []
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

  readonly property var effectiveToplevels: {
    var rev = root.toplevelRevision
    var activeAddr = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
    var clients = selectedWorkspace ? selectedWorkspace.toplevels.values : []
    return WindowModel.resolveWorkspacePreviews(clients, activeAddr)
  }
  readonly property int windowCount: effectiveToplevels.length
  readonly property bool occupied: windowCount > 0

  readonly property var activeToplevel: {
    if (!occupied) return null
    var activeAddr = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
    if (activeAddr) {
      for (var i = 0; i < effectiveToplevels.length; i++) {
        var item = effectiveToplevels[i]
        var top = (item && item.toplevel) ? item.toplevel : item
        if (top && top.address === activeAddr) return top
      }
    }
    var first = effectiveToplevels[0]
    return (first && first.toplevel) ? first.toplevel : first
  }

  function appNameFor(top) {
    if (!top) return ""
    var wayland = top.wayland
    if (wayland && wayland.appId) return root.cleanAppName(String(wayland.appId))
    var ipc = top.lastIpcObject
    if (ipc && ipc.initialClass) return root.cleanAppName(String(ipc.initialClass))
    if (ipc && ipc.class) return root.cleanAppName(String(ipc.class))
    if (top.appId) return root.cleanAppName(String(top.appId))
    return ""
  }

  function cleanAppName(raw) {
    if (!raw) return ""
    var name = String(raw).split(".").pop()
    if (name.length > 0) return name.charAt(0).toUpperCase() + name.slice(1)
    return name
  }

  function iconFor(top) {
    if (!top) return ""
    var id = (top.wayland && top.wayland.appId) ? String(top.wayland.appId) : ""
    if (!id && top.lastIpcObject) {
      id = top.lastIpcObject.initialClass || top.lastIpcObject.class || ""
    }
    if (!id && top.appId) id = String(top.appId)
    if (!id) return ""
    var entry = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
    if (!entry || !entry.icon) return ""
    return Quickshell.iconPath(entry.icon, true)
  }

  readonly property string activeAppTitle: appNameFor(activeToplevel)
  readonly property string activeWindowFullTitle: activeToplevel && activeToplevel.title ? String(activeToplevel.title) : ""
  readonly property string activeAppIcon: iconFor(activeToplevel)

  // ── Responsive & Stable Dimensions ──────────────────────────────────────────
  readonly property real screenWidth: overview && overview.targetScreen ? overview.targetScreen.width : 1920
  readonly property real screenHeight: overview && overview.targetScreen ? overview.targetScreen.height : 1080
  readonly property real monitorAspect: {
    if (selectedMonitor && selectedMonitor.height > 0) {
      return selectedMonitor.width / selectedMonitor.height
    }
    return 16.0 / 9.0
  }

  readonly property real previewWidth: Math.round(Math.max(560, Math.min(912, screenWidth * 0.48)))
  readonly property real previewHeight: Math.round(previewWidth / Math.max(1.3, Math.min(2.2, monitorAspect)))

  readonly property real headerHeight: Style.space(42)
  readonly property real footerHeight: Style.space(68)
  readonly property real contentPadding: Style.spacing.md

  implicitWidth: previewWidth + contentPadding * 2
  implicitHeight: headerHeight + previewHeight + footerHeight + contentPadding * 2 + Style.spacing.sm * 2
  width: implicitWidth
  height: implicitHeight

  // ── Card Surface ────────────────────────────────────────────────────────────
  Rectangle {
    id: cardSurface
    anchors.fill: parent
    radius: Style.cornerRadiusLarge || Style.space(12)
    color: Color.menu.background
    border.width: 1
    border.color: Util.alpha(Color.menu.border, 0.65)
    clip: true

    // Outer click: switches to this workspace
    MouseArea {
      anchors.fill: parent
      z: 1
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (overview) overview.activateWorkspace(root.selectedWorkspace, root.selectedWorkspaceId, root.occupied)
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: root.contentPadding
      spacing: Style.spacing.sm
      z: 2

      // ── Header: Workspace Badge + Name + Monitor + Count ──────────────────
      Item {
        width: parent.width
        height: root.headerHeight

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.sm

          // KDE-Style Number Badge
          Rectangle {
            height: Style.space(26)
            width: Math.max(height, badgeLabel.implicitWidth + Style.spacing.md)
            radius: Math.min(Style.cornerRadius, Style.space(6))
            color: Color.accent
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: badgeLabel
              anchors.centerIn: parent
              text: WindowModel.workspaceBadgeText(root.selectedWorkspaceId, root.isScratchpad)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              font.bold: true
              color: Color.menu.scrim
            }
          }

          // Workspace Title (visible only for special workspaces like Scratchpad)
          Text {
            visible: root.isScratchpad
            text: "Scratchpad"
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            color: Color.menu.text
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.sm

          // Multi-monitor badge
          Rectangle {
            visible: root.isMultiMonitor && root.monitorName !== ""
            height: Style.space(22)
            width: monitorLabel.implicitWidth + Style.spacing.sm * 2
            radius: Style.cornerRadiusSmall || Style.space(4)
            color: Util.alpha(Color.menu.text, 0.08)
            border.width: 1
            border.color: Util.alpha(Color.menu.border, 0.25)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: monitorLabel
              anchors.centerIn: parent
              text: root.monitorName
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Util.alpha(Color.menu.text, 0.75)
            }
          }

          // Window count pill
          Text {
            text: root.occupied
              ? (root.windowCount + (root.windowCount === 1 ? " window" : " windows"))
              : "Empty"
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
            color: Util.alpha(Color.menu.text, 0.55)
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // ── Center: Workspace Preview Canvas ──────────────────────────────────
      Rectangle {
        id: previewBox
        width: root.previewWidth
        height: root.previewHeight
        radius: Style.cornerRadius
        color: Util.alpha(Color.menu.background, 0.75)
        border.width: 1
        border.color: Util.alpha(Color.menu.border, 0.40)
        clip: true

        // Empty state cue
        Item {
          anchors.fill: parent
          visible: !root.occupied

          Column {
            anchors.centerIn: parent
            spacing: Style.spacing.xs

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "·"
              color: Color.menu.text
              opacity: 0.35
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.displayLarge
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Empty Workspace"
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              color: Util.alpha(Color.menu.text, 0.40)
            }
          }
        }

        // Live Spatial Window Previews
        Item {
          id: spatialPreview
          anchors.fill: parent
          visible: root.occupied

          Repeater {
            model: root.effectiveToplevels

            WindowPreview {
              required property var modelData
              required property int index

              readonly property var previewToplevel: (modelData && modelData.toplevel) ? modelData.toplevel : modelData
              readonly property var previewIpc: (modelData && modelData.lastIpcObject)
                ? modelData.lastIpcObject
                : (previewToplevel ? previewToplevel.lastIpcObject : null)

              readonly property var targetMon: root.selectedMonitor || Hyprland.focusedMonitor
              readonly property var targetScr: root.screenForMonitor(targetMon)

              readonly property var previewGeometry: WindowGeometry.previewGeometry(
                previewIpc,
                targetMon,
                targetScr,
                spatialPreview.width,
                spatialPreview.height,
                Math.min(spatialPreview.width, Math.max(Style.space(48), spatialPreview.width * 0.15)),
                Math.min(spatialPreview.height, Math.max(Style.space(36), spatialPreview.height * 0.20)))

              readonly property var displayGeometry: previewGeometry.valid
                ? previewGeometry
                : WindowGeometry.fallbackGeometry(index, root.windowCount,
                    spatialPreview.width, spatialPreview.height, Style.spacing.xs)

              readonly property real dpr: (targetMon && targetMon.scale > 0)
                ? targetMon.scale
                : ((targetScr && targetScr.devicePixelRatio) ? targetScr.devicePixelRatio : 1.0)

              x: WindowGeometry.snapToDevicePixels(displayGeometry.x, dpr)
              y: WindowGeometry.snapToDevicePixels(displayGeometry.y, dpr)
              width: Math.max(1, WindowGeometry.snapToDevicePixels(displayGeometry.width, dpr))
              height: Math.max(1, WindowGeometry.snapToDevicePixels(displayGeometry.height, dpr))
              z: index + 1

              toplevel: previewToplevel
              isGroup: Boolean(modelData && modelData.isGroup)
              groupMembers: (modelData && modelData.members) ? modelData.members : []
              liveCaptureEnabled: root.livePreviews && root.visible && previewBox.visible

              onActivated: {
                if (root.overview) root.overview.activateWindow(previewToplevel)
              }
              onTabActivated: function(targetToplevel) {
                if (root.overview) root.overview.activateWindow(targetToplevel)
              }
            }
          }
        }

        // Topmost border overlay for preview
        Rectangle {
          anchors.fill: parent
          z: 100
          color: "transparent"
          radius: previewBox.radius
          border.width: 1
          border.color: Util.alpha(Color.menu.border, 0.40)
        }
      }

      // ── Footer: Window Title Summary + Workspace Indicator Strip ──────────
      Column {
        width: parent.width
        height: root.footerHeight
        spacing: Style.spacing.xs

        // Active window label row
        Item {
          width: parent.width
          height: Style.space(22)

          Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs
            visible: root.occupied

            Image {
              visible: root.activeAppIcon !== ""
              source: root.activeAppIcon
              width: Style.space(16)
              height: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }

            Text {
              visible: root.activeAppTitle !== ""
              text: root.activeAppTitle
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              color: Color.menu.text
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              visible: root.activeAppTitle !== "" && root.activeWindowFullTitle !== ""
              text: "—"
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              color: Util.alpha(Color.menu.text, 0.40)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: root.activeWindowFullTitle
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              color: Util.alpha(Color.menu.text, 0.75)
              elide: Text.ElideRight
              width: Math.max(0, parent.width - (parent.spacing * 3 + Style.space(16) + (root.activeAppTitle ? 100 : 0)))
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.occupied
            text: "No active windows"
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.menu.text, 0.35)
          }
        }

        // Workspace Indicator Strip (1  2  [3]  4  S)
        Item {
          width: parent.width
          height: Style.space(32)

          Row {
            id: indicatorRow
            anchors.centerIn: parent
            spacing: Style.spacing.sm

            Repeater {
              model: root.cardModel

              Rectangle {
                required property var modelData
                required property int index

                readonly property int itemWsId: typeof modelData === "object" ? modelData.workspaceId : modelData
                readonly property bool itemIsScratch: typeof modelData === "object" && Boolean(modelData.isScratchpad)
                readonly property bool isCurrentPill: index === root.currentIndex
                readonly property var itemWs: root.overview ? root.overview.workspaceById(itemWsId) : null
                readonly property bool isOccupied: {
                  if (!itemWs) return false
                  if (itemWs.toplevels && itemWs.toplevels.values && itemWs.toplevels.values.length > 0)
                    return true
                  if (itemWs.lastIpcObject && typeof itemWs.lastIpcObject.windows === "number")
                    return itemWs.lastIpcObject.windows > 0
                  return false
                }

                height: Style.space(26)
                width: Math.max(height, pillText.implicitWidth + Style.spacing.md)
                radius: Math.min(Style.cornerRadius, Style.space(6))
                color: isCurrentPill
                  ? Color.accent
                  : (pillMouseArea.containsMouse
                    ? Util.alpha(Color.menu.text, 0.16)
                    : Util.alpha(Color.menu.text, 0.08))
                border.width: isCurrentPill ? 0 : 1
                border.color: isCurrentPill
                  ? "transparent"
                  : (pillMouseArea.containsMouse
                    ? Util.alpha(Color.menu.border, 0.50)
                    : Util.alpha(Color.menu.border, 0.25))

                Behavior on color {
                  ColorAnimation { duration: 80 }
                }

                Text {
                  id: pillText
                  anchors.centerIn: parent
                  text: WindowModel.workspaceBadgeText(itemWsId, itemIsScratch)
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: isCurrentPill || isOccupied
                  color: isCurrentPill
                    ? Color.menu.scrim
                    : (isOccupied ? Color.menu.text : Util.alpha(Color.menu.text, 0.45))
                }

                // Subtle dot under occupied inactive workspace
                Rectangle {
                  visible: isOccupied && !isCurrentPill
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: 2
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: 3
                  height: 3
                  radius: 1.5
                  color: Util.alpha(Color.menu.text, 0.55)
                }

                MouseArea {
                  id: pillMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.overview) {
                      root.overview.selectedCardIndex = index
                      root.overview.activateSelectedCard()
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
