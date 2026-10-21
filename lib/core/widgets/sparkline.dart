import 'package:flutter/material.dart';

/// Minimal trend line with a soft gradient fill. Decorative: excluded from
/// semantics (the row's label already states the change).
///
/// Takes doubles because it only draws; convert Decimals at the call site.
class Sparkline extends StatelessWidget {
  const new({
    required this.values,
    required this.color,
    super.key,
    this.strokeWidth = 1.6,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SparklinePainter(values, color, strokeWidth),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  new(this.values, this.color, this.strokeWidth);

  final List<double> values;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    // Inset so the stroke isn't clipped at the extremes.
    final inset = strokeWidth;
    final height = size.height - inset * 2;
    final dx = size.width / (values.length - 1);

    double y(double v) =>
        range == 0 ? height / 2 : height - (v - min) / range * height;
    Offset point(int i) => Offset(i * dx, inset + y(values[i]));

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = point(i);
      line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas
      ..drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      !_sameValues(old.values, values);

  static bool _sameValues(List<double> a, List<double> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
