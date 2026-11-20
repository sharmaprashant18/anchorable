/// Anchorable — attach a fully custom callout to anything.
///
/// The target is a pluggable resolver ([AnchorTarget]), the bubble is any
/// widget, and the connector is any painter ([Connector]) that can leave the
/// bubble at any point ([BubbleAnchor]) and arrive at the target from any
/// angle ([Arrival]).
library anchorable;

export 'src/anchor_target.dart';
export 'src/connector.dart';
export 'src/geometry.dart';
export 'src/anchorable.dart';
