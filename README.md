# anchorable

Attach a **fully custom callout to anything** in Flutter — a chart data point, a
region of an image, a map spot, or a coordinate on a `CustomPaint` canvas —
without hand-rolling `CustomPaint` + `Overlay` + position math every time.

The engine owns **geometry only**. Three pluggable slots carry all the look:

| Slot | What it controls | Type |
|------|------------------|------|
| `target` | **what** to point at (any value → a point) | `AnchorTarget` |
| `bubbleBuilder` | **the callout** — any widget | `WidgetBuilder` |
| `connector` | **the leader** — any painter | `Connector` |

Plus full control over the connection itself:

- `connectorOrigin` — where on the bubble the connector attaches: `auto`, any
  corner/edge-center, `BubbleAnchor.edge(side, t)` for a point along a side, or
  `BubbleAnchor.fractional(u, v)` for any point on the box.
- `placement` — `Placement.auto` (most-room side) or `Placement.angle(a, distance:)`
  to orbit the target at any angle.
- `arrival` — `Arrival.auto`, or `Arrival.angle(a, stub:)` to force the connector
  to **arrive at the target from a fixed direction** regardless of bubble position
  (e.g. always drop onto a chart point from straight above).

## The one idea

Every other tooltip/callout package anchors to a **widget**. Here the target is a
**resolver** — a function that turns *your* domain value into a point:

```dart
AnchorTarget.resolver((ctx) {
  // ctx.overlaySize is the AnchorScope's box; convert your value to a point.
  return chart.dataToPixel(x: 7, y: 42.5);
});
```

Return `null` to hide the callout when the target scrolls out of layout.

Built-in resolvers cover the easy cases: `AnchorTarget.widget(key)`,
`AnchorTarget.point(offset, normalized:)`, `AnchorTarget.rect(rect, align:)`.

## Usage

```dart
AnchorScope(
  child: myChart,
  annotations: [
    Anchorable(
      target: AnchorTarget.resolver((ctx) => /* your point */),
      bubbleBuilder: (_) => MyGlassCallout(),      // any widget
      connector: Connector.tapered(),             // any painter
      connectorOrigin: BubbleAnchor.bottomLeft,   // any attach point
      placement: Placement.angle(-math.pi / 3, distance: 64),
      arrival: Arrival.angle(math.pi / 2, stub: 40), // drop in from above
    ),
  ],
)
```

Custom connector — you get both endpoints and both angles:

```dart
Connector.custom((canvas, geom) {
  // geom.originPoint, geom.targetPoint, geom.bendPoint,
  // geom.leaveAngle, geom.arriveAngle, geom.bubbleRect
  final path = Path()..moveTo(geom.originPoint.dx, geom.originPoint.dy);
  // ...draw however you like
  canvas.drawPath(path, myPaint);
});
```

## Status / roadmap

This is a **0.1 skeleton** demonstrating the architecture. Before publishing:

- **Follow mechanism:** the layout currently re-resolves via a persistent frame
  callback (simple, always-correct, but rebuilds each frame). Replace with a
  `LeaderLayer`/`CompositedTransformFollower` pair or a change-gated listenable so
  it only repaints when the target actually moves.
- **Root-overlay mode:** `AnchorScope` keeps bubbles inside a bounded box (good for
  charts). Add an `Overlay`-based mode so a callout can float above scrollables.
- **Bubble rotation:** optional `bubbleRotation` to match a diagonal connector
  (for dimension-label style annotations).
- Arrow heads on connectors, hit-testing / tap callbacks on bubbles, enter/exit
  animations, and golden tests.

## License

MIT — see LICENSE.
