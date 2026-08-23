import QtQuick 2.15
import QtTest 1.3

TestCase {
  name: "WorkspaceOverviewIntegration"

  function workspaceOverviewSource() {
    var request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../WorkspaceOverview.qml"), false)
    request.send()
    verify(request.status === 0 || request.status === 200)
    return request.responseText
  }

  function test_blurNamespaceRemainsStable() {
    var source = workspaceOverviewSource()
    verify(/WlrLayershell\.namespace\s*:\s*"omarchy-workspace-overview"/.test(source))
  }
}
