import 'package:flutter/material.dart';

/// Centralized application-wide [ScrollBehavior] for ShadiDriver.
///
/// Ensures a disciplined, luxury ceremonial app feel across all platforms:
/// 1. Clamps scroll boundaries cleanly using [ClampingScrollPhysics] (no elastic bounce).
/// 2. Disables Android 12+ [StretchingOverscrollIndicator] and [GlowingOverscrollIndicator]
///    by returning the child directly.
/// 3. Preserves full native vertical and horizontal scrolling responsiveness.
/// 4. Does not interfere with text fields, dialogs, keyboard insets, or nested scrollables.
class ShadiScrollBehavior extends MaterialScrollBehavior {
  const ShadiScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Return child directly without wrapping in StretchingOverscrollIndicator
    // or GlowingOverscrollIndicator, eliminating edge stretch, pull deformation,
    // and glow globally.
    return child;
  }
}
