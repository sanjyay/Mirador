import QtQuick 2.15
import QtTest 1.0
import "../GestureHelper.js" as GestureHelper

TestCase {
  name: "GestureHelperUnitTests"

  function test_pinchThresholdDefaults() {
    compare(GestureHelper.PINCH_THRESHOLD, 0.10, "Default pinch threshold should be 10%")
  }

  function test_isPinchOut() {
    // Neutral
    verify(!GestureHelper.isPinchOut(1.0), "Neutral scale 1.0 is not pinch-out")
    // Minor changes within deadband (< 10%)
    verify(!GestureHelper.isPinchOut(1.04), "1.04 is within deadband")
    verify(!GestureHelper.isPinchOut(1.09), "1.09 is below 10% threshold")
    // At and above threshold
    verify(GestureHelper.isPinchOut(1.10), "1.10 is at 10% threshold")
    verify(GestureHelper.isPinchOut(1.25), "1.25 is above 10% threshold")
    // Inward scaling
    verify(!GestureHelper.isPinchOut(0.90), "0.90 is pinch-in, not pinch-out")
    // Invalid inputs
    verify(!GestureHelper.isPinchOut(null), "null scale should return false")
    verify(!GestureHelper.isPinchOut(undefined), "undefined scale should return false")
    verify(!GestureHelper.isPinchOut(NaN), "NaN scale should return false")
    verify(!GestureHelper.isPinchOut(0), "0 scale should return false")
    verify(!GestureHelper.isPinchOut(-1.5), "Negative scale should return false")
    // Custom threshold
    verify(GestureHelper.isPinchOut(1.16, 0.15), "1.16 exceeds custom 15% threshold")
    verify(!GestureHelper.isPinchOut(1.14, 0.15), "1.14 is below custom 15% threshold")
  }

  function test_isPinchIn() {
    // Neutral
    verify(!GestureHelper.isPinchIn(1.0), "Neutral scale 1.0 is not pinch-in")
    // Minor changes within deadband (< 10%)
    verify(!GestureHelper.isPinchIn(0.96), "0.96 is within deadband")
    verify(!GestureHelper.isPinchIn(0.91), "0.91 is above 0.90 threshold")
    // At and below threshold
    verify(GestureHelper.isPinchIn(0.90), "0.90 is at 10% threshold")
    verify(GestureHelper.isPinchIn(0.75), "0.75 is below 10% threshold")
    // Outward scaling
    verify(!GestureHelper.isPinchIn(1.10), "1.10 is pinch-out, not pinch-in")
    // Invalid inputs
    verify(!GestureHelper.isPinchIn(null), "null scale should return false")
    verify(!GestureHelper.isPinchIn(undefined), "undefined scale should return false")
    verify(!GestureHelper.isPinchIn(NaN), "NaN scale should return false")
    verify(!GestureHelper.isPinchIn(0), "0 scale should return false")
    verify(!GestureHelper.isPinchIn(-0.5), "Negative scale should return false")
    // Custom threshold
    verify(GestureHelper.isPinchIn(0.84, 0.15), "0.84 exceeds custom 15% threshold (<= 0.85)")
    verify(!GestureHelper.isPinchIn(0.86, 0.15), "0.86 is above custom 15% threshold (> 0.85)")
  }

  function test_shouldTriggerTransition_normalMode() {
    // In normal mode, only outward pinch (spread) transitions to focused mode
    compare(GestureHelper.shouldTriggerTransition("normal", 1.0, false), null, "Neutral scale should not trigger")
    compare(GestureHelper.shouldTriggerTransition("normal", 1.05, false), null, "5% spread is below threshold")
    compare(GestureHelper.shouldTriggerTransition("normal", 1.10, false), "focused", "10% spread should trigger focused")
    compare(GestureHelper.shouldTriggerTransition("normal", 1.20, false), "focused", "20% spread should trigger focused")

    // Inward pinch in normal mode must NOT trigger anything
    compare(GestureHelper.shouldTriggerTransition("normal", 0.80, false), null, "Inward pinch in normal mode is ignored")
    compare(GestureHelper.shouldTriggerTransition("normal", 0.50, false), null, "Strong inward pinch in normal mode is ignored")
  }

  function test_shouldTriggerTransition_focusedMode() {
    // In focused mode, only inward pinch (squeeze) transitions to normal mode
    compare(GestureHelper.shouldTriggerTransition("focused", 1.0, false), null, "Neutral scale should not trigger")
    compare(GestureHelper.shouldTriggerTransition("focused", 0.95, false), null, "5% squeeze is below threshold")
    compare(GestureHelper.shouldTriggerTransition("focused", 0.90, false), "normal", "10% squeeze should trigger normal")
    compare(GestureHelper.shouldTriggerTransition("focused", 0.70, false), "normal", "30% squeeze should trigger normal")

    // Outward pinch in focused mode must NOT trigger anything
    compare(GestureHelper.shouldTriggerTransition("focused", 1.20, false), null, "Outward pinch in focused mode is ignored")
    compare(GestureHelper.shouldTriggerTransition("focused", 1.50, false), null, "Strong outward pinch in focused mode is ignored")
  }

  function test_shouldTriggerTransition_oneShotDebounce() {
    var mode = "normal"
    var gestureTriggered = false

    // Step 1: Small motion under threshold
    var target = GestureHelper.shouldTriggerTransition(mode, 1.04, gestureTriggered)
    compare(target, null, "Minor motion under threshold should not fire")

    // Step 2: Scale crosses threshold -> fires transition to focused
    target = GestureHelper.shouldTriggerTransition(mode, 1.12, gestureTriggered)
    compare(target, "focused", "Exceeding threshold fires transition to focused")

    // Consumer applies transition and marks gesture as triggered
    mode = target
    gestureTriggered = true

    // Step 3: Ongoing gesture continues or moves further outward
    target = GestureHelper.shouldTriggerTransition(mode, 1.25, gestureTriggered)
    compare(target, null, "Ongoing gesture must NOT re-trigger (one-shot invariant)")

    // Step 4: Even if user moves fingers inward in the SAME ongoing gesture, do not toggle back!
    target = GestureHelper.shouldTriggerTransition(mode, 0.75, gestureTriggered)
    compare(target, null, "Inward reversal in SAME active gesture must NOT fire until gesture ends")

    // Step 5: User lifts fingers -> gesture resets
    gestureTriggered = false

    // Step 6: Next gesture: user pinches inward to return to normal
    target = GestureHelper.shouldTriggerTransition(mode, 0.88, gestureTriggered)
    compare(target, "normal", "New gesture pinching inward transitions back to normal")

    mode = target
    gestureTriggered = true

    // Step 7: Ongoing gesture ignored again
    target = GestureHelper.shouldTriggerTransition(mode, 0.70, gestureTriggered)
    compare(target, null, "Ongoing gesture ignored")
  }

  function test_shouldTriggerTransition_customThreshold() {
    // 10% threshold
    compare(GestureHelper.shouldTriggerTransition("normal", 1.11, false, 0.10), "focused")
    compare(GestureHelper.shouldTriggerTransition("normal", 1.08, false, 0.10), null)

    // 20% threshold
    compare(GestureHelper.shouldTriggerTransition("focused", 0.85, false, 0.20), null)
    compare(GestureHelper.shouldTriggerTransition("focused", 0.79, false, 0.20), "normal")
  }
}
