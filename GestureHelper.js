// Pure JS gesture decision helper for Mirador overview mode transitions.
// Contains threshold evaluation, deadband checking, and one-shot debounce logic
// without depending on QML or Qt types, allowing comprehensive automated unit testing.

.pragma library

// Default pinch threshold: 10% scale divergence from 1.0.
// Requires scale >= 1.10 for pinch-out (spread) or <= 0.90 for pinch-in (squeeze).
var PINCH_THRESHOLD = 0.10;

/**
 * Checks whether the pinch scale represents an outward spread gesture exceeding threshold.
 * @param {number} scale Current scale relative to gesture start (1.0 = neutral).
 * @param {number} [threshold] Optional custom threshold fraction (defaults to PINCH_THRESHOLD).
 * @returns {boolean}
 */
function isPinchOut(scale, threshold) {
  if (typeof scale !== "number" || isNaN(scale) || scale <= 0) return false;
  var th = (typeof threshold === "number" && !isNaN(threshold) && threshold > 0)
    ? threshold
    : PINCH_THRESHOLD;
  return scale >= (1.0 + th);
}

/**
 * Checks whether the pinch scale represents an inward squeeze gesture exceeding threshold.
 * @param {number} scale Current scale relative to gesture start (1.0 = neutral).
 * @param {number} [threshold] Optional custom threshold fraction (defaults to PINCH_THRESHOLD).
 * @returns {boolean}
 */
function isPinchIn(scale, threshold) {
  if (typeof scale !== "number" || isNaN(scale) || scale <= 0) return false;
  var th = (typeof threshold === "number" && !isNaN(threshold) && threshold > 0)
    ? threshold
    : PINCH_THRESHOLD;
  return scale <= (1.0 - th);
}

/**
 * Determines whether a pinch gesture should trigger a mode transition.
 *
 * Invariants:
 * - If gestureTriggered is true, always returns null (enforcing one-shot per gesture).
 * - In "normal" mode: only outward pinch (scale >= 1.0 + threshold) transitions to "focused".
 *   Inward pinch in normal mode is ignored (returns null).
 * - In "focused" mode: only inward pinch (scale <= 1.0 - threshold) transitions to "normal".
 *   Outward pinch in focused mode is ignored (returns null).
 * - Small fluctuations (within 1.0 +/- threshold) are ignored as deadband, preventing accidental
 *   triggers during two-finger scrolling.
 *
 * @param {string} currentMode Current overview mode ("normal" or "focused").
 * @param {number} scale Current gesture scale relative to gesture start.
 * @param {boolean} gestureTriggered Whether a transition was already fired in the ongoing gesture.
 * @param {number} [threshold] Configurable pinch threshold (defaults to PINCH_THRESHOLD).
 * @returns {string|null} Target mode ("normal" or "focused"), or null if no transition should occur.
 */
function shouldTriggerTransition(currentMode, scale, gestureTriggered, threshold) {
  if (gestureTriggered) {
    return null;
  }
  if (typeof scale !== "number" || isNaN(scale) || scale <= 0) {
    return null;
  }

  var th = (typeof threshold === "number" && !isNaN(threshold) && threshold > 0)
    ? threshold
    : PINCH_THRESHOLD;

  if (currentMode === "normal") {
    if (scale >= (1.0 + th)) {
      return "focused";
    }
  } else if (currentMode === "focused") {
    if (scale <= (1.0 - th)) {
      return "normal";
    }
  }

  return null;
}
