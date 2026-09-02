import 'package:flutter/widgets.dart';

/// Helpers for layouts whose fixed pixel sizes have to survive large system
/// text sizes.
///
/// Flutter scales *text* with the accessibility text size, but a `width: 128`
/// column or a `height: 176` card stays exactly as wide and tall as it was —
/// so at 2× the text grows into a box that didn't, and you get one character
/// per line, a truncated label, or a debug overflow stripe. Anything sized to
/// hold text needs to grow with it.
extension TextScaleLayout on BuildContext {
  /// The viewer's text scale, e.g. 1.0 normally and 2.0 at the largest
  /// Android font setting.
  double get textScale => MediaQuery.textScalerOf(this).scale(1);

  /// [size] grown by the text scale, never past [max].
  ///
  /// The cap is what keeps a scaled column from eating the whole row: a 128px
  /// time column at 2× wants 256px, which is wider than a phone. Past the cap
  /// the text inside wraps, which is a much better failure than overflowing.
  double scaled(double size, {double? max}) {
    final grown = size * textScale;
    return max == null ? grown : (grown > max ? max : grown);
  }

  /// True when text is large enough that side-by-side content should stack
  /// instead — a row that reads fine at 1.0 is unreadable when each half has
  /// half a phone's width and double-height text.
  bool get prefersStackedLayout => textScale >= 1.5;
}
