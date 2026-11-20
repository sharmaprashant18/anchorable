import 'package:flutter/widgets.dart';

/// Context handed to a target when it is asked to resolve.
///
/// [overlaySize] is the size of the coordinate space the annotation is laid out
/// in (the [AnchorScope]'s box, or the screen). Resolvers that work in
/// normalized `0..1` coordinates multiply by this. [overlayBox] is the render
/// box of that same space, so a resolver can convert a global offset into it.
@immutable
class AnchorContext {
  const AnchorContext({
    required this.overlaySize,
    required this.overlayBox,
  });

  final Size overlaySize;
  final RenderBox overlayBox;

  /// Convert a point given in the global coordinate space into overlay-local.
  Offset globalToLocal(Offset global) => overlayBox.globalToLocal(global);
}

/// The one idea of this package: *what to point at* is a resolver, not a widget.
///
/// Implement [resolve] to turn anything — a chart datum, a lat/lng, a vertex
/// index, a pixel on an image — into a point in the overlay's coordinate space.
/// Return `null` when the target is currently off-layout (scrolled away,
/// filtered out); the annotation then hides itself instead of pointing at
/// stale pixels.
abstract class AnchorTarget {
  const AnchorTarget();

  Offset? resolve(AnchorContext ctx);

  /// Open-ended resolver — the escape hatch that makes this "anchor to anything".
  const factory AnchorTarget.resolver(Offset? Function(AnchorContext ctx) fn) =
      _ResolverTarget;

  /// Anchor to a raw point. [normalized] treats [point] as `0..1` of the
  /// overlay size; otherwise it is overlay-local pixels.
  const factory AnchorTarget.point(Offset point, {bool normalized}) =
      _PointTarget;

  /// Anchor to a rectangle (an image region, a cell, a map area). [align]
  /// picks which point of the rect the connector aims at.
  const factory AnchorTarget.rect(Rect rect,
      {bool normalized, Alignment align}) = _RectTarget;

  /// Anchor to a widget identified by [key]. The widget's render box is read
  /// each resolve, so it follows layout, scroll and animation.
  const factory AnchorTarget.widget(GlobalKey key, {Alignment align}) =
      _WidgetTarget;
}

class _ResolverTarget extends AnchorTarget {
  const _ResolverTarget(this._fn);
  final Offset? Function(AnchorContext ctx) _fn;
  @override
  Offset? resolve(AnchorContext ctx) => _fn(ctx);
}

class _PointTarget extends AnchorTarget {
  const _PointTarget(this.point, {this.normalized = false});
  final Offset point;
  final bool normalized;
  @override
  Offset? resolve(AnchorContext ctx) => normalized
      ? Offset(point.dx * ctx.overlaySize.width,
          point.dy * ctx.overlaySize.height)
      : point;
}

class _RectTarget extends AnchorTarget {
  const _RectTarget(this.rect,
      {this.normalized = false, this.align = Alignment.topCenter});
  final Rect rect;
  final bool normalized;
  final Alignment align;
  @override
  Offset? resolve(AnchorContext ctx) {
    final r = normalized
        ? Rect.fromLTWH(
            rect.left * ctx.overlaySize.width,
            rect.top * ctx.overlaySize.height,
            rect.width * ctx.overlaySize.width,
            rect.height * ctx.overlaySize.height,
          )
        : rect;
    return align.withinRect(r);
  }
}

class _WidgetTarget extends AnchorTarget {
  const _WidgetTarget(this.key, {this.align = Alignment.topCenter});
  final GlobalKey key;
  final Alignment align;
  @override
  Offset? resolve(AnchorContext ctx) {
    final ro = key.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return null;
    final topLeft = ctx.overlayBox.globalToLocal(ro.localToGlobal(Offset.zero));
    return align.withinRect(topLeft & ro.size);
  }
}
