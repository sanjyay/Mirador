import QtQuick 2.15

// Registration only: neither this item nor the controller owns layout/input.
Item {
  id: root
  property var controller: null
  property Item anchorItem: parent
  property string kind: "card"
  property string presentation: "full"
  property string workspace: ""
  property string identity: ""
  property var addresses: []
  property bool active: false
  property bool validDropTarget: false
  property bool dropHovered: false
  property real offsetX: 0
  property real offsetY: 0
  property bool ready: false
  readonly property string bodyKey: presentation + ":" + kind + ":" + workspace + ":" + identity
  function bounds() {
    var p = anchorItem.mapToItem(controller.scene, 0, 0)
    return { key: bodyKey, x: p.x, y: p.y, width: anchorItem.width,
      height: anchorItem.height, insertion: kind === "insertion", surface: root }
  }
  function attach() { if (ready && controller) controller.attach(root) }
  onBodyKeyChanged: attach()
  onActiveChanged: {
    attach()
    if (!active) { offsetX = 0; offsetY = 0 }
  }
  onDropHoveredChanged: if (controller) controller.updateAnticipation()
  Component.onCompleted: { ready = true; attach() }
  Component.onDestruction: if (controller) controller.detach(root)
}
