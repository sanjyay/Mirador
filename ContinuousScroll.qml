import QtQuick
Item {
  id: root
  property real distance: 280
  property real displacement: 0
  readonly property real progress: Math.max(-1,Math.min(1,displacement/Math.max(1,distance)))
  signal finished(int step)
  function feed(dx,dy) {
    if (!isFinite(dx) || !isFinite(dy) || Math.abs(dx) <= Math.abs(dy) || dx === 0) return false
    displacement=Math.max(-distance,Math.min(distance,displacement+dx))
    settle.restart()
    return true
  }
  function cancel() { settle.stop(); displacement=0 }
  function finish() {
    var step=Math.abs(progress)>=0.35 ? (progress>0 ? 1 : -1) : 0
    settle.stop()
    root.finished(step)
    displacement=0
  }
  Timer { id: settle; interval: 140; onTriggered: root.finish() }
}
