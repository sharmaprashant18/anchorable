import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'geometry.dart';

/// Draws the connector between the bubble and the target. Fully pluggable:
/// use a built-in style, or [Connector.custom] with your own painter.
///
/// A painter receives a [ConnectorGeometry] with *both* endpoints and *both*
/// angles already computed, so it only has to draw.
abstract class Connector {
  const Connector();

  void paint(Canvas canvas, ConnectorGeometry geom);

  static const Connector none = _NoneConnector();

  const factory Connector.line({Color color, double width}) = _LineConnector;
  const factory Connector.curve({Color color, double width, double bow}) =
      _CurveConnector;
  const factory Connector.elbow({Color color, double width}) = _ElbowConnector;
  const factory Connector.tapered({Color color, double baseWidth}) =
      _TaperedConnector;
  const factory Connector.dotted(
      {Color color, double width, double dash, double gap}) = _DottedConnector;

  /// Draw the connector however you like.
  const factory Connector.custom(
      void Function(Canvas canvas, ConnectorGeometry geom) painter) =
      _CustomConnector;
}

// A connector that honors a forced arrival angle routes bubble->bend with its
// own style, then draws a straight bend->target stub. This mixin centralizes it.
mixin _ArrivalAware on Connector {
  void drawBody(Canvas canvas, Offset from, Offset to, Paint paint);

  @override
  void paint(Canvas canvas, ConnectorGeometry g) {
    final paint = _basePaint();
    if (g.bendPoint != null) {
      drawBody(canvas, g.originPoint, g.bendPoint!, paint);
      canvas.drawLine(g.bendPoint!, g.targetPoint, paint);
    } else {
      drawBody(canvas, g.originPoint, g.targetPoint, paint);
    }
    canvas.drawCircle(g.targetPoint, 3, Paint()..color = paint.color);
  }

  Paint _basePaint();
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..strokeWidth = w
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

const _defaultColor = Color(0xFFFFB454);

class _NoneConnector extends Connector {
  const _NoneConnector();
  @override
  void paint(Canvas canvas, ConnectorGeometry geom) {}
}

class _LineConnector extends Connector with _ArrivalAware {
  const _LineConnector({this.color = _defaultColor, this.width = 2});
  final Color color;
  final double width;
  @override
  Paint _basePaint() => _stroke(color, width);
  @override
  void drawBody(Canvas canvas, Offset from, Offset to, Paint paint) =>
      canvas.drawLine(from, to, paint);
}

class _CurveConnector extends Connector with _ArrivalAware {
  const _CurveConnector(
      {this.color = _defaultColor, this.width = 2, this.bow = 18});
  final Color color;
  final double width;
  final double bow;
  @override
  Paint _basePaint() => _stroke(color, width);
  @override
  void drawBody(Canvas canvas, Offset from, Offset to, Paint paint) {
    final mid = (from + to) / 2;
    var n = Offset(-(to.dy - from.dy), to.dx - from.dx);
    final double len = n.distance == 0 ? 1.0 : n.distance;
    n = n / len * bow;
    final ctrl = mid + n;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
    canvas.drawPath(path, paint);
  }
}

class _ElbowConnector extends Connector with _ArrivalAware {
  const _ElbowConnector({this.color = _defaultColor, this.width = 2});
  final Color color;
  final double width;
  @override
  Paint _basePaint() => _stroke(color, width);
  @override
  void drawBody(Canvas canvas, Offset from, Offset to, Paint paint) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(from.dx, to.dy)
      ..lineTo(to.dx, to.dy);
    canvas.drawPath(path, paint);
  }
}

class _TaperedConnector extends Connector {
  const _TaperedConnector({this.color = _defaultColor, this.baseWidth = 7});
  final Color color;
  final double baseWidth;
  @override
  void paint(Canvas canvas, ConnectorGeometry g) {
    final start = g.originPoint;
    final end = g.bendPoint ?? g.targetPoint;
    final ang = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final perp = ang + math.pi / 2;
    final p1 = start + Offset(math.cos(perp), math.sin(perp)) * baseWidth;
    final p2 = start - Offset(math.cos(perp), math.sin(perp)) * baseWidth;
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(end.dx, end.dy)
      ..close();
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
    if (g.bendPoint != null) {
      canvas.drawLine(g.bendPoint!, g.targetPoint, _stroke(color, 2));
    }
  }
}

class _DottedConnector extends Connector with _ArrivalAware {
  const _DottedConnector(
      {this.color = _defaultColor,
      this.width = 2.5,
      this.dash = 2,
      this.gap = 6});
  final Color color;
  final double width, dash, gap;
  @override
  Paint _basePaint() => _stroke(color, width);
  @override
  void drawBody(Canvas canvas, Offset from, Offset to, Paint paint) {
    final total = (to - from).distance;
    final dir = total == 0 ? Offset.zero : (to - from) / total;
    double d = 0;
    while (d < total) {
      final a = from + dir * d;
      final b = from + dir * math.min(d + dash, total);
      canvas.drawLine(a, b, paint);
      d += dash + gap;
    }
  }
}

class _CustomConnector extends Connector {
  const _CustomConnector(this.painter);
  final void Function(Canvas canvas, ConnectorGeometry geom) painter;
  @override
  void paint(Canvas canvas, ConnectorGeometry geom) => painter(canvas, geom);
}
