import QtQuick 2.15
import QtTest 1.3
import "../WindowModel.js" as WindowModel

TestCase {
  name: "WindowModel"

  function client(address, grouped, acceptsInput, focusHistoryID, extra) {
    var ipc = {
      address: address,
      grouped: grouped || [],
      hidden: false,
      visible: acceptsInput === true,
      acceptsInput: acceptsInput === true,
      focusHistoryID: isFinite(focusHistoryID) ? focusHistoryID : (acceptsInput === true ? 0 : 5),
      at: [12, 47],
      size: [900, 1000],
      floating: false
    }
    extra = extra || {}
    for (var key in extra) ipc[key] = extra[key]
    return { address: address, title: extra.title || address, lastIpcObject: ipc }
  }

  function addresses(clients) {
    return clients.map(function(value) { return value.address })
  }

  function test_twoNormalWindowsRemainVisible() {
    var values = [client("0x1", [], true, 0), client("0x2", [], true, 1)]
    compare(addresses(WindowModel.visibleWorkspaceWindows(values)), ["0x1", "0x2"])
  }

  function test_twoMemberGroupUsesActiveMember() {
    var group = ["0x1", "0x2"]
    var values = [client("0x1", group, false, 2), client("0x2", group, true, 0)]
    compare(addresses(WindowModel.visibleWorkspaceWindows(values)), ["0x2"])
  }

  function test_switchingGroupMemberSwitchesResult() {
    var group = ["0x1", "0x2"]
    var first = client("0x1", group, true, 0)
    var second = client("0x2", group, false, 1)
    compare(addresses(WindowModel.visibleWorkspaceWindows([first, second])), ["0x1"])

    first.lastIpcObject.acceptsInput = false
    first.lastIpcObject.focusHistoryID = 1
    second.lastIpcObject.acceptsInput = true
    second.lastIpcObject.focusHistoryID = 0
    compare(addresses(WindowModel.visibleWorkspaceWindows([first, second])), ["0x2"])
  }

  function test_hiddenStateDeprioritizesMinimizedGroupMember() {
    var group = ["0x1", "0x2"]
    var first = client("0x1", group, true, 0, { hidden: true })
    var second = client("0x2", group, false, 2, { hidden: false })
    compare(addresses(WindowModel.visibleWorkspaceWindows([first, second])), ["0x2"])
  }

  function test_activeWindowAddressWinsOverStaleFlags() {
    var group = ["0x1", "0x2"]
    var first = client("0x1", group, true, 0)
    var second = client("0x2", group, false, 1)
    compare(addresses(WindowModel.visibleWorkspaceWindows([first, second], "0x2")), ["0x2"])
  }

  function test_threeMemberGroupIncludesExactlyOne() {
    var group = ["0x1", "0x2", "0x3"]
    var result = WindowModel.visibleWorkspaceWindows([
      client("0x1", group, false, 3),
      client("0x2", group, true, 0),
      client("0x3", group, false, 5)
    ])
    compare(addresses(result), ["0x2"])
  }

  function test_twoIndependentGroups() {
    var one = ["0x1", "0x2"]
    var two = ["0x3", "0x4"]
    var result = WindowModel.visibleWorkspaceWindows([
      client("0x1", one, true, 0), client("0x2", one, false, 2),
      client("0x3", two, false, 3), client("0x4", two, true, 1)
    ])
    compare(addresses(result), ["0x1", "0x4"])
  }

  function test_groupAndNormalWindow() {
    var group = ["0x1", "0x2"]
    var result = WindowModel.visibleWorkspaceWindows([
      client("0x1", group, false, 2),
      client("0x2", group, true, 0),
      client("0x3", [], true, 1)
    ])
    compare(addresses(result), ["0x2", "0x3"])
  }

  function test_unrelatedNormalWindowsWithIdenticalGeometryAreNotDeduplicated() {
    var first = client("0x1", [], true, 0, { at: [0, 0], size: [1920, 1080] })
    var second = client("0x2", [], true, 1, { at: [0, 0], size: [1920, 1080] })
    var result = WindowModel.visibleWorkspaceWindows([first, second])
    compare(addresses(result), ["0x1", "0x2"])
  }

  function test_identicalGeometryGroupedMembersDoNotCover() {
    var group = ["0x1", "0x2"]
    var result = WindowModel.visibleWorkspaceWindows([
      client("0x1", group, false, 1), client("0x2", group, true, 0)
    ])
    compare(result.length, 1)
    compare(result[0].address, "0x2")
    compare(result[0].lastIpcObject.at, [12, 47])
    compare(result[0].lastIpcObject.size, [900, 1000])
  }

  function test_activeMemberCloses() {
    var staleGroup = ["0x1", "0x2"]
    var remaining = client("0x1", staleGroup, true, 0)
    compare(addresses(WindowModel.visibleWorkspaceWindows([remaining])), ["0x1"])
  }

  function test_dissolvedGroupRestoresNormalWindows() {
    var values = [client("0x1", [], true, 0), client("0x2", [], true, 1)]
    compare(addresses(WindowModel.visibleWorkspaceWindows(values)), ["0x1", "0x2"])
  }

  function test_malformedMetadataDoesNotCrash() {
    var malformed = [
      { address: "not-an-address", lastIpcObject: { grouped: null } },
      { address: "0x2", lastIpcObject: { grouped: [null, "bad"] } },
      { address: "0x3" },
      null
    ]
    compare(WindowModel.visibleWorkspaceWindows(malformed).length, 4)
  }

  function test_qtVariantStyleGroupedListIsRecognized() {
    var grouped = { 0: "0x1", 1: "0x2", length: 2 }
    var values = [client("0x1", [], false, 1), client("0x2", [], true, 0)]
    values[0].lastIpcObject.grouped = grouped
    values[1].lastIpcObject.grouped = grouped
    compare(addresses(WindowModel.visibleWorkspaceWindows(values)), ["0x2"])
  }

  function test_missingInputFlagUsesFocusHistoryID() {
    var group = ["0x1", "0x2"]
    var first = client("0x1", group, false, 5, { acceptsInput: undefined })
    var second = client("0x2", group, false, 1, { acceptsInput: undefined })
    compare(addresses(WindowModel.visibleWorkspaceWindows([first, second])), ["0x2"])
  }

  function test_floatingGroupPreservesClientAndGeometry() {
    var group = ["0x1", "0x2"]
    var visible = client("0x2", group, true, 0, {
      floating: true, at: [400, 225], size: [800, 450]
    })
    var result = WindowModel.visibleWorkspaceWindows([
      client("0x1", group, false, 2), visible
    ])
    compare(result.length, 1)
    verify(result[0] === visible)
    compare(result[0].lastIpcObject.at, [400, 225])
    compare(result[0].lastIpcObject.size, [800, 450])
    compare(result[0].lastIpcObject.floating, true)
  }

  function test_partialOverlappingMetadataStillFormsOneGroup() {
    var first = client("0x1", ["0x1", "0x2"], false, 3)
    var second = client("0x2", ["0x1", "0x2", "0x3"], false, 2)
    var third = client("0x3", ["0x2", "0x3"], true, 0)
    compare(addresses(WindowModel.visibleWorkspaceWindows([first, second, third])), ["0x3"])
  }

  function test_addressNormalizationMatchesWithOrWithoutHexPrefix() {
    var group = ["564bf618b650", "0x564bff177040"]
    var first = client("564bf618b650", group, false, 2)
    var second = client("564bff177040", group, true, 0)
    compare(addresses(WindowModel.visibleWorkspaceWindows([first, second], "564bff177040")), ["564bff177040"])
  }

  // ── Structured preview descriptor tests (resolveWorkspacePreviews) ──────────

  function test_resolveGroupModelRetainsEveryMember() {
    var group = ["0x1", "0x2"]
    var brave = client("0x1", group, false, 2, { title: "Brave" })
    var foot = client("0x2", group, true, 0, { title: "foot" })

    var previews = WindowModel.resolveWorkspacePreviews([brave, foot])
    compare(previews.length, 1)
    verify(previews[0].isGroup === true)
    verify(previews[0].type === "group")
    compare(previews[0].activeMember, foot)
    compare(previews[0].toplevel, foot)
    compare(previews[0].members.length, 2)
    compare(previews[0].members[0].title, "Brave")
    compare(previews[0].members[1].title, "foot")
  }

  function test_resolveGroupActiveMemberSwitching() {
    var group = ["0x1", "0x2"]
    var brave = client("0x1", group, false, 2, { title: "Brave" })
    var foot = client("0x2", group, true, 0, { title: "foot" })

    var previews1 = WindowModel.resolveWorkspacePreviews([brave, foot])
    compare(previews1[0].activeMember, foot)

    // Switch active tab to Brave
    brave.lastIpcObject.acceptsInput = true
    brave.lastIpcObject.focusHistoryID = 0
    foot.lastIpcObject.acceptsInput = false
    foot.lastIpcObject.focusHistoryID = 1

    var previews2 = WindowModel.resolveWorkspacePreviews([brave, foot])
    compare(previews2.length, 1)
    verify(previews2[0].isGroup === true)
    compare(previews2[0].activeMember, brave)
    compare(previews2[0].toplevel, brave)
    compare(previews2[0].members.length, 2)
  }

  function test_resolveThreeMemberGroup() {
    var group = ["0x1", "0x2", "0x3"]
    var brave = client("0x1", group, false, 3, { title: "Brave" })
    var foot = client("0x2", group, true, 0, { title: "foot" })
    var ghostty = client("0x3", group, false, 4, { title: "Ghostty" })

    var previews = WindowModel.resolveWorkspacePreviews([brave, foot, ghostty])
    compare(previews.length, 1)
    verify(previews[0].isGroup === true)
    compare(previews[0].activeMember, foot)
    compare(previews[0].members.length, 3)
  }

  function test_resolveMixedWorkspaceNormalAndGroup() {
    var group = ["0x1", "0x2"]
    var brave = client("0x1", group, false, 2, { title: "Brave" })
    var foot = client("0x2", group, true, 0, { title: "foot" })
    var ghostty = client("0x3", [], true, 1, { title: "Ghostty" })
    var files = client("0x4", [], true, 3, { title: "Files" })

    var previews = WindowModel.resolveWorkspacePreviews([brave, foot, ghostty, files])
    // 4 clients total, 1 group + 2 normal = 3 spatial previews
    compare(previews.length, 3)
    verify(previews[0].isGroup === true)
    compare(previews[0].members.length, 2)
    verify(previews[1].isGroup === false)
    compare(previews[1].toplevel, ghostty)
    verify(previews[2].isGroup === false)
    compare(previews[2].toplevel, files)
  }

  function test_resolveGroupCollapsingFromTwoToOne() {
    // When one member of a 2-member group closes, remaining member becomes normal window
    var single = client("0x1", ["0x1"], true, 0, { title: "Remaining" })
    var previews = WindowModel.resolveWorkspacePreviews([single])
    compare(previews.length, 1)
    verify(previews[0].isGroup === false)
    verify(previews[0].type === "window")
    compare(previews[0].toplevel, single)
  }

  function test_resolveGroupDissolution() {
    var brave = client("0x1", [], true, 0, { title: "Brave" })
    var foot = client("0x2", [], true, 1, { title: "foot" })

    var previews = WindowModel.resolveWorkspacePreviews([brave, foot])
    compare(previews.length, 2)
    verify(previews[0].isGroup === false)
    verify(previews[1].isGroup === false)
  }

  function test_resolveTwoIndependentGroups() {
    var group1 = ["0x1", "0x2"]
    var group2 = ["0x3", "0x4"]
    var a = client("0x1", group1, true, 0)
    var b = client("0x2", group1, false, 2)
    var c = client("0x3", group2, false, 3)
    var d = client("0x4", group2, true, 1)

    var previews = WindowModel.resolveWorkspacePreviews([a, b, c, d])
    compare(previews.length, 2)
    verify(previews[0].isGroup === true)
    compare(previews[0].activeMember, a)
    compare(previews[0].members.length, 2)
    verify(previews[1].isGroup === true)
    compare(previews[1].activeMember, d)
    compare(previews[1].members.length, 2)
  }
}
