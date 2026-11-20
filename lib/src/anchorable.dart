import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'anchor_target.dart';
import 'connector.dart';
import 'geometry.dart';

/// A bounded coordinate space that one or more [Anchorable]s resolve and draw
/// inside. Put it around the thing you annotate (a chart card, an image,
/// a map). Everything is laid out in this box's local coordinates.
class AnchorScope extends StatefulWidget {
  const AnchorScope({
    super.key,
    required this.child,
    this.annotations = const [],
    this.clipBubbles = false,
  });

  /// The content being annotated.
  final Widget child;

  /// Annotations drawn on top of [child], in this scope's coordinate space.
  final List<Anchorable> annotations;

  /// Whether bubbles are clipped to the scope bounds.
  final bool clipBubbles;

  @override
  State<AnchorScope> createState() => _AnchorScopeState();
}

class _AnchorScopeState extends State<AnchorScope> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      key: _key,
      children: [
        Positioned.fill(child: widget.child),
        for (final a in widget.annotations)
          _AnchorableLayout(scopeKey: _key, spec: a),
      ],
    );
    return widget.clipBubbles ? ClipRect(child: stack) : stack;
  }
}

/// The declarative spec for one annotation. The three pluggable slots carry all
/// the customization: [target] (what to point at), [bubbleBuilder] (any widget
/// for the callout), and [connector] (any painter for the leader).
@immutable
class Anchorable {
  const Anchorable({
    required this.target,
    required this.bubbleBuilder,
    this.connector = const Connector.curve(),
    this.connectorOrigin = BubbleAnchor.auto,
    this.placement = Placement.auto,
    this.arrival = Arrival.auto,
    this.clampToScreen = true,
  });

  final AnchorTarget target;
  final WidgetBuilder bubbleBuilder;
  final Connector connector;
  final BubbleAnchor connectorOrigin;
  final Placement placement;
  final Arrival arrival;
  final bool clampToScreen;
}

/// Measures the bubble, resolves the target each frame, positions the bubble,
/// and paints the connector beneath it.
class _AnchorableLayout extends StatefulWidget {
  const _AnchorableLayout({required this.scopeKey, required this.spec});
  final GlobalKey scopeKey;
  final Anchorable spec;

  @override
  State<_AnchorableLayout> createState() => _AnchorableLayoutState();
}

class _AnchorableLayoutState extends State<_AnchorableLayout> {
  final _bubbleKey = GlobalKey();
  Size? _bubbleSize;

  @override
  void initState() {
    super.initState();
    // Re-resolve after first layout so we know the bubble's measured size, and
    // keep following on every frame (scroll / resize / animation).
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      if (!mounted) return;
      final ro = _bubbleKey.currentContext?.findRenderObject();
      if (ro is RenderBox && ro.hasSize && ro.size != _bubbleSize) {
        setState(() => _bubbleSize = ro.size);
      } else {
        // Trigger a rebuild so a moving target re-resolves.
        setState(() {});
      }
    });
  }

  RenderBox? get _scopeBox {
    final ro = widget.scopeKey.currentContext?.findRenderObject();
    return ro is RenderBox && ro.hasSize ? ro : null;
  }

  @override
  Widget build(BuildContext context) {
    final box = _scopeBox;
    final spec = widget.spec;

    // Offstage measure pass until we know the bubble size.
    if (box == null || _bubbleSize == null) {
      return Offstage(
        child: KeyedSubtree(
          key: _bubbleKey,
          child: Builder(builder: spec.bubbleBuilder),
        ),
      );
    }

    final ctx = AnchorContext(overlaySize: box.size, overlayBox: box);
    final target = spec.target.resolve(ctx);
    if (target == null) return const SizedBox.shrink();

    final size = _bubbleSize!;
    final center = _placeBubble(target, size, box.size, spec);
    final rect = Rect.fromCenter(
        center: center, width: size.width, height: size.height);
    final origin = spec.connectorOrigin.resolve(rect, target);
    final geom = _geometry(origin, target, rect, spec.arrival);

    return Positioned.fill(
      // Let taps fall through the annotation layer to the content below.
      child: IgnorePointer(
        ignoring: true,
        child: Stack(
          children: [
            // connector under the bubble
            Positioned.fill(
              child: CustomPaint(
                painter: _ConnectorPainter(spec.connector, geom),
              ),
            ),
            Positioned(
              left: rect.left,
              top: rect.top,
              child: KeyedSubtree(
                key: _bubbleKey,
                child: Builder(builder: spec.bubbleBuilder),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset _placeBubble(Offset target, Size size, Size scope, Anchorable spec) {
    const pad = 12.0;
    double cx, cy;
    final p = spec.placement;
    if (p.kind == 1 || p.kind == 2) {
      final a = p.angle!;
      final d = p.distance + math.max(size.width, size.height) / 2;
      cx = target.dx + math.cos(a) * d;
      cy = target.dy + math.sin(a) * d;
    } else {
      // auto: choose the side with the most room
      final gap = p.distance;
      final cands = <List<double>>[
        [target.dx, target.dy - gap - size.height / 2],
        [target.dx, target.dy + gap + size.height / 2],
        [target.dx + gap + size.width / 2, target.dy],
        [target.dx - gap - size.width / 2, target.dy],
      ];
      double overflow(List<double> c) {
        final l = c[0] - size.width / 2,
            t = c[1] - size.height / 2,
            r = c[0] + size.width / 2,
            b = c[1] + size.height / 2;
        double o = 0;
        if (l < pad) o += pad - l;
        if (t < pad) o += pad - t;
        if (r > scope.width - pad) o += r - (scope.width - pad);
        if (b > scope.height - pad) o += b - (scope.height - pad);
        return o;
      }

      cands.sort((a, b) => overflow(a).compareTo(overflow(b)));
      cx = cands.first[0];
      cy = cands.first[1];
    }
    if (spec.clampToScreen) {
      cx = cx.clamp(pad + size.width / 2, scope.width - pad - size.width / 2);
      cy = cy.clamp(pad + size.height / 2, scope.height - pad - size.height / 2);
    }
    return Offset(cx, cy);
  }

  ConnectorGeometry _geometry(
      Offset origin, Offset target, Rect rect, Arrival arrival) {
    Offset? bend;
    double arriveAngle;
    if (arrival.isForced) {
      final a = arrival.angle!;
      // bend sits out from the target along the arrival direction, so the final
      // segment (bend -> target) always holds angle `a`.
      bend = Offset(
        target.dx + math.cos(a) * arrival.stub,
        target.dy + math.sin(a) * arrival.stub,
      );
      arriveAngle = math.atan2(target.dy - bend.dy, target.dx - bend.dx);
    } else {
      arriveAngle = math.atan2(target.dy - origin.dy, target.dx - origin.dx);
    }
    final leaveAngle = math.atan2(
      (bend ?? target).dy - origin.dy,
      (bend ?? target).dx - origin.dx,
    );
    return ConnectorGeometry(
      originPoint: origin,
      targetPoint: target,
      bubbleRect: rect,
      leaveAngle: leaveAngle,
      arriveAngle: arriveAngle,
      bendPoint: bend,
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter(this.connector, this.geom);
  final Connector connector;
  final ConnectorGeometry geom;
  @override
  void paint(Canvas canvas, Size size) => connector.paint(canvas, geom);
  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.geom.originPoint != geom.originPoint ||
      old.geom.targetPoint != geom.targetPoint ||
      old.connector != connector;
}
