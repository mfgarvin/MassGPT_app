import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../utils/parish_palette.dart';

/// Scrim strength used by the parish detail header.
const double kHeaderOverlayDarken = 0.45;

/// Presents a parish's seeded stained-glass art.
///
/// Named for the [Hero] it used to wrap. There is no shared-element flight
/// any more — see [build] — but the wrapper is kept so every place that shows
/// a parish's glass still goes through one widget, and so the treatment can be
/// changed in one place.
class ParishGlassHero extends StatelessWidget {
  final String seed;

  /// Parish name for palette inference — see [StainedGlassHeader.patron].
  final String? patron;
  final double borderRadius;
  final double overlayDarken;
  final Widget child;

  const ParishGlassHero({
    super.key,
    required this.seed,
    required this.child,
    this.patron,
    this.borderRadius = 0,
    this.overlayDarken = 0,
  });

  /// No shared-element flight. The parish header now settles in on the detail
  /// page itself (see `_HeaderArtworkSettle` in `parish_detail_page.dart`),
  /// which is why this is a plain wrapper: [StainedGlassHeader] is procedural
  /// and composes from the shorter side of its box, so flying it between a
  /// square chip and a wide header repainted a different panel every frame,
  /// and pinning the size traded that for a pop flight that dived into the
  /// icon before snapping back.
  ///
  /// [borderRadius] and [overlayDarken] are kept because callers pass them and
  /// a future treatment would want them; nothing reads them today.
  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// A generative stained-glass-style abstract painted from a seed string.
///
/// A Chartres-style armature panel: a deep field of glass crossed by a fine
/// diaper pattern, a quatrefoil fleuron tucked into each corner, and a
/// **roundel** at the centre — eight wedges of alternating glass ringed by lead
/// came, with a lighter iron armature outside it.
///
/// The roundel's wedges are offset by half a wedge so that a pane of glass sits
/// on the vertical rather than a lead line; the four wedges sharing the accent
/// colour then land on the axes and read as an upright cross. Nothing in the
/// composition is randomly rotated.
///
/// Colour comes from what the parish is named after — see `parish_palette.dart`.
/// Geometry is deterministic from the seed, so each parish has a stable
/// visual identity.
class StainedGlassHeader extends StatelessWidget {
  /// Stable identity for the *geometry*. Callers pass the parish ID where they
  /// have one, since three parishes in the diocese are called "Saint Mary" and
  /// they must not share a window.
  final String seed;

  /// The parish *name*, from which the palette's patron is inferred. Separate
  /// from [seed] because [seed] is usually an opaque ID like `0689`, which no
  /// patron rule could ever match. Defaults to [seed] for callers that have
  /// only the one string.
  final String? patron;

  /// Bottom-of-image darken applied as a vertical gradient overlay. Higher
  /// values keep an overlaid display title legible across all palettes; the
  /// pale palettes need more, which `headerDarkenFor` supplies.
  final double overlayDarken;

  const StainedGlassHeader({
    super.key,
    required this.seed,
    this.patron,
    this.overlayDarken = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Painted at whatever size it is given — a 44px chip is composed as a
          // square, not centre-cropped out of a wide render. Line weights and
          // the fleuron cutoff scale with that size.
          RepaintBoundary(
            child: CustomPaint(
              painter: _StainedGlassPainter(seed: seed, patron: patron ?? seed),
            ),
          ),
          // Soft vertical fade for header text legibility
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: overlayDarken),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _StainedGlassPainter extends CustomPainter {
  final String seed;
  final String patron;

  _StainedGlassPainter({required this.seed, required this.patron});

  static const Color _lead = Color(0xFF050507);

  Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
  Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;

  /// Tight per-pane variation. The earlier pass scattered hue by ±14° and
  /// saturation by ±16%, which fractured the palette instead of holding it;
  /// these ranges keep a window reading as one piece of glass.
  Color _vary(Color base, math.Random rng) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withHue((hsl.hue + (rng.nextDouble() - 0.5) * 6) % 360)
        .withSaturation((hsl.saturation + (rng.nextDouble() - 0.5) * 0.06).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + (rng.nextDouble() - 0.5) * 0.07).clamp(0.0, 1.0))
        .toColor();
  }

