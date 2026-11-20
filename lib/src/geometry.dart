import 'dart:math' as math;
import 'package:flutter/widgets.dart';

enum BoxSide { top, right, bottom, left }

/// Where on the bubble rectangle the connector attaches.
///
/// `auto` uses the edge point facing the target. The rest let the developer
/// force any corner, any point along an edge, or any point on the box.
@immutable
class BubbleAnchor {
  const BubbleAnchor._(this._u, this._v, this._auto);

  final double? _u; // 0..1 across the box, null in auto mode
  final double? _v;
  final bool _auto;

  static const auto = BubbleAnchor._(null, null, true);

  static const topLeft = BubbleAnchor._(0, 0, false);
  static const topCenter = BubbleAnchor._(0.5, 0, false);
  static const topRight = BubbleAnchor._(1, 0, false);
  static const centerLeft = BubbleAnchor._(0, 0.5, false);
  static const center = BubbleAnchor._(0.5, 0.5, false);
  static const centerRight = BubbleAnchor._(1, 0.5, false);
  static const bottomLeft = BubbleAnchor._(0, 1, false);
  static const bottomCenter = BubbleAnchor._(0.5, 1, false);
  static const bottomRight = BubbleAnchor._(1, 1, false);

  /// A point a fraction [t] (0..1) along [side].
  factory BubbleAnchor.edge(BoxSide side, double t) {
    t = t.clamp(0.0, 1.0);
    switch (side) {
      case BoxSide.top:
        return BubbleAnchor._(t, 0, false);
      case BoxSide.bottom:
        return BubbleAnchor._(t, 1, false);
      case BoxSide.left:
        return BubbleAnchor._(0, t, false);
      case BoxSide.right:
        return BubbleAnchor._(1, t, false);
    }
  }

  /// Any point on the box in normalized box coordinates.
  factory BubbleAnchor.fractional(double u, double v) =>
      BubbleAnchor._(u.clamp(0.0, 1.0), v.clamp(0.0, 1.0), false);

  /// Resolve to a concrete point, given the placed bubble [rect] and the
  /// [target] (used only in auto mode).
  Offset resolve(Rect rect, Offset target) {
    if (_auto) return _edgePointToward(rect, target);
    return Offset(rect.left + _u! * rect.width, rect.top + _v! * rect.height);
  }

  static Offset _edgePointToward(Rect rect, Offset target) {
    final c = rect.center;
    final dx = target.dx - c.dx, dy = target.dy - c.dy;
    if (dx == 0 && dy == 0) return c;
    final sx = (rect.width / 2) / (dx.abs() < 1e-6 ? 1e-6 : dx.abs());
    final sy = (rect.height / 2) / (dy.abs() < 1e-6 ? 1e-6 : dy.abs());
    final s = math.min(sx, sy);
    return Offset(c.dx + dx * s, c.dy + dy * s);
  }
}

/// How the connector arrives at the target.
@immutable
class Arrival {
  const Arrival._(this.angle, this.stub);

  /// Straight from the bubble origin to the target (default).
  static const auto = Arrival._(null, 0);

  /// Force the final segment to arrive along [angle] (radians, screen space:
  /// 0 = →, pi/2 = ↓). [stub] is how long that fixed-angle final segment is.
  factory Arrival.angle(double angle, {double stub = 40}) =>
      Arrival._(angle, stub);

  final double? angle;
  final double stub;

  bool get isForced => angle != null;
}

/// Preferred bubble placement relative to the target.
@immutable
class Placement {
  const Placement._(this.kind, this.angle, this.distance);
  final int kind; // 0 auto, 1 angle, 2 fixed side
  final double? angle;
  final double distance;

  static const auto = Placement._(0, null, 46);

  /// Orbit the target at [angle] radians, [distance] px from the target.
  factory Placement.angle(double angle, {double distance = 70}) =>
      Placement._(1, angle, distance);

  static const top = Placement._(2, -math.pi / 2, 46);
  static const bottom = Placement._(2, math.pi / 2, 46);
  static const left = Placement._(2, math.pi, 46);
  static const right = Placement._(2, 0, 46);
}

/// Everything a connector painter needs — both endpoints and both angles.
@immutable
class ConnectorGeometry {
  const ConnectorGeometry({
    required this.originPoint,
    required this.targetPoint,
    required this.bubbleRect,
    required this.leaveAngle,
    required this.arriveAngle,
    this.bendPoint,
  });

  /// Where the connector leaves the bubble.
  final Offset originPoint;

  /// The resolved target point.
  final Offset targetPoint;

  /// The placed bubble rectangle.
  final Rect bubbleRect;

  /// Angle (radians) the connector leaves the bubble at.
  final double leaveAngle;

  /// Angle (radians) the connector arrives at the target at.
  final double arriveAngle;

  /// When an [Arrival.angle] is forced, the elbow point the path routes
  /// through so the final segment holds [arriveAngle]. Null otherwise.
  final Offset? bendPoint;
}
