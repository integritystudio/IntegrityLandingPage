import 'package:flutter/material.dart';

/// Shared timing and layout constants for widget tests.
///
/// Centralises durations and scroll offsets that appear across multiple test
/// files so they can be updated in one place.

/// Short pump duration to settle animations without waiting for long ones.
const kShortAnimationSettle = Duration(milliseconds: 300);

/// Pump duration long enough for navigation and route transitions to complete.
const kNavigationSettle = Duration(milliseconds: 500);

/// Single-frame pump duration used in scroll loops and pumpFrames.
const kFramePumpDuration = Duration(milliseconds: 100);

/// Default timeout for pumpAndSettleWithTimeout.
const kSettleTimeout = Duration(seconds: 5);

/// Default number of frames pumped by pumpFrames().
const kDefaultFrameCount = 10;

/// Default per-scroll drag delta (logical pixels) for scrollUntilVisible().
const kScrollDelta = 100.0;

/// Maximum drag iterations for scrollUntilVisible() before asserting failure.
const kMaxScrollIterations = 50;

/// Device pixel ratio used in setScreenSize() for deterministic layout.
const kTestDevicePixelRatio = 1.0;

// ---------------------------------------------------------------------------
// Careers page scroll offsets (logical pixels)
// ---------------------------------------------------------------------------

/// Scroll offset to reach the No Open Positions section on the careers page.
const kCareersScrollToNoOpenings = 300.0;

/// Scroll offset to reach mid-page content sections on the careers page.
const kCareersScrollToMidContent = 400.0;

/// Scroll offset to reach the Keep in Touch CTA section on the careers page.
const kCareersScrollToKeepInTouch = 500.0;

/// Scroll offset per step to reach the footer on the careers page (applied twice).
const kCareersScrollToFooterStep = 800.0;

// ---------------------------------------------------------------------------
// Full-page scroll offsets
// ---------------------------------------------------------------------------

/// Scroll offset to reach the Pricing section in a full-page scroll view.
const kScrollToPricingOffset = Offset(0, -5000);

/// Scroll offset to reach the CTA section in a full-page scroll view.
const kScrollToCTAOffset = Offset(0, -6000);
