import 'package:flutter/material.dart';
import 'package:anchorable/anchorable.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Anchorable demo',
        theme: ThemeData.dark(useMaterial3: true),
        home: const DemoPage(),
      );
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});
  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  // the chart data — drag the point to see the annotation re-resolve
  final data = <double>[12, 30, 22, 48, 35, 62, 41, 58];
  int selected = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anchorable — chart point example')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: AnchorScope(
            // The chart draws itself; the resolver below converts a DATA index
            // into a pixel inside this scope — the engine knows nothing about
            // charts.
            child: _Chart(data: data, onPick: (i) => setState(() => selected = i)),
            annotations: [
              Anchorable(
                target: AnchorTarget.resolver((ctx) {
                  final s = ctx.overlaySize;
                  const padL = 46.0, padR = 24.0, padT = 24.0, padB = 34.0, maxV = 70.0;
                  final x = padL + (s.width - padL - padR) * selected / (data.length - 1);
                  final y = padT + (s.height - padT - padB) * (1 - data[selected] / maxV);
                  return Offset(x, y);
                }),
                // any widget as the callout
                bubbleBuilder: (_) => _Callout(
                  title: 'Point ${selected + 1}',
                  sub: 'value ${data[selected].toInt()}',
                ),
                // clean defaults: a curved leader, auto placement & origin.
                connector: const Connector.curve(),
                connectorOrigin: BubbleAnchor.auto,
                placement: Placement.auto,
                arrival: Arrival.auto,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.title, required this.sub});
  final String title, sub;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black45)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF1C2330),
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            Text(sub,
                style: const TextStyle(color: Color(0xFF5B6673), fontSize: 11)),
          ],
        ),
      );
}

class _Chart extends StatelessWidget {
  const _Chart({required this.data, required this.onPick});
  final List<double> data;
  final void Function(int) onPick;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) {
        final size = context.size!;
        const padL = 46.0, padR = 24.0;
        final i = ((d.localPosition.dx - padL) /
                ((size.width - padL - padR) / (data.length - 1)))
            .round()
            .clamp(0, data.length - 1);
        onPick(i);
      },
      child: CustomPaint(painter: _ChartPainter(data), child: const SizedBox.expand()),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.data);
  final List<double> data;
  @override
  void paint(Canvas canvas, Size size) {
    const padL = 46.0, padR = 24.0, padT = 24.0, padB = 34.0, maxV = 70.0;
    final grid = Paint()..color = const Color(0xFF2A333F);
    for (var i = 0; i <= 5; i++) {
      final y = padT + (size.height - padT - padB) * i / 5;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), grid);
    }
    final line = Paint()
      ..color = const Color(0xFF3B6FA0)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = padL + (size.width - padL - padR) * i / (data.length - 1);
      final y = padT + (size.height - padT - padB) * (1 - data[i] / maxV);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = const Color(0xFF3B6FA0));
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.data != data;
}
