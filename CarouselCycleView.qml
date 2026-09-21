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

  // The same safe monitor rectangle and desktop proportions used by the grid.
  readonly property real dpr: overview ? overview.gridDpr : 1
  readonly property var viewport: overview ? overview.gridViewport
    : WindowGeometry.snapRectToDevicePixels({ x: 0, y: 0, width: width, height: height }, dpr, true)
  readonly property real monitorAspect: WindowGeometry.workspaceAspectRatio(
    overview ? overview.targetMonitor : null, overview ? overview.targetScreen : null)
  readonly property real sideScale: 0.68
  readonly property real sideOpacity: 0.58
  readonly property var layoutGeometry: WindowGeometry.carouselGeometry(
    viewport.width, viewport.height, monitorAspect, {
      count: cardCount, spacing: Style.space(24), peekWidth: Style.space(48),
      previewInset: overview ? overview.gridPreviewInset : 4,
      indicatorHeight: Style.space(26), indicatorSpacing: Style.space(12), sideScale: sideScale
    })
  readonly property real centerPreviewWidth: layoutGeometry.previewWidth
  readonly property real centerPreviewHeight: layoutGeometry.previewHeight
  readonly property real previewInset: WindowGeometry.snapToDevicePixels(layoutGeometry.previewInset, dpr)
  readonly property real slotDistance: layoutGeometry.slotDistance
  readonly property real screenCenterX: layoutGeometry.centerX
  readonly property var indicatorGeometry: WindowGeometry.snapRectToDevicePixels({
    x: 0, y: layoutGeometry.indicatorY,
    width: viewport.width, height: layoutGeometry.indicatorHeight
  }, dpr)

  onSlotDistanceChanged: resetTo(currentIndex)
  onCurrentIndexChanged: Qt.callLater(ensureIndicatorVisible)
  onCardCountChanged: Qt.callLater(ensureIndicatorVisible)

  function ensureIndicatorVisible() {
    var pill = indicatorRepeater.itemAt(currentIndex)
    if (!pill) return
    var target = indicatorRow.x + pill.x + pill.width / 2 - indicatorFlick.width / 2
    indicatorFlick.contentX = Math.max(0, Math.min(target, indicatorFlick.contentWidth - indicatorFlick.width))
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
    x: root.viewport.x
    y: root.viewport.y
    width: root.viewport.width
    height: WindowGeometry.snapToDevicePixels(root.layoutGeometry.contentHeight, root.dpr)
    clip: true
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
            geometry = WindowGeometry.snapRectToDevicePixels(geometry, root.dpr)
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

        readonly property real itemOpacity: normDist <= 1.0
          ? (1.0 - normDist * (1.0 - root.sideOpacity))
          : Math.max(0.15, root.sideOpacity * (1.0 - (normDist - 1.0) * 0.5))

        readonly property bool isHero: index === root.currentIndex

        readonly property var cardGeometry: WindowGeometry.snapRectToDevicePixels(
          WindowGeometry.carouselSlotGeometry(root.layoutGeometry,
            index * root.slotDistance - root.trackOffset), root.dpr)
        width: cardGeometry.width
        height: cardGeometry.height
        x: cardGeometry.x
        y: cardGeometry.y
        opacity: itemOpacity
        visible: normDist < 2.5 && itemOpacity > 0.05
        z: isHero ? 30 : Math.max(1, 20 - Math.round(normDist))

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

          Item {
            anchors.fill: parent
            anchors.margins: root.previewInset
            z: 2

            // Overlay the badge instead of reserving a full-width header.
            Row {
              x: WindowGeometry.snapToDevicePixels(Style.spacing.xs, root.dpr)
              y: x
              spacing: Style.spacing.sm
              z: 110

              Rectangle {
                height: Style.space(26)
                width: Math.max(height, badgeLabel.implicitWidth + Style.spacing.md)
                radius: Math.min(Style.cornerRadius, Style.space(6))
                color: slotItem.isHero ? Color.accent : Color.menu.background
                border.width: slotItem.isHero ? 0 : 1
                border.color: Color.menu.border

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

              Rectangle {
                visible: slotItem.isScratchpad
                height: Style.space(26)
                width: scratchpadLabel.implicitWidth + Style.spacing.md * 2
                radius: Math.min(Style.cornerRadius, Style.space(6))
                color: Color.menu.background
                Text {
                  id: scratchpadLabel
                  anchors.centerIn: parent
                  text: "Scratchpad"
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.body
                  color: Color.menu.text
                }
              }
            }

            // ── Center: Workspace Preview Canvas ────────────────────────────
            Rectangle {
              id: previewBox
              anchors.fill: parent
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

                property var previewMap: ({})

                function syncPreviews() {
                  previewMap = WindowModel.syncPreviewDelegates(
                    spatialPreview,
                    previewMap,
                    slotItem.effectiveToplevels,
                    windowPreviewComponent,
                    {
                      initialProps: function(p, i) {
                        return {
                          itemIndex: i,
                          modelData: p,
                          toplevel: (p && p.activeMember) ? p.activeMember : (p && p.toplevel ? p.toplevel : null)
                        }
                      },
                      onUpdate: function(del, p, i) {
                        del.itemIndex = i
                        del.modelData = p
                        var targetTop = (p && p.activeMember) ? p.activeMember : (p && p.toplevel ? p.toplevel : null)
                        if (del.toplevel !== targetTop) {
                          del.toplevel = targetTop
                        }
                      }
                    }
                  )
                }

                Component.onCompleted: syncPreviews()

                Connections {
                  target: slotItem
                  function onEffectiveToplevelsChanged() {
                    spatialPreview.syncPreviews()
                  }
                }

                Component {
                  id: windowPreviewComponent

                  WindowPreview {
                    id: previewItem
                    required property var modelData
                    property int itemIndex: 0

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
                      : WindowGeometry.fallbackGeometry(itemIndex, slotItem.windowCount,
                          spatialPreview.width, spatialPreview.height, Style.spacing.xs)

                    readonly property var renderGeometry: WindowGeometry.snapRectToDevicePixels(displayGeometry, root.dpr)
                    x: renderGeometry.x
                    y: renderGeometry.y
                    width: Math.max(1 / root.dpr, renderGeometry.width)
                    height: Math.max(1 / root.dpr, renderGeometry.height)
                    keyboardSelected: slotItem.isHero
                      && root.overview && root.overview.isSelectedWindow(previewToplevel)

                    z: keyboardSelected ? 90 : itemIndex + 1

                    toplevel: previewToplevel
                    isGroup: Boolean(modelData && modelData.isGroup)
                    groupMembers: (modelData && modelData.members) ? modelData.members : []
                    liveCaptureEnabled: root.livePreviews && root.visible && slotItem.visible && previewBox.visible && slotItem.normDist < 1.6
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
    x: root.viewport.x
    y: root.viewport.y + root.indicatorGeometry.y
    width: root.viewport.width
    height: root.indicatorGeometry.height
    z: 100
    visible: root.cardCount > 1

    Flickable {
      id: indicatorFlick
      anchors.fill: parent
      contentWidth: Math.max(width, indicatorRow.width)
      contentHeight: height
      flickableDirection: Flickable.HorizontalFlick
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      onWidthChanged: Qt.callLater(root.ensureIndicatorVisible)

      Row {
        id: indicatorRow
        x: WindowGeometry.snapToDevicePixels(Math.max(0, (indicatorFlick.width - width) / 2), root.dpr)
        y: WindowGeometry.snapToDevicePixels((indicatorFlick.height - height) / 2, root.dpr)
        spacing: Style.spacing.sm
        onWidthChanged: Qt.callLater(root.ensureIndicatorVisible)

        Repeater {
          id: indicatorRepeater
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
}