  /// Backlit glass: a light shoulder up and to the left, a shadowed far edge.
  Shader _radialGlass(Color c, Offset center, double r) => RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: [_lighten(c, 0.20), c, _darken(c, 0.24)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));

  Shader _linearGlass(Color c, Rect rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_lighten(c, 0.18), c, _darken(c, 0.22)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

  Offset _polar(Offset c, double r, double a) =>
      Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));

  /// Top dead centre, in canvas angle terms.
  static const double _top = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    // stableHash rather than seed.hashCode: Dart makes no promise that
    // String.hashCode holds across VM versions, and a parish's window must not
    // change because the toolchain moved.
    final rng = math.Random(stableHash(seed));
    // Colour comes from what the parish is named after — see parish_palette.dart.
    final p = paletteForParish(patron);

    final short = math.min(size.width, size.height);
    final lead = math.max(0.5, short / 130);
    // Below this the fleurons only add noise, so the chip drops to field +
    // roundel. This is why the small sizes have to be composed, not cropped.
    final tiny = short < 70;

    // ── Field ───────────────────────────────────────────────────────────────
    canvas.drawRect(Offset.zero & size, Paint()..color = p.deep);

    // Fine diaper — a whisper of the quarry lattice, not a full leaded field.
    final step = short / 7;
    final diaper = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.4, lead * 0.5);
    final h = size.height;
    final firstK = -(h / step).ceil();
    final lastK = ((size.width + h) / step).ceil() + 1;
    final lattice = Path();
    for (var k = firstK; k < lastK; k++) {
      final x = k * step;
      lattice
        ..moveTo(x, 0)
        ..lineTo(x + h, h)
        ..moveTo(x, 0)
        ..lineTo(x - h, h);
    }
    canvas.drawPath(lattice, diaper);

    // ── Corner fleurons ─────────────────────────────────────────────────────
    if (!tiny) {
      final inset = short * 0.13;
      final fr = short * 0.045;
      final fleuron = Paint()..color = p.bright;
      for (final corner in [
        Offset(inset, inset),
        Offset(size.width - inset, inset),
        Offset(inset, size.height - inset),
        Offset(size.width - inset, size.height - inset),
      ]) {
        for (var j = 0; j < 4; j++) {
          final c = _polar(corner, fr * 0.8, _top + j * math.pi / 2);
          canvas.drawCircle(c, fr * 0.7, fleuron);
        }
      }
    }

    final centre = Offset(size.width / 2, size.height / 2);
    final r = short * 0.33;

    // ── Armature ring ───────────────────────────────────────────────────────
    // Deliberately subordinate to the came on the roundel, so the two
    // concentric rings read as a hierarchy rather than a double border.
    canvas.drawCircle(
      centre,
      r * 1.2,
      Paint()
        ..color = _lead.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lead * 1.1,
    );

    // ── Roundel ─────────────────────────────────────────────────────────────
    canvas.drawCircle(centre, r, Paint()..shader = _radialGlass(p.accent, centre, r));

    final came = Paint()
      ..color = _lead.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lead
      ..strokeJoin = StrokeJoin.round;

    // Offset by half a wedge so a pane of glass — not a lead line — sits on the
    // vertical. The four accent wedges then land on the axes as an upright cross.
    const halfWedge = math.pi / 8;
    const sweep = math.pi / 4;
    final roundelRect = Rect.fromCircle(center: centre, radius: r);
    for (var i = 0; i < 8; i++) {
      final a0 = _top - halfWedge + i * sweep;
      final wedge = Path()
        ..moveTo(centre.dx, centre.dy)
        ..arcTo(roundelRect, a0, sweep, false)
        ..close();
      final colour = _vary(i.isOdd ? p.bright : p.accent, rng);
      canvas.drawPath(wedge, Paint()..shader = _linearGlass(colour, roundelRect));
      canvas.drawPath(wedge, came);
    }

    // Hub jewel
    final hub = r * 0.2;
    canvas.drawCircle(centre, hub, Paint()..shader = _radialGlass(p.highlight, centre, hub));
    canvas.drawCircle(centre, hub, came);

    // Lead rim — the heaviest line in the composition
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..color = _lead.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lead * 2,
    );
  }

  @override
  bool shouldRepaint(covariant _StainedGlassPainter old) =>
      old.seed != seed || old.patron != patron;
}
