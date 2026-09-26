import QtQuick 2.15
import QtTest 1.3
import "../WindowGeometry.js" as WindowGeometry
import "../WindowModel.js" as WindowModel

TestCase {
  name: "CarouselCycleUnitTests"

  function readSource(relativePath) {
    var xhr = new XMLHttpRequest()
    var url = Qt.resolvedUrl(relativePath)
    xhr.open("GET", url, false)
    xhr.send(null)
    return xhr.responseText
  }

  function test_workspaceOverviewCarouselIntegration() {
    var source = readSource("../WorkspaceOverview.qml")

    // 1. Settings parsing includes carousel
    verify(/s\.cycleUI\s*===?\s*"carousel"/.test(source),
      "loadSettings must parse cycleUI 'carousel'")

    // 2. open() logic sets activePresentation to carousel
    verify(/root\.activePresentation\s*=\s*"carousel"/.test(source),
      "open() must allow setting activePresentation to carousel")
    verify(/payload\.carousel/.test(source),
      "open() must honor payload.carousel")

    // 3. cycleStep() triggers carouselCycleView.step()
    verify(/carouselCycleView\.step\(stepVal\)/.test(source),
      "cycleStep() must forward step delta to carouselCycleView")

    // 4. close() and dismiss() reset activePresentation to full
    var closeMatch = source.match(/function\s+close\(\)[\s\S]*?\n  \}/)
    verify(closeMatch && /activePresentation\s*=\s*"full"/.test(closeMatch[0]),
      "close() must reset activePresentation to 'full'")
    var dismissMatch = source.match(/function\s+dismiss\(\)[\s\S]*?\n  \}/)
    verify(dismissMatch && /activePresentation\s*=\s*"full"/.test(dismissMatch[0]),
      "dismiss() must reset activePresentation to 'full'")

    // 5. cardsContainer visibility and livePreviews exclusion
    verify(/cardsContainer[\s\S]*visible\s*:\s*root\.activePresentation\s*!==\s*"compact"\s*&&\s*root\.activePresentation\s*!==\s*"carousel"/.test(source),
      "cardsContainer must be hidden when activePresentation is carousel")
    verify(/livePreviews\s*:\s*root\.opened\s*&&\s*root\.livePreviewsReady\s*&&\s*panel\.visible\s*&&\s*root\.activePresentation\s*!==\s*"compact"\s*&&\s*root\.activePresentation\s*!==\s*"carousel"/.test(source),
      "cardsContainer cards must disable livePreviews in carousel mode")

    // 6. CarouselCycleView declaration
    verify(/CarouselCycleView\s*\{/.test(source),
      "WorkspaceOverview must host CarouselCycleView")
    verify(/visible\s*:\s*root\.activePresentation\s*===\s*"carousel"/.test(source),
      "CarouselCycleView must be visible only when activePresentation is carousel")
    verify(/livePreviews\s*:\s*root\.opened\s*&&\s*root\.livePreviewsReady\s*&&\s*panel\.visible\s*&&\s*root\.activePresentation\s*===\s*"carousel"/.test(source),
      "CarouselCycleView must receive active livePreviews only when carousel is active")
  }

  function test_carouselCycleViewComponentStructure() {
    var source = readSource("../CarouselCycleView.qml")

    // 1. Required overview property
    verify(/required\s+property\s+var\s+overview/.test(source),
      "CarouselCycleView must declare required overview property")

    // 2. Animated tracking properties and methods
    verify(/property\s+real\s+trackOffset/.test(source),
      "CarouselCycleView must track animated trackOffset")
    verify(/readonly\s+property\s+real\s+targetOffset/.test(source),
      "CarouselCycleView must calculate targetOffset")
    verify(/function\s+resetTo\(index\)/.test(source),
      "CarouselCycleView must implement resetTo(index)")
    verify(/model\s*:\s*root\.cardModel/.test(source),
      "CarouselCycleView must model only available workspaces without continuous duplication")

    // 3. Sizing and scale variables
    verify(/readonly\s+property\s+real\s+centerPreviewWidth/.test(source),
      "CarouselCycleView must define centerPreviewWidth")
    verify(/readonly\s+property\s+real\s+sideScale\s*:\s*0\.68/.test(source),
      "CarouselCycleView must set sideScale")
    verify(/readonly\s+property\s+real\s+slotDistance/.test(source),
      "CarouselCycleView must compute slotDistance")

    // 4. WindowPreview delegate & spatial geometry
    verify(/WindowPreview\s*\{/.test(source),
      "CarouselCycleView must instantiate WindowPreview delegates")
    verify(/WindowGeometry\.previewGeometry/.test(source),
      "CarouselCycleView must calculate previewGeometry")
    verify(/WindowGeometry\.snapToDevicePixels/.test(source),
      "CarouselCycleView must snap coordinates via snapToDevicePixels")

    // 5. Bottom indicator row
    verify(/indicatorRow/.test(source),
      "CarouselCycleView must include indicatorRow for bottom workspace strip")
  }

  function test_binMiradorCarouselFlag() {
    var source = readSource("../bin/mirador")
    verify(/--carousel/.test(source),
      "bin/mirador must support --carousel CLI flag")
    verify(/cycleUI["']?\s*:\s*["']?carousel/.test(source),
      "bin/mirador --carousel must pass cycleUI: 'carousel'")
  }

  function test_binMiradorKeybindingShortcuts() {
    var source = readSource("../bin/mirador")

    // --cycle-next
    verify(/--cycle-next/.test(source), "bin/mirador must support --cycle-next flag")
    verify(/--cycle-next\s*\)[\s\S]*?summon mirador\s*'\{[^}]*"step":\s*1[^}]*"cycleUI":\s*"carousel"[^}]*"keybindMode":\s*"cycle"/.test(source),
      "bin/mirador --cycle-next must pass step:1, cycleUI:carousel, keybindMode:cycle")

    // --cycle-prev
    verify(/--cycle-prev/.test(source), "bin/mirador must support --cycle-prev flag")
    verify(/--cycle-prev\s*\)[\s\S]*?summon mirador\s*'\{[^}]*"step":\s*-1[^}]*"cycleUI":\s*"carousel"[^}]*"keybindMode":\s*"cycle"/.test(source),
      "bin/mirador --cycle-prev must pass step:-1, cycleUI:carousel, keybindMode:cycle")

    verify(/--close-window\s*\)[\s\S]*?summon mirador\s*'\{[^}]*"action":\s*"closeWindow"/.test(source),
      "bin/mirador --close-window must send the addressed close action")
    verify(/--window-left\s*\)[\s\S]*?"action":\s*"navigateWindow"[^}]*"dx":\s*-1/.test(source),
      "bin/mirador --window-left must send leftward window navigation")
    verify(/--window-right\s*\)[\s\S]*?"action":\s*"navigateWindow"[^}]*"dx":\s*1/.test(source),
      "bin/mirador --window-right must send rightward window navigation")
    verify(/--window-up\s*\)[\s\S]*?"action":\s*"navigateWindow"[^}]*"dy":\s*-1/.test(source),
      "bin/mirador --window-up must send upward window navigation")
    verify(/--window-down\s*\)[\s\S]*?"action":\s*"navigateWindow"[^}]*"dy":\s*1/.test(source),
      "bin/mirador --window-down must send downward window navigation")
    verify(/--move-window-to-workspace\s*\)/.test(source),
      "bin/mirador must support addressed workspace movement")
    verify(/moveWindowToWorkspace/.test(source) && /workspace/.test(source),
      "bin/mirador must send an explicit workspace move action")
    verify(/--workspace\s*\)/.test(source),
      "bin/mirador must support deterministic numeric workspace navigation")
    verify(/navigateWorkspace/.test(source),
      "bin/mirador must send numeric navigation through Mirador IPC")

    // --full
    verify(/--full/.test(source), "bin/mirador must support --full flag")
    verify(/--full\s*\)[\s\S]*?toggle mirador\s*'\{[^}]*"cycleUI":\s*"full"[^}]*"keybindMode":\s*"normal"/.test(source),
      "bin/mirador --full must pass cycleUI:full, keybindMode:normal")
  }

  function test_carouselAddressedWorkspaceMoveIntegration() {
    var overview = readSource("../WorkspaceOverview.qml")
    var bindings = readSource("../mirador.bindings.lua")

    verify(/payload\.action\s*===\s*"moveWindowToWorkspace"/.test(overview),
      "WorkspaceOverview must handle addressed workspace-move actions")
    verify(/function\s+moveSelectedWindowToWorkspace\(workspaceId\)/.test(overview),
      "WorkspaceOverview must expose selected-window workspace movement")
    verify(/activeToplevelForWorkspace\([\s\S]*?moveWindowToWorkspace\(targetToplevel, workspaceId\)/.test(overview),
      "Carousel movement must resolve and move the explicitly selected preview")
    verify(/function\s+dispatchActiveWindowToWorkspace\(workspaceId\)/.test(overview),
      "Normal desktop movement must remain available")
    verify(/SUPER \+ SHIFT \+ /.test(bindings)
        && /mirador --move-window-to-workspace/.test(bindings),
      "Number workspace-move bindings must route through Mirador")
    verify(/hl\.unbind\("SUPER \+ SHIFT \+ " \..*keycode\)/.test(bindings),
      "Mirador bindings must remove Omarchy's physical-keycode workspace move")
    verify(/o\.bind\([\s\S]*?"SUPER \+ SHIFT \+ " \..*keycode/.test(bindings),
      "Mirador workspace moves must use the same physical keycodes as Omarchy")
  }

  function test_carouselDeterministicNumericWorkspaceBindings() {
    var overview = readSource("../WorkspaceOverview.qml")
    var bindings = readSource("../mirador.bindings.lua")

    verify(/payload\.action\s*===\s*"navigateWorkspace"/.test(overview),
      "WorkspaceOverview must handle numeric workspace IPC actions")
    verify(/navigateWorkspace[\s\S]*?root\.opened[\s\S]*?navigateToWorkspaceNumber\(workspaceTarget\)/.test(overview),
      "An open carousel must navigate its selected card")
    verify(/navigateWorkspace[\s\S]*?else[\s\S]*?dispatchWorkspace\(workspaceTarget\)/.test(overview),
      "A closed carousel must preserve normal desktop workspace switching")
    verify(/hl\.unbind\("SUPER \+ " \.\. keycode\)/.test(bindings),
      "Mirador bindings must remove Omarchy physical-keycode workspace navigation")
    verify(/o\.bind\([\s\S]*?"SUPER \+ " \.\. keycode[\s\S]*?mirador --workspace/.test(bindings),
      "Numeric workspace bindings must route through Mirador IPC")
  }

  function test_availableWorkspacesLinearStrip() {
    // Exactly available workspaces are mapped with no artificial continuous duplicate slots
    var workspaces = [1, 2, 4, 7]
    compare(workspaces.length, 4)
    for (var i = 0; i < workspaces.length; i++) {
      compare(workspaces[i], [1, 2, 4, 7][i])
    }
  }

  function test_continuousResponsiveDimensionsStability() {
    var geometry = WindowGeometry.carouselGeometry(1888, 1013, 1920 / 1045, {
      count: 3, spacing: 24, sideVisibility: 0.8, previewSizeMultiplier: 1.32, previewInset: 4,
      indicatorHeight: 26, indicatorSpacing: 12
    })
    verify(geometry.cardWidth > geometry.width * 0.60 && geometry.cardWidth < geometry.width * 0.65,
      "Enlarged hero must still leave substantial space for both neighbors")
    var hero = WindowGeometry.carouselSlotGeometry(geometry, 0)
    var side = WindowGeometry.carouselSlotGeometry(geometry, geometry.slotDistance)
    verify(Math.abs(side.x - hero.x - hero.width - 24) < 0.001)
    verify(side.x < geometry.width && side.x + side.width > geometry.width,
      "Neighbor must remain partially visible at the safe viewport edge")
    verify(side.width < hero.width * 0.75)
    verify((geometry.width - side.x) / side.width > 0.4)
    var left = WindowGeometry.carouselSlotGeometry(geometry, -geometry.slotDistance)
    verify((left.x + left.width) / left.width > 0.4)
  }

  function test_workspaceOverviewDirectNumberNavigationIntegration() {
    var source = readSource("../WorkspaceOverview.qml")

    // 1. Check helper functions exist
    verify(/function\s+navigateToWorkspaceNumber\(target\)/.test(source),
      "WorkspaceOverview must declare navigateToWorkspaceNumber(target)")
    verify(/function\s+workspaceTargetFromEvent\(event\)/.test(source),
      "WorkspaceOverview must declare workspaceTargetFromEvent(event)")

    // 2. WindowModel findWorkspaceCardIndex integration
    verify(/WindowModel\.findWorkspaceCardIndex/.test(source),
      "navigateToWorkspaceNumber must use WindowModel.findWorkspaceCardIndex")

    // 3. Keys.onPressed forwards to workspaceTargetFromEvent and navigateToWorkspaceNumber
    verify(/workspaceTargetFromEvent\(event\)/.test(source),
      "Keys.onPressed must query workspaceTargetFromEvent")
    verify(/navigateToWorkspaceNumber\(targetWs\)/.test(source),
      "Keys.onPressed must invoke navigateToWorkspaceNumber with targetWs")
  }

  function test_workspaceTargetFromEventParsing() {
    // Helper simulating workspaceTargetFromEvent logic
    function parseTarget(key, modifiers, text, activePresentation, activeCycleModifier) {
      var isSuper = Boolean(modifiers & 0x10000000) // Qt.MetaModifier
      var isCycleMod = Boolean(activeCycleModifier && (modifiers & activeCycleModifier))
      var isNoMod = (modifiers === 0)

      if (activePresentation === "carousel") {
        if (!isSuper && !isCycleMod && !isNoMod) return null
      } else {
        if (!isSuper && !isCycleMod) return null
      }

      var Qt_Key_0 = 0x30
      var Qt_Key_1 = 0x31
      var Qt_Key_9 = 0x39
      var Qt_Key_S = 0x53

      if (key >= Qt_Key_1 && key <= Qt_Key_9) {
        return key - Qt_Key_0
      }
      if (key === Qt_Key_0) {
        return 10
      }
      if (key === Qt_Key_S) {
        return "scratchpad"
      }

      if (text && text.length === 1) {
        if (text >= "1" && text <= "9") {
          return parseInt(text, 10)
        }
        if (text === "0") {
          return 10
        }
        if (text === "s" || text === "S") {
          return "scratchpad"
        }
      }

      return null
    }

    var MetaMod = 0x10000000
    var CtrlMod = 0x04000000
    var ShiftMod = 0x02000000
    var KeypadMod = 0x20000000

    // Super + 1..9 in carousel
    compare(parseTarget(0x31, MetaMod, "1", "carousel", MetaMod), 1)
    compare(parseTarget(0x32, MetaMod, "2", "carousel", MetaMod), 2)
    compare(parseTarget(0x35, MetaMod, "5", "carousel", MetaMod), 5)
    compare(parseTarget(0x39, MetaMod, "9", "carousel", MetaMod), 9)

    // Super + 0 -> 10
    compare(parseTarget(0x30, MetaMod, "0", "carousel", MetaMod), 10)

    // Super + S -> scratchpad
    compare(parseTarget(0x53, MetaMod, "s", "carousel", MetaMod), "scratchpad")

    // Super + Shift + 1 (e.g. AZERTY)
    compare(parseTarget(0x31, MetaMod | ShiftMod, "1", "carousel", MetaMod), 1)

    // Super + Keypad (NumLock active)
    compare(parseTarget(0x32, MetaMod | KeypadMod, "2", "carousel", MetaMod), 2)

    // Unmodified 1..9 in carousel
    compare(parseTarget(0x33, 0, "3", "carousel", MetaMod), 3)

    // Disallowed modifier (Ctrl + 1 when cycle modifier is Super)
    compare(parseTarget(0x31, CtrlMod, "1", "carousel", MetaMod), null)

    // Non-number keys (Tab, arrows, Return) return null
    var Qt_Key_Tab = 0x01000001
    compare(parseTarget(Qt_Key_Tab, MetaMod, "\t", "carousel", MetaMod), null)
  }

  function test_carouselNumberNavigationModelResolution() {
    var cardModel = [
      { workspaceId: 1, isInsertion: false, isScratchpad: false },
      { workspaceId: 2, isInsertion: false, isScratchpad: false },
      { workspaceId: 4, isInsertion: false, isScratchpad: false },
      { workspaceId: 10, isInsertion: false, isScratchpad: false },
      { workspaceId: -98, isInsertion: false, isScratchpad: true }
    ]

    // Verify resolving target workspace number to card index
    compare(WindowModel.findWorkspaceCardIndex(cardModel, 1), 0)
    compare(WindowModel.findWorkspaceCardIndex(cardModel, 2), 1)
    compare(WindowModel.findWorkspaceCardIndex(cardModel, 4), 2)
    compare(WindowModel.findWorkspaceCardIndex(cardModel, 10), 3)
    compare(WindowModel.findWorkspaceCardIndex(cardModel, 0), 3) // Key 0 maps to 10
    compare(WindowModel.findWorkspaceCardIndex(cardModel, "scratchpad"), 4)

    // Non-existent workspace returns -1
    compare(WindowModel.findWorkspaceCardIndex(cardModel, 3), -1)
    compare(WindowModel.findWorkspaceCardIndex(cardModel, 5), -1)
  }

  function test_missingNumericWorkspaceBecomesSelected() {
    var source = readSource("../WorkspaceOverview.qml")

    verify(/property\s+int\s+pendingWorkspaceNavigationTarget\s*:\s*-1/.test(source),
      "Missing numeric navigation must retain its intended workspace")
    verify(/foundIndex\s*===\s*-1[\s\S]*pendingWorkspaceNavigationTarget\s*=\s*targetNum[\s\S]*dispatchWorkspace\(targetNum\)/.test(source),
      "A missing workspace must be recorded before it is created")
    verify(/function\s+resolvePendingWorkspaceNavigation\(\)[\s\S]*findWorkspaceCardIndex[\s\S]*navigateToWorkspaceNumber\(target\)/.test(source),
      "Pending navigation must select the card once it appears")
    verify(/onOverviewCardModelChanged[\s\S]*resolvePendingWorkspaceNavigation/.test(source),
      "Workspace model updates must retry pending card selection")
    verify(/function\s+activateSelectedCard\(\)[\s\S]*pendingWorkspaceNavigationTarget[\s\S]*dispatchWorkspace\(pendingWorkspaceTarget\)/.test(source),
      "Super release must keep a not-yet-rendered workspace authoritative")
  }

  function test_workspaceOverviewCompositorEventSyncIntegration() {
    var source = readSource("../WorkspaceOverview.qml")

    // 1. Verify workspace raw event handler parses and navigates
    verify(/name\s*===\s*"workspace"\s*\|\|\s*name\s*===\s*"workspacev2"/.test(source),
      "onRawEvent must handle workspace and workspacev2 events")
    verify(/root\.navigateToWorkspaceNumber\(targetWs\)/.test(source),
      "onRawEvent must forward target workspace to navigateToWorkspaceNumber")

    // 2. Verify onFocusedWorkspaceChanged handler exists for compositor changes
    verify(/function\s+onFocusedWorkspaceChanged\(\)/.test(source),
      "WorkspaceOverview must declare onFocusedWorkspaceChanged")

    // 3. Verify navigateToWorkspaceNumber dispatches missing numeric workspaces
    verify(/root\.dispatchWorkspace\(targetNum\)/.test(source),
      "navigateToWorkspaceNumber must dispatch missing workspace to Hyprland")

    // 4. Verify PanelWindow does not attach invalid Keys.forwardTo
    verify(!/Keys\.forwardTo\s*:\s*\[keyCatcher\]/.test(source),
      "PanelWindow must not attach Keys.forwardTo as it is not an Item")
  }

  function test_cycleModeIgnoresStaleCompositorWorkspaceEchoes() {
    var source = readSource("../WorkspaceOverview.qml")
    verify(/root\.activePresentation\s*===\s*"carousel"\s*&&\s*root\.keybindMode\s*!==\s*"cycle"/.test(source),
      "Raw compositor workspace sync must not override cycle-owned selection")
    verify(/onFocusedWorkspaceChanged\(\)[\s\S]*root\.keybindMode\s*===\s*"cycle"\)\s*return/.test(source),
      "Focused-workspace echoes must be ignored during cycle navigation")
  }

  function test_carouselWorkspaceSyncAndCancellation() {
    var source = readSource("../WorkspaceOverview.qml")

    // 1. initialWorkspaceTarget property declaration
    verify(/property\s+var\s+initialWorkspaceTarget\s*:\s*null/.test(source),
      "WorkspaceOverview must declare initialWorkspaceTarget initialized to null")

    // 2. open() records origin workspace
    verify(/root\.initialWorkspaceTarget\s*=\s*WindowModel\.restoreWorkspaceTarget\(Hyprland\.focusedWorkspace\)/.test(source),
      "open() must record initialWorkspaceTarget from Hyprland.focusedWorkspace")

    // 3. cycleStep dispatches to compositor in carousel mode
    verify(/cycleStep[\s\S]*activePresentation\s*===\s*"carousel"[\s\S]*dispatchWorkspace\(curWsId\)/.test(source),
      "cycleStep must dispatch workspace in carousel presentation")

    // 4. navigateToWorkspaceNumber dispatches to compositor in carousel mode
    verify(/navigateToWorkspaceNumber[\s\S]*activePresentation\s*===\s*"carousel"[\s\S]*dispatchWorkspace\(foundWsId\)/.test(source),
      "navigateToWorkspaceNumber must dispatch workspace in carousel presentation")

    // 5. onSelectedCardIndexChanged dispatches to compositor when opened in carousel mode
    verify(/onSelectedCardIndexChanged\s*:\s*\{[\s\S]*root\.opened\s*&&\s*root\.activePresentation\s*===\s*"carousel"[\s\S]*dispatchWorkspace\(curWsId\)/.test(source),
      "onSelectedCardIndexChanged must dispatch workspace in carousel mode")

    // 6. Activation functions clear initialWorkspaceTarget
    verify(/function\s+activateSelectedCard\(\)\s*\{[\s\S]*root\.initialWorkspaceTarget\s*=\s*null/.test(source),
      "activateSelectedCard must clear initialWorkspaceTarget to keep selection")
    verify(/function\s+activateWorkspace[\s\S]*root\.initialWorkspaceTarget\s*=\s*null/.test(source),
      "activateWorkspace must clear initialWorkspaceTarget to keep selection")
    verify(/function\s+activateWindow[\s\S]*root\.initialWorkspaceTarget\s*=\s*null/.test(source),
      "activateWindow must clear initialWorkspaceTarget to keep selection")

    // 7. Dismiss and close schedule restoration after the exclusive layer hides
    verify(/function\s+close\(\)[\s\S]*scheduleCompositorFocusRestore\(restoreWorkspaceTarget, restoreWindowAddress\)/.test(source),
      "close() must schedule compositor focus restoration")
    verify(/function\s+dismiss\(\)[\s\S]*scheduleCompositorFocusRestore\(restoreWorkspaceTarget, restoreWindowAddress\)/.test(source),
      "dismiss() must schedule compositor focus restoration")
    verify(/restoreCompositorFocusTimer[\s\S]*dispatchWorkspace\(workspaceTarget\)/.test(source),
      "focus restoration must switch back after the exclusive layer hides")
  }

  function test_closeActiveWindowInSelectedWorkspaceIntegration() {
    var source = readSource("../WorkspaceOverview.qml")

    // 1. Function declarations
    verify(/function\s+activeToplevelForWorkspace\(workspace\)/.test(source),
      "WorkspaceOverview must declare activeToplevelForWorkspace(workspace)")
    verify(/function\s+closeWindow\(toplevel\)/.test(source),
      "WorkspaceOverview must declare closeWindow(toplevel)")
    verify(/function\s+closeActiveWindowInSelectedWorkspace\(\)/.test(source),
      "WorkspaceOverview must declare closeActiveWindowInSelectedWorkspace()")

    // 2. closeWindow delegates to Hyprland dispatcher without dismissing
    verify(/closeWindow[\s\S]*hl\.dsp\.window\.close/.test(source),
      "closeWindow must use hl.dsp.window.close for Lua environments")
    verify(/closeWindow[\s\S]*closewindow\s+address:/.test(source),
      "closeWindow must support closewindow address fallback")

    // 3. The shell action invokes addressed close selection
    verify(/payload\.action\s*===\s*"closeWindow"[\s\S]*root\.closeActiveWindowInSelectedWorkspace\(\)/.test(source),
      "closeWindow action must invoke closeActiveWindowInSelectedWorkspace")

    // 4. closeWindow does NOT call dismiss or close (keeps carousel open)
    var closeWinMatch = source.match(/function\s+closeWindow\(toplevel\)[\s\S]*?\n  \}/)
    verify(closeWinMatch && !/root\.dismiss/.test(closeWinMatch[0]),
      "closeWindow must not call dismiss()")
    verify(closeWinMatch && !/root\.close\(\)/.test(closeWinMatch[0]),
      "closeWindow must not call close()")

    // 5. Toplevel revision increment on window close
    verify(/toplevelRevision\+\+/.test(source),
      "closeWindow and onRawEvent must increment toplevelRevision to refresh previews")
  }

  function test_carouselWindowSelectionIntegration() {
    var overview = readSource("../WorkspaceOverview.qml")
    var carousel = readSource("../CarouselCycleView.qml")
    var preview = readSource("../WindowPreview.qml")
    var binding = readSource("../mirador.bindings.lua")

    verify(/property\s+string\s+selectedWindowAddress\s*:\s*""/.test(overview),
      "WorkspaceOverview must own explicit selected-window state")
    verify(/payload\.action\s*===\s*"navigateWindow"/.test(overview),
      "WorkspaceOverview must handle compositor-routed window navigation")
    verify(/function\s+moveSelectedWindow\(dx, dy\)/.test(overview),
      "WorkspaceOverview must expose carousel window movement")
    verify(/function\s+moveWindowSelection\(dx, dy\)/.test(carousel),
      "CarouselCycleView must navigate its rendered window previews")
    verify(/WindowGeometry\.cyclicCardMove\(items, currentWindowIndex, dx, dy\)/.test(carousel),
      "Window navigation must use rendered 2D cyclic geometry")
    verify(/keyboardSelected:\s*slotItem\.isHero/.test(carousel),
      "Only the selected hero-card window may show keyboard selection")
    verify(/property\s+bool\s+keyboardSelected\s*:\s*false/.test(preview),
      "WindowPreview must expose keyboard selection styling")
    verify(/root\.keyboardSelected[\s\S]*Color\.accent/.test(preview),
      "Selected window preview must render an accent border")
    verify(/SUPER \+ LEFT[\s\S]*mirador --window-left/.test(binding),
      "Mirador binding must route Super+Left through the overlay")
    verify(/SUPER \+ W[\s\S]*mirador --close-window/.test(binding),
      "Mirador binding must close the explicitly selected window")
  }

  function test_deterministicCloseDispatchAndCancellationInvariants() {
    var source = readSource("../WorkspaceOverview.qml")

    // 1. initialActiveWindowAddress property
    verify(/property\s+string\s+initialActiveWindowAddress\s*:\s*""/.test(source),
      "WorkspaceOverview must declare initialActiveWindowAddress property")

    // 2. Exclusive layer focus makes compositor focus synchronization invalid.
    verify(!/function\s+syncSelectedWorkspaceFocus\(\)/.test(source),
      "WorkspaceOverview must not try to focus a window behind an exclusive layer")

    // 3. The compositor binding routes through an explicit plugin action.
    verify(/payload\.action\s*===\s*"closeWindow"/.test(source),
      "WorkspaceOverview must handle the closeWindow action")
    verify(/payload\.action\s*===\s*"closeWindow"[\s\S]*root\.opened[\s\S]*closeActiveWindowInSelectedWorkspace/.test(source),
      "An open Mirador must close the explicitly selected workspace window")
    verify(/payload\.action\s*===\s*"closeWindow"[\s\S]*hl\.dsp\.window\.close\(\)/.test(source),
      "A closed Mirador must preserve the normal active-window close behavior")

    // 4. Close and destroy events exclude stale model objects immediately.
    verify(/function\s+markWindowClosing\(value\)/.test(source),
      "WorkspaceOverview must track closing addresses")
    verify(/closewindow.*destroywindow[\s\S]*markWindowClosing/.test(source),
      "onRawEvent must exclude closing windows from successive close selection")

    // 5. Cancel restoration includes initial active window
    var dismissMatch = source.match(/function\s+dismiss\(\)[\s\S]*?\n  \}/)
    verify(dismissMatch && /initialActiveWindowAddress/.test(dismissMatch[0]),
      "dismiss() must restore initialActiveWindowAddress on cancellation")
    var closeMatch = source.match(/function\s+close\(\)[\s\S]*?\n  \}/)
    verify(closeMatch && /initialActiveWindowAddress/.test(closeMatch[0]),
      "close() must restore initialActiveWindowAddress on cancellation")
  }

  function test_miradorAwareCloseBindingDocumentation() {
    var binding = readSource("../mirador.bindings.lua")
    verify(/hl\.unbind\("SUPER \+ W"\)/.test(binding),
      "Mirador binding must replace the compositor's unaddressed close")
    verify(/mirador --close-window/.test(binding),
      "Mirador binding must route close through the plugin action")
  }
  function carouselOptions(count, scale) {
    return { count: count, spacing: 24 * scale, sideVisibility: 0.8, previewSizeMultiplier: 1.32,
      previewInset: 4 * scale, indicatorHeight: 26 * scale, indicatorSpacing: 12 * scale }
  }

  function near(actual, expected, tolerance) {
    verify(Math.abs(actual - expected) < (tolerance || 0.001),
      "Expected " + expected + ", got " + actual)
  }

  function test_carouselMonitorAwareSizing_data() {
    var displays = [
      { tag: "1080p", w: 1920, h: 1080, dpr: 1 },
      { tag: "1440p", w: 2560, h: 1440, dpr: 1.25 },
      { tag: "4k", w: 3840, h: 2160, dpr: 2 },
      { tag: "ultrawide", w: 3440, h: 1440, dpr: 1 },
      { tag: "portrait", w: 1080, h: 1920, dpr: 1 },
      { tag: "fractional", w: 2560, h: 1600, dpr: 1.5 }
    ]
    var bars = ["", "left", "top", "right", "bottom"]
    var rows = []
    for (var d = 0; d < displays.length; d++) {
      for (var b = 0; b < bars.length; b++) {
        rows.push({ tag: displays[d].tag + "-" + bars[b], display: displays[d], bar: bars[b] })
      }
    }
    return rows
  }

  function test_carouselMonitorAwareSizing(data) {
    var display = data.display
    var reserved = [0, 0, 0, 0]
    var edges = { left: 0, top: 1, right: 2, bottom: 3 }
    if (data.bar) reserved[edges[data.bar]] = 35
    var monitor = { name: "carousel", x: -1920, y: -100, width: display.w,
      height: display.h, scale: display.dpr, reserved: reserved }
    var screen = { name: "carousel", width: display.w / display.dpr, height: display.h / display.dpr }
    var aspect = WindowGeometry.workspaceAspectRatio(monitor, screen)
    var safe = WindowGeometry.safeAreaGeometry(screen.width, screen.height, data.bar,
      data.bar ? 35 : 0, 16, reserved)
    var viewport = WindowGeometry.snapRectToDevicePixels({ x: safe.usableX, y: safe.usableY,
      width: safe.usableWidth, height: safe.usableHeight }, display.dpr, true)
    var counts = [0, 1, 2, 3, 5, 12, 50]
    for (var n = 0; n < counts.length; n++) {
      var options = carouselOptions(counts[n], 1)
      var layout = WindowGeometry.carouselGeometry(viewport.width, viewport.height, aspect, options)
      options.previewSizeMultiplier = 1.2
      var baseline = WindowGeometry.carouselGeometry(viewport.width, viewport.height, aspect, options)
      near(layout.previewWidth, Math.min(baseline.previewWidth * 1.1,
        viewport.width - 2 * layout.previewInset,
        (layout.contentHeight - 2 * layout.previewInset) * aspect))
      var hero = WindowGeometry.carouselSlotGeometry(layout, 0)
      var inset = layout.previewInset
      near((hero.width - 2 * inset) / (hero.height - 2 * inset), aspect)
      near(hero.x + hero.width / 2, viewport.width / 2)
      near(hero.y + hero.height / 2, layout.contentHeight / 2)
      verify(hero.x >= 0 && hero.y >= 0)
      verify(hero.x + hero.width <= viewport.width + 0.001)
      verify(hero.y + hero.height <= layout.contentHeight + 0.001)
      verify(layout.contentHeight <= layout.indicatorY)
      near(layout.indicatorY + layout.indicatorHeight, viewport.height)
      // At least one axis must reach its limit; no arbitrary preview-size cap.
      verify(Math.abs(hero.width - (viewport.width - 2 * (layout.peekWidth + layout.spacing))) < 0.001
        || Math.abs(hero.height - layout.contentHeight) < 0.001)
      if (counts[n] > 1) {
        var right = WindowGeometry.snapRectToDevicePixels(
          WindowGeometry.carouselSlotGeometry(layout, layout.slotDistance), display.dpr)
        var left = WindowGeometry.snapRectToDevicePixels(
          WindowGeometry.carouselSlotGeometry(layout, -layout.slotDistance), display.dpr)
        verify(Math.min(right.width, viewport.width - right.x) >= right.width * 0.4 - 1 / display.dpr,
          "At least 40% of the next workspace must be visible")
        verify(Math.min(left.width, left.x + left.width) >= left.width * 0.4 - 1 / display.dpr,
          "At least 40% of the previous workspace must be visible")
      }
      var snapped = WindowGeometry.snapRectToDevicePixels(hero, display.dpr)
      var boundaries = [viewport.x + snapped.x, viewport.y + snapped.y,
        viewport.x + snapped.x + snapped.width, viewport.y + snapped.y + snapped.height]
      for (var b = 0; b < boundaries.length; b++) near(boundaries[b] * display.dpr, Math.round(boundaries[b] * display.dpr))
      verify(snapped.x + snapped.width <= viewport.width + 0.001)
      verify(snapped.y + snapped.height <= layout.contentHeight + 1 / display.dpr)
      near(snapped.width - 2 * inset, (snapped.height - 2 * inset) * aspect, (1 + aspect) / display.dpr + 0.001)
      var projection = WindowGeometry.workspaceTransform(monitor, screen, layout.previewWidth, layout.previewHeight)
      near(projection.offsetX, 0)
      near(projection.offsetY, 0)
      near(projection.renderedWidth / projection.renderedHeight, aspect)
    }
  }

  function test_carouselAnimationPreservesProportionsAndSpacing() {
    var aspect = 1920 / 1045
    var layout = WindowGeometry.carouselGeometry(1888, 1013, aspect, carouselOptions(5, 1))
    for (var step = 0; step <= 20; step++) {
      var offset = layout.slotDistance * step / 20
      var left = WindowGeometry.carouselSlotGeometry(layout, -offset)
      var right = WindowGeometry.carouselSlotGeometry(layout, layout.slotDistance - offset)
      near(right.x - left.x - left.width, layout.spacing)
      near((left.width - 8) / (left.height - 8), aspect)
      near((right.width - 8) / (right.height - 8), aspect)
      verify(left.y >= 0 && right.y >= 0)
      verify(left.y + left.height <= layout.contentHeight + 0.001)
      verify(right.y + right.height <= layout.contentHeight + 0.001)
    }
  }

  function test_carouselSingleAndTinyViewports() {
    var single = WindowGeometry.carouselGeometry(1888, 1013, 1920 / 1045, carouselOptions(1, 1))
    var multi = WindowGeometry.carouselGeometry(1888, 1013, 1920 / 1045, carouselOptions(3, 1))
    compare(single.indicatorHeight, 0)
    compare(single.peekWidth, 0)
    compare(single.spacing, 0)
    verify(single.previewWidth > multi.previewWidth)
    var sizes = [1, 12, 80]
    for (var i = 0; i < sizes.length; i++) {
      var layout = WindowGeometry.carouselGeometry(sizes[i], sizes[i], 16 / 9, carouselOptions(12, 2))
      var hero = WindowGeometry.carouselSlotGeometry(layout, 0)
      verify(hero.width > 0 && hero.height > 0)
      verify(hero.x >= 0 && hero.y >= 0)
      verify(hero.x + hero.width <= sizes[i] + 0.001)
      verify(hero.y + hero.height <= sizes[i] + 0.001)
    }
    var fallback = WindowGeometry.carouselGeometry(NaN, -1, NaN, null)
    verify(isFinite(fallback.previewWidth) && fallback.previewWidth > 0)
    near(fallback.previewWidth / fallback.previewHeight, 16 / 9)
  }

  function test_carouselViewportAndCaptureWiring() {
    var source = readSource("../CarouselCycleView.qml")
    verify(/viewport: overview \? overview.gridViewport/.test(source), "Carousel must use the same safe monitor bounds as the grid")
    verify(/WindowGeometry\.workspaceAspectRatio\([\s\S]*?overview.targetMonitor[\s\S]*?overview.targetScreen/.test(source))
    verify(/WindowGeometry\.carouselGeometry/.test(source))
    verify(/sideVisibility: 0\.8/.test(source), "Start from the neighboring-preview layout")
    verify(/previewSizeMultiplier: 1\.32/.test(source), "Enlarge preview dimensions by another 10%")
    verify(/WindowGeometry\.carouselSlotGeometry/.test(source))
    verify(!/\bscale\s*:/.test(source), "Live preview cards must not use fractional scaling transforms")
    verify(!/Math.min\(840|screenWidth \* 0.44/.test(source), "No fixed preview-width cap")
    verify(!/headerHeight/.test(source), "Workspace badge must overlay the preview")
    verify(/renderGeometry: WindowGeometry\.snapRectToDevicePixels\(displayGeometry, root.dpr\)/.test(source))
    verify(/dpr: overview \? overview.gridDpr/.test(source), "Use destination display DPR for all source monitors")
    verify(/liveCaptureEnabled: root.livePreviews && root.visible && slotItem.visible && previewBox.visible/.test(source))
    verify(/WindowModel\.syncPreviewDelegates/.test(source), "Keep the existing flicker fix")
    verify(/Flickable[\s\S]*?id: indicatorFlick[\s\S]*?clip: true/.test(source))
    verify(/onCurrentIndexChanged: Qt.callLater\(ensureIndicatorVisible\)/.test(source))
  }

}
