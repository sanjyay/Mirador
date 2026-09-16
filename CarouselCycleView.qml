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

  readonly property var cardModel: overview ? overview.overviewCardModel : []
  readonly property int cardCount: cardModel.length
  readonly property int currentIndex: overview ? overview.selectedCardIndex : 0

  // ── Track Dimensions & Positioning ─────────────────────────────────────────
  readonly property real screenWidth: overview && overview.targetScreen ? overview.targetScreen.width : 1920
  readonly property real screenHeight: overview && overview.targetScreen ? overview.targetScreen.height : 1080
  readonly property real monitorAspect: {
    var mon = Hyprland.focusedMonitor
    if (mon && mon.height > 0) return mon.width / mon.height
    return 16.0 / 9.0
  }

  // Hero Center Preview Dimensions
  readonly property real centerPreviewWidth: Math.round(Math.min(840, screenWidth * 0.44))
  readonly property real centerPreviewHeight: Math.round(centerPreviewWidth / monitorAspect)
  readonly property real headerHeight: Style.space(38)
  readonly property real cardPadding: Style.spacing.md

  readonly property real centerCardWidth: centerPreviewWidth + cardPadding * 2
  readonly property real centerCardHeight: centerPreviewHeight + headerHeight + cardPadding * 2 + Style.spacing.sm

  // Side Card Dimensions & Proportions
  readonly property real sideScale: 0.68
  readonly property real sideOpacity: 0.58
  readonly property real sideCardWidth: Math.round(centerCardWidth * sideScale)
  readonly property real sideCardHeight: Math.round(centerCardHeight * sideScale)

  // Distance between adjacent card centers on the horizontal strip
  readonly property real slotDistance: Math.round(centerCardWidth * 0.5 + sideCardWidth * 0.5 + Style.space(28))

  readonly property real screenCenterX: Math.round(width / 2)
  readonly property real screenCenterY: Math.round(height / 2 - Style.space(20))

  readonly property bool isMultiMonitor: {
    var scrs = Quickshell.screens ? Quickshell.screens.length : 0
    var mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values.length : 0
    return scrs > 1 || mons > 1
  }

  // ── Animated Scrolling for Available Workspaces Strip ──────────────────────
  readonly property real targetOffset: currentIndex >= 0 ? currentIndex * slotDistance : 0
  property real trackOffset: targetOffset
  property bool animatingEnabled: false

  onTargetOffsetChanged: {
    trackOffset = targetOffset
  }

  Behavior on trackOffset {
    enabled: root.animatingEnabled
    NumberAnimation {
      duration: 150
      easing.type: Easing.OutCubic
    }
  }

  function resetTo(index) {
    animatingEnabled = false
    var idx = index >= 0 ? index : 0
    trackOffset = idx * slotDistance
    Qt.callLater(function() {
      root.animatingEnabled = true
    })
  }

  function step(delta) {
    // Selection state is driven by overview.selectedCardIndex which binds to targetOffset
  }

  function moveWindowSelection(dx, dy) {
    if (!overview || currentIndex < 0) return false
    var slot = workspaceRepeater.itemAt(currentIndex)
    if (!slot) return false
    var items = slot.windowNavigationItems()
    if (!items || items.length === 0) {
      overview.selectedWindowAddress = ""
      return true
    }

    var currentWindowIndex = -1
    for (var i = 0; i < items.length; i++) {
      if (items[i].address === overview.selectedWindowAddress) {
        currentWindowIndex = items[i].index
        break
      }
    }

    if (items.length === 1) {
      overview.selectedWindowAddress = items[0].address
      return true
    }

    var nextIndex = WindowGeometry.cyclicCardMove(items, currentWindowIndex, dx, dy)
    for (var n = 0; n < items.length; n++) {
      if (items[n].index === nextIndex) {
        overview.selectedWindowAddress = items[n].address
        return true
      }
    }
    return true
  }

  Connections {
    target: Hyprland
    function onActiveToplevelChanged() { root.toplevelRevision++ }
  }

  function screenForMonitor(monitor) {
    if (!monitor) return null
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && screens[i].name === monitor.name) return screens[i]
    }
    return null
  }

  // Dismiss when clicking outside cards on the backdrop
  MouseArea {
    anchors.fill: parent
    z: 0
    onClicked: {
      if (overview) overview.dismiss()
    }
  }

  // ── Horizontal Strip: Exactly One Card Per Available Workspace ────────────
  Item {
    id: carouselTrack
    anchors.fill: parent
    z: 10

    Repeater {
      id: workspaceRepeater
      model: root.cardModel

      Item {
        id: slotItem
        required property var modelData
        required property int index

        readonly property int workspaceId: typeof modelData === "object" ? modelData.workspaceId : modelData
        readonly property bool isScratchpad: typeof modelData === "object" && Boolean(modelData.isScratchpad)

        readonly property var workspace: root.overview ? root.overview.workspaceById(workspaceId) : null
        readonly property var wsMonitor: (workspace && workspace.monitor)
          ? workspace.monitor : Hyprland.focusedMonitor
        readonly property string monitorName: wsMonitor ? String(wsMonitor.name || "") : ""

        // Toplevel preview model resolution
        readonly property var effectiveToplevels: {
          var rev = root.toplevelRevision
          var activeAddr = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
          var clients = workspace ? workspace.toplevels.values : []
          return WindowModel.resolveWorkspacePreviews(clients, activeAddr)
        }
        readonly property int windowCount: effectiveToplevels.length
        readonly property bool occupied: windowCount > 0

        function windowNavigationItems() {
          var items = []
          for (var i = 0; i < effectiveToplevels.length; i++) {
            var previewModel = effectiveToplevels[i]
            var previewTop = previewModel && previewModel.activeMember
              ? previewModel.activeMember
              : (previewModel && previewModel.toplevel ? previewModel.toplevel : previewModel)
            var previewIpc = previewModel && previewModel.lastIpcObject
              ? previewModel.lastIpcObject
              : (previewTop ? previewTop.lastIpcObject : null)
            var geometry = WindowGeometry.previewGeometry(
              previewIpc,
              wsMonitor || Hyprland.focusedMonitor,
              root.screenForMonitor(wsMonitor || Hyprland.focusedMonitor),
              previewBox.width,
              previewBox.height,
              Math.min(previewBox.width, Math.max(Style.space(48), previewBox.width * 0.15)),
              Math.min(previewBox.height, Math.max(Style.space(36), previewBox.height * 0.20)))
            if (!geometry.valid) {
              geometry = WindowGeometry.fallbackGeometry(
                i, windowCount, previewBox.width, previewBox.height, Style.spacing.xs)
            }
            var address = WindowModel.normalizedAddress(
              (previewTop && previewTop.address)
                || (previewTop && previewTop.lastIpcObject && previewTop.lastIpcObject.address))
            if (!address) continue
            items.push({
              index: i,
              address: address,
              x: geometry.x,
              y: geometry.y,
              width: geometry.width,
              height: geometry.height,
              centerX: geometry.x + geometry.width / 2,
              centerY: geometry.y + geometry.height / 2,
              isInsertion: false
            })
          }
          return items
        }

        // Spatial Positioning on Linear Strip
        readonly property real cardCenterX: root.screenCenterX + (index * root.slotDistance - root.trackOffset)
        readonly property real pixelDist: Math.abs(root.screenCenterX - cardCenterX)
        readonly property real normDist: pixelDist / root.slotDistance

        readonly property real itemScale: normDist <= 1.0
          ? (1.0 - normDist * (1.0 - root.sideScale))
          : Math.max(0.50, root.sideScale - (normDist - 1.0) * 0.18)

        readonly property real itemOpacity: normDist <= 1.0
          ? (1.0 - normDist * (1.0 - root.sideOpacity))
          : Math.max(0.15, root.sideOpacity * (1.0 - (normDist - 1.0) * 0.5))

        readonly property bool isHero: index === root.currentIndex

        width: root.centerCardWidth
        height: root.centerCardHeight
        x: Math.round(cardCenterX - width / 2)
        y: Math.round(root.screenCenterY - height / 2)
        scale: itemScale
        opacity: itemOpacity
        visible: normDist < 2.5 && itemOpacity > 0.05
        z: isHero ? 30 : Math.max(1, 20 - Math.round(normDist))
        transformOrigin: Item.Center

        // ── Card Surface ────────────────────────────────────────────────────
        Rectangle {
          id: cardSurface
          anchors.fill: parent
          radius: Style.cornerRadiusLarge || Style.space(12)
          color: Color.menu.background
          border.width: slotItem.isHero ? 2 : 1
          border.color: slotItem.isHero ? Color.accent : Util.alpha(Color.menu.border, 0.45)
          clip: true

          MouseArea {
            anchors.fill: parent
            z: 1
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (slotItem.isHero) {
                if (root.overview) root.overview.activateWorkspace(slotItem.workspace, slotItem.workspaceId, slotItem.occupied)
              } else {
                if (root.overview) root.overview.selectedCardIndex = slotItem.index
              }
            }
          }

          Column {
            anchors.fill: parent
            anchors.margins: root.cardPadding
            spacing: Style.spacing.sm
            z: 2

            // ── Card Header: Number Badge only ──────────────────────────────
            Item {
              width: parent.width
              height: root.headerHeight

              Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.spacing.sm

                // Number Badge
                Rectangle {
                  height: Style.space(26)
                  width: Math.max(height, badgeLabel.implicitWidth + Style.spacing.md)
                  radius: Math.min(Style.cornerRadius, Style.space(6))
                  color: slotItem.isHero ? Color.accent : Util.alpha(Color.menu.text, 0.14)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: WindowModel.workspaceBadgeText(slotItem.workspaceId, slotItem.isScratchpad)
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    color: slotItem.isHero ? Color.menu.scrim : Color.menu.text
                  }
                }

                // Scratchpad label (only shown for Scratchpad)
                Text {
                  visible: slotItem.isScratchpad
                  text: "Scratchpad"
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.heading
                  font.bold: true
                  color: Color.menu.text
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Window count / monitor badge row — hidden in carousel
              Row {
                visible: false
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.spacing.sm

                Rectangle {
                  visible: root.isMultiMonitor && slotItem.monitorName !== ""
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
                    text: slotItem.monitorName
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: Util.alpha(Color.menu.text, 0.75)
                  }
                }

                Text {
                  text: slotItem.occupied
                    ? (slotItem.windowCount + (slotItem.windowCount === 1 ? " window" : " windows"))
                    : "Empty"
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  color: Util.alpha(Color.menu.text, slotItem.isHero ? 0.65 : 0.40)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            // ── Center: Workspace Preview Canvas ────────────────────────────
            Rectangle {
              id: previewBox
              width: root.centerPreviewWidth
              height: root.centerPreviewHeight
              radius: Style.cornerRadius
              color: Util.alpha(Color.menu.background, 0.75)
              border.width: 1
              border.color: Util.alpha(Color.menu.border, slotItem.isHero ? 0.50 : 0.25)
              clip: true

              // Empty state cue
              Item {
                anchors.fill: parent
                visible: !slotItem.occupied

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
                visible: slotItem.occupied

                Repeater {
                  model: slotItem.effectiveToplevels

                  WindowPreview {
                    required property var modelData
                    required property int index

                    readonly property var previewToplevel: (modelData && modelData.toplevel) ? modelData.toplevel : modelData
                    readonly property var previewIpc: (modelData && modelData.lastIpcObject)
                      ? modelData.lastIpcObject
                      : (previewToplevel ? previewToplevel.lastIpcObject : null)

                    readonly property var targetMon: slotItem.wsMonitor || Hyprland.focusedMonitor
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
                      : WindowGeometry.fallbackGeometry(index, slotItem.windowCount,
                          spatialPreview.width, spatialPreview.height, Style.spacing.xs)

                    readonly property real dpr: (targetMon && targetMon.scale > 0)
                      ? targetMon.scale
                      : ((targetScr && targetScr.devicePixelRatio) ? targetScr.devicePixelRatio : 1.0)

                    x: WindowGeometry.snapToDevicePixels(displayGeometry.x, dpr)
                    y: WindowGeometry.snapToDevicePixels(displayGeometry.y, dpr)
                    width: Math.max(1, WindowGeometry.snapToDevicePixels(displayGeometry.width, dpr))
                    height: Math.max(1, WindowGeometry.snapToDevicePixels(displayGeometry.height, dpr))
                    keyboardSelected: slotItem.isHero
                      && root.overview && root.overview.isSelectedWindow(previewToplevel)

                    z: keyboardSelected ? 90 : index + 1

                    toplevel: previewToplevel
                    isGroup: Boolean(modelData && modelData.isGroup)
                    groupMembers: (modelData && modelData.members) ? modelData.members : []
                    liveCaptureEnabled: root.livePreviews && root.visible && previewBox.visible && slotItem.normDist < 1.6
                    showLabel: keyboardSelected

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
                border.color: Util.alpha(Color.menu.border, slotItem.isHero ? 0.40 : 0.20)
              }
            }
          }

          // Subtle dimming overlay for non-hero cards
          Rectangle {
            anchors.fill: parent
            z: 50
            color: "#000000"
            opacity: Math.min(0.28, slotItem.normDist * 0.28)
            radius: cardSurface.radius
          }
        }
      }
    }
  }

  // ── Bottom: Workspace Indicator Strip (1  [2]  3  4  S) ───────────────────
  Item {
    id: bottomIndicatorArea
    width: parent.width
    height: Style.space(48)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.max(Style.space(36), Style.space(44))
    z: 100
    visible: root.cardCount > 1

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
            var tops = itemWs.toplevels
            return tops ? (tops.values ? tops.values.length > 0 : tops.length > 0) : false
          }

          height: Style.space(26)
          width: Math.max(height, pillLabel.implicitWidth + Style.spacing.md)
          radius: Math.min(Style.cornerRadius, Style.space(6))
          color: isCurrentPill
            ? Color.accent
            : (isOccupied ? Util.alpha(Color.menu.text, 0.16) : Util.alpha(Color.menu.text, 0.07))
          border.width: isCurrentPill ? 0 : 1
          border.color: isCurrentPill
            ? "transparent"
            : (isOccupied ? Util.alpha(Color.menu.border, 0.45) : Util.alpha(Color.menu.border, 0.20))

          Behavior on color {
            ColorAnimation { duration: 120 }
          }

          Text {
            id: pillLabel
            anchors.centerIn: parent
            text: WindowModel.workspaceBadgeText(itemWsId, itemIsScratch)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: isCurrentPill
            color: isCurrentPill
              ? Color.menu.scrim
              : (isOccupied ? Color.menu.text : Util.alpha(Color.menu.text, 0.45))
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.overview) {
                root.overview.selectedCardIndex = index
              }
            }
          }
        }
      }
    }
  }
}
