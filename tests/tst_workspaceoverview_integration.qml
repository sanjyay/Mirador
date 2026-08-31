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

  function workspaceCardSource() {
    var request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../WorkspaceCard.qml"), false)
    request.send()
    verify(request.status === 0 || request.status === 200)
    return request.responseText
  }

  function test_blurNamespaceRemainsStable() {
    var source = workspaceOverviewSource()
    verify(/WlrLayershell\.namespace\s*:\s*"omarchy-workspace-overview"/.test(source))
  }

  function test_keyboardFocusRemainsExclusive() {
    var source = workspaceOverviewSource()
    verify(/WlrLayershell\.keyboardFocus\s*:\s*WlrKeyboardFocus\.Exclusive/.test(source))
  }

  function test_groupModelRefreshesAfterIpcObjectChanges() {
    var source = workspaceCardSource()
    verify(/onLastIpcObjectChanged\s*\(\)\s*\{\s*root\.toplevelRevision\+\+\s*\}/.test(source))
    verify(/onActiveToplevelChanged\s*\(\)\s*\{\s*root\.toplevelRevision\+\+\s*\}/.test(source))
    verify(/WindowModel\.resolveWorkspacePreviews/.test(source))
  }

  function test_groupEventsUseExistingToplevelRefreshPath() {
    var source = workspaceOverviewSource()
    verify(/name\.indexOf\("group"\)\s*!==\s*-1/.test(source))
    verify(/name\.indexOf\("group"\)[\s\S]*Hyprland\.refreshToplevels\(\)/.test(source))
  }
}
