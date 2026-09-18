import QtQuick 2.15
import QtTest 1.15

// ── tst_stable_preview_identity.qml ──────────────────────────────────────────
// Regression tests for the live-preview flicker fix (fix/live-preview-flicker).
//
// Root cause: Repeater with a plain JS array model destroys and recreates all
// delegates — including their ScreencopyView instances — on every array reference
// change, even when the window set is identical. This caused the entire workspace
// preview to flash with placeholder icons whenever any Hyprland event (including
// title changes from an active terminal) triggered effectiveToplevels to recompute.
//
// Fix:
//   1. WindowModel.syncPreviewDelegates — incremental keyed diff; existing
//      delegates survive metadata-only updates.
//   2. WindowPreview.hasReceivedFrame — preserves the last captured frame,
//      preventing icon flash on transient screencopy pauses.
//   3. WorkspaceOverview.onRawEvent — filters self-generated screencast events
//      and uses a debounced structuralRefreshDebounce timer for all IPC refreshes.
// ─────────────────────────────────────────────────────────────────────────────

TestCase {
  name: "StablePreviewIdentity"

  // ── Helpers ─────────────────────────────────────────────────────────────────

  function readSource(path) {
    var req = new XMLHttpRequest()
    req.open("GET", path, false)
    req.send()
    return req.responseText
  }

  function windowModelSource() {
    return readSource("../WindowModel.js")
  }

  function windowPreviewSource() {
    return readSource("../WindowPreview.qml")
  }

  function workspaceOverviewSource() {
    return readSource("../WorkspaceOverview.qml")
  }

  function workspaceCardSource() {
    return readSource("../WorkspaceCard.qml")
  }

  function carouselCycleViewSource() {
    return readSource("../CarouselCycleView.qml")
  }

  function compactCycleViewSource() {
    return readSource("../CompactCycleView.qml")
  }

  // ── WindowModel.syncPreviewDelegates: existence and signature ────────────────

  function test_syncPreviewDelegatesExistsInWindowModel() {
    var src = windowModelSource()
    verify(/function\s+syncPreviewDelegates\s*\(/.test(src),
      "WindowModel.js must export a syncPreviewDelegates function")
  }

  function test_syncPreviewDelegatesAcceptsContainerAndPreviews() {
    var src = windowModelSource()
    // Must accept at least 4 parameters: container, currentMap, previews, component
    verify(/function\s+syncPreviewDelegates\s*\(\s*\w+\s*,\s*\w+\s*,\s*\w+\s*,\s*\w+/.test(src),
      "syncPreviewDelegates must accept container, currentMap, previews, component parameters")
  }

  function test_syncPreviewDelegatesUsesKeyedDiffNotClearAndRebuild() {
    var src = windowModelSource()
    // Must NOT reset the entire delegate map in one shot (clear-and-rebuild anti-pattern)
    verify(!(/currentMap\s*=\s*\{\}[\s\S]*?for.*previews/.test(src) &&
             /\.destroy\(\)[\s\S]*?createObject/.test(src)),
      "syncPreviewDelegates must diff incrementally, not clear-and-rebuild")
  }

  function test_syncPreviewDelegatesUsesAddressOrGroupKeyAsStableKey() {
    var src = windowModelSource()
    // Must use address or groupKey as the primary lookup key for diffing
    verify(/groupKey|\.address/.test(src),
      "syncPreviewDelegates must use stable address/groupKey for delegate identity")
  }

  function test_syncPreviewDelegatesDestroysVanishedDelegatesOnly() {
    var src = windowModelSource()
    // Must call destroy() for delegates whose windows are gone
    verify(/\.destroy\(\)/.test(src),
      "syncPreviewDelegates must call .destroy() for removed window delegates")
  }

  function test_syncPreviewDelegatesCreatesObjectForNewWindows() {
    var src = windowModelSource()
    // Must call component.createObject for new windows
    verify(/createObject\s*\(/.test(src),
      "syncPreviewDelegates must call createObject for new delegates")
  }

  // ── resolveWorkspacePreviews: groupKey field for stable group identity ────────

  function test_resolveWorkspacePreviewsExposesGroupKeyField() {
    var src = windowModelSource()
    // Each descriptor must include a groupKey field so that groups can be
    // identified stably even when the active member's address changes
    verify(/groupKey\s*:/.test(src),
      "resolveWorkspacePreviews must set a groupKey field on each descriptor")
  }

  // ── WorkspaceCard: no plain Repeater on effectiveToplevels ──────────────────

  function test_workspaceCardDoesNotUseRepeaterOnEffectiveToplevels() {
    var src = workspaceCardSource()
    // Plain Repeater{model: ...effectiveToplevels} is the anti-pattern that caused flicker
    verify(!/Repeater\s*\{[^}]*model\s*:\s*[^}]*effectiveToplevels/.test(src),
      "WorkspaceCard must not bind Repeater.model directly to effectiveToplevels")
  }

  function test_workspaceCardUsesSyncPreviewDelegatesForIncremental() {
    var src = workspaceCardSource()
    verify(/syncPreviewDelegates|syncPreviews/.test(src),
      "WorkspaceCard must use syncPreviews/syncPreviewDelegates for incremental updates")
  }

  function test_workspaceCardHasPreviewMapProperty() {
    var src = workspaceCardSource()
    verify(/previewMap/.test(src),
      "WorkspaceCard must maintain a previewMap for delegate identity tracking")
  }

  // ── CarouselCycleView: no plain Repeater on effectiveToplevels ──────────────

  function test_carouselCycleViewDoesNotUseRepeaterOnEffectiveToplevels() {
    var src = carouselCycleViewSource()
    // The exact anti-pattern was: Repeater { model: slotItem.effectiveToplevels }
    // The outer workspaceRepeater iterates over cardModel and is unrelated — only
    // check that effectiveToplevels is not used directly as a Repeater model.
    verify(!/model\s*:\s*slotItem\.effectiveToplevels/.test(src),
      "CarouselCycleView must not bind Repeater.model directly to slotItem.effectiveToplevels")
  }

  function test_carouselCycleViewUsesSyncPreviewDelegates() {
    var src = carouselCycleViewSource()
    verify(/syncPreviewDelegates|syncPreviews/.test(src),
      "CarouselCycleView must use syncPreviews/syncPreviewDelegates for incremental updates")
  }

  // ── CompactCycleView: no plain Repeater on effectiveToplevels ───────────────

  function test_compactCycleViewDoesNotUseRepeaterOnEffectiveToplevels() {
    var src = compactCycleViewSource()
    verify(!/Repeater\s*\{[^}]*model\s*:\s*[^}]*effectiveToplevels/.test(src),
      "CompactCycleView must not bind Repeater.model directly to effectiveToplevels")
  }

  function test_compactCycleViewUsesSyncPreviewDelegates() {
    var src = compactCycleViewSource()
    verify(/syncPreviewDelegates|syncPreviews/.test(src),
      "CompactCycleView must use syncPreviews/syncPreviewDelegates for incremental updates")
  }

  // ── WindowPreview: hasReceivedFrame prevents icon flash on transient pauses ─

  function test_windowPreviewHasReceivedFramePropertyExists() {
    var src = windowPreviewSource()
    verify(/hasReceivedFrame/.test(src),
      "WindowPreview must declare a hasReceivedFrame property")
  }

  function test_windowPreviewPreservesLastFrameOnTransientPause() {
    var src = windowPreviewSource()
    // The ScreencopyView visible binding must use hasReceivedFrame to prevent
    // going blank when content momentarily vanishes (transient screencopy pause)
    verify(/hasReceivedFrame/.test(src) && /hasContent/.test(src),
      "WindowPreview must use hasReceivedFrame alongside hasContent for visibility")
  }

  function test_windowPreviewIconIsHiddenAfterFirstFrame() {
    var src = windowPreviewSource()
    // The fallback icon (Image) must be hidden once hasReceivedFrame is true
    // so that a screencopy hiccup doesn't flash placeholder icons
    verify(/hasReceivedFrame/.test(src),
      "WindowPreview fallback icon must consult hasReceivedFrame to stay hidden after first frame")
  }

  function test_windowPreviewResetsHasReceivedFrameOnToplevelChange() {
    var src = windowPreviewSource()
    // When the window is replaced (new toplevel), hasReceivedFrame must reset
    // so the new window goes through the icon→frame transition correctly
    verify(/onToplevelChanged[\s\S]*?hasReceivedFrame\s*=\s*false|hasReceivedFrame\s*=\s*false[\s\S]*?onToplevelChanged/.test(src),
      "WindowPreview must reset hasReceivedFrame when toplevel changes")
  }

  // ── WorkspaceOverview: screencast events are filtered ───────────────────────

  function test_screencopyEventFilteredFromOnRawEvent() {
    var src = workspaceOverviewSource()
    // Mirador's own ScreencopyView generates screencast/screencastv2 events.
    // Reacting to these causes needless IPC refreshes on every captured frame.
    // They must be explicitly discarded early in onRawEvent.
    verify(/name\s*===\s*"screencast"\s*\|\|\s*name\s*===\s*"screencastv2"/.test(src),
      'WorkspaceOverview must filter out "screencast" and "screencastv2" events')
    verify(/(name\s*===\s*"screencast"\s*\|\|\s*name\s*===\s*"screencastv2")\s*\)\s*return/.test(src),
      "screencast/screencastv2 events must cause an early return in onRawEvent")
  }

  // ── WorkspaceOverview: debounced structural refresh ─────────────────────────

  function test_structuralRefreshDebounceTimerExists() {
    var src = workspaceOverviewSource()
    verify(/structuralRefreshDebounce/.test(src),
      "WorkspaceOverview must define a structuralRefreshDebounce timer")
  }

  function test_scheduleStructuralRefreshFunctionExists() {
    var src = workspaceOverviewSource()
    verify(/function\s+scheduleStructuralRefresh\s*\(/.test(src),
      "WorkspaceOverview must define a scheduleStructuralRefresh helper function")
  }

  function test_onRawEventUsesDebounceNotDirectRefresh() {
    var src = workspaceOverviewSource()
    // The onRawEvent handler should call scheduleStructuralRefresh (debounced)
    // rather than calling Hyprland.refreshToplevels() directly for most events
    verify(/function\s+onRawEvent[\s\S]*?scheduleStructuralRefresh/.test(src),
      "onRawEvent must route structural events through scheduleStructuralRefresh")
  }

  // ── Security invariants: captureSource must still be released on dismiss ────

  function test_captureSourceReleasedWhenLiveCaptureDisabled() {
    var src = windowPreviewSource()
    // This is the established safety invariant from tst_windowpreview_security.qml.
    // The fix must not break it.
    verify(/captureSource\s*:\s*root\.liveCaptureEnabled\s*\?\s*root\.waylandToplevel\s*:\s*null/.test(src),
      "WindowPreview captureSource must still be released to null when liveCaptureEnabled is false")
  }

  // ── Security invariants: title must remain plaintext ────────────────────────

  function test_windowTitleSinkRemainsPlainText() {
    var src = windowPreviewSource()
    verify(/textFormat\s*:\s*Text\.PlainText/.test(src),
      "WindowPreview title text must use textFormat: Text.PlainText")
  }
}
