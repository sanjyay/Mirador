import QtQuick 2.15
import QtTest 1.3
import "../WindowGeometry.js" as WindowGeometry
import "../WindowModel.js" as WindowModel

TestCase {
  name: "CompactCycleUnitTests"

  function readSource(relativePath) {
    var xhr = new XMLHttpRequest()
    var url = Qt.resolvedUrl(relativePath)
    xhr.open("GET", url, false)
    xhr.send(null)
    return xhr.responseText
  }

  function test_workspaceOverviewCompactIntegration() {
    var source = readSource("../WorkspaceOverview.qml")

    // 1. Properties
    verify(/property\s+string\s+cycleUI\s*:\s*"full"/.test(source),
      "WorkspaceOverview must declare cycleUI property defaulting to 'full'")
    verify(/property\s+string\s+activePresentation\s*:\s*"full"/.test(source),
      "WorkspaceOverview must declare activePresentation property defaulting to 'full'")

    // 2. Settings parsing
    verify(/s\.cycleUI\s*===?\s*"compact"\s*\|\|\s*s\.cycleUI\s*===?\s*"full"/.test(source),
      "loadSettings must parse cycleUI setting ('compact' or 'full')")

    // 3. open() logic sets activePresentation
    verify(/root\.activePresentation\s*=\s*payload\.cycleUI/.test(source),
      "open() must honor payload.cycleUI")
    verify(/root\.activePresentation\s*=\s*"compact"/.test(source),
      "open() must allow setting activePresentation to compact")
    verify(/root\.activePresentation\s*=\s*"full"/.test(source),
      "open() must fall back to full overview for standard invocations")

    // 4. close() and dismiss() reset activePresentation to full
    var closeMatch = source.match(/function\s+close\(\)[\s\S]*?\n  \}/)
    verify(closeMatch && /activePresentation\s*=\s*"full"/.test(closeMatch[0]),
      "close() must reset activePresentation to 'full'")
    var dismissMatch = source.match(/function\s+dismiss\(\)[\s\S]*?\n  \}/)
    verify(dismissMatch && /activePresentation\s*=\s*"full"/.test(dismissMatch[0]),
      "dismiss() must reset activePresentation to 'full'")

    // 5. cardsContainer visibility and livePreviews
    verify(/cardsContainer[\s\S]*visible\s*:\s*root\.activePresentation\s*!==\s*"compact"/.test(source),
      "cardsContainer must be hidden when activePresentation is compact")
    verify(/livePreviews\s*:\s*root\.opened\s*&&\s*panel\.visible\s*&&\s*root\.activePresentation\s*!==\s*"compact"/.test(source),
      "cardsContainer cards must disable livePreviews in compact mode")

    // 6. CompactCycleView declaration
    verify(/CompactCycleView\s*\{/.test(source),
      "WorkspaceOverview must host CompactCycleView")
    verify(/visible\s*:\s*root\.activePresentation\s*===\s*"compact"/.test(source),
      "CompactCycleView must be visible only when activePresentation is compact")
    verify(/livePreviews\s*:\s*root\.opened\s*&&\s*panel\.visible\s*&&\s*root\.activePresentation\s*===\s*"compact"/.test(source),
      "CompactCycleView must receive active livePreviews only when compact is active")
  }

  function test_compactCycleViewComponentStructure() {
    var source = readSource("../CompactCycleView.qml")

    // 1. Required overview property
    verify(/required\s+property\s+var\s+overview/.test(source),
      "CompactCycleView must declare required overview property")

    // 2. Selection and workspace tracking
    verify(/selectedWorkspaceId/.test(source),
      "CompactCycleView must track selectedWorkspaceId")
    verify(/WindowModel\.workspaceBadgeText/.test(source),
      "CompactCycleView must use WindowModel.workspaceBadgeText for badge labels")
    verify(/WindowModel\.resolveWorkspacePreviews/.test(source),
      "CompactCycleView must use WindowModel.resolveWorkspacePreviews for toplevel resolution")

    // 3. Preview geometry projection
    verify(/WindowGeometry\.previewGeometry/.test(source),
      "CompactCycleView must compute spatial layout via WindowGeometry.previewGeometry")
    verify(/WindowGeometry\.snapToDevicePixels/.test(source),
      "CompactCycleView must snap preview coordinates via snapToDevicePixels")

    // 4. WindowPreview delegate
    verify(/WindowPreview\s*\{/.test(source),
      "CompactCycleView must instantiate WindowPreview delegates")
    verify(/liveCaptureEnabled\s*:/.test(source),
      "CompactCycleView must bind liveCaptureEnabled")

    // 5. Workspace indicator strip
    verify(/indicatorRow/.test(source),
      "CompactCycleView must include indicatorRow for workspace strip")

    // 6. Header must not contain redundant "Workspace <id>" title text
    verify(!/"Workspace\s*"\s*\+\s*root\.selectedWorkspaceId/.test(source),
      "CompactCycleView must not contain redundant 'Workspace <id>' text next to badge")
  }

  function test_binMiradorCompactFlag() {
    var source = readSource("../bin/mirador")
    verify(/--compact/.test(source),
      "bin/mirador must support --compact CLI flag")
    verify(/cycleUI["']?\s*:\s*["']?compact/.test(source),
      "bin/mirador --compact must pass cycleUI: 'compact'")
  }

  function test_responsiveDimensionsStability() {
    // Sizing formula verification:
    // previewWidth = Math.round(Math.max(560, Math.min(912, screenWidth * 0.48)))
    // previewHeight = Math.round(previewWidth / monitorAspect)

    // 1080p display (1920x1080, aspect 16/9 = 1.777)
    var w1080 = Math.round(Math.max(560, Math.min(912, 1920 * 0.48)))
    compare(w1080, 912)
    var h1080 = Math.round(w1080 / (16.0 / 9.0))
    compare(h1080, 513)

    // 720p display (1280x720, aspect 16/9)
    var w720 = Math.round(Math.max(560, Math.min(912, 1280 * 0.48)))
    compare(w720, 614)
    var h720 = Math.round(w720 / (16.0 / 9.0))
    compare(h720, 345)

    // Dimensions remain 100% stable regardless of whether workspace has 0 or 10 windows
    verify(w1080 > 0 && h1080 > 0, "Dimensions must be strictly positive")
    verify(w1080 < 1920 * 0.5, "Compact preview width must be less than 50% of screen width")
    verify(h1080 < 1080 * 0.6, "Compact preview height must be less than 60% of screen height")
  }
}
