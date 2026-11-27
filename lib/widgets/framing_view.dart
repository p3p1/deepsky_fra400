// Inquadratura in scala: l'oggetto, disegnato con una forma astratta che
// ricorda il suo aspetto (spirale, ammasso, nube, anello...), dentro i campi
// del FRA400 a 400 mm e con il riduttore a 280 mm. Si ingrandisce con due
// dita o con un doppio tocco, e si apre a tutto schermo.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../theme.dart';

class FramingView extends StatelessWidget {
  const FramingView({super.key, required this.object});

  final DsObject object;

  @override
  Widget build(BuildContext context) {
    final DsObject o = object;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AspectRatio(
              aspectRatio: 300 / 210,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ZoomableFraming(object: o),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: IconButton.filledTonal(
                        tooltip: 'Inquadratura a tutto schermo',
                        icon: const Icon(Icons.fullscreen),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          fullscreenDialog: true,
                          builder: (BuildContext _) => _FramingFullScreen(object: o),
                        )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const FramingLegend(),
        const SizedBox(height: 4),
        Text(
          'Forma indicativa in base al tipo (${o.info.singular.toLowerCase()}) e alle dimensioni del catalogo; '
          'l\'orientamento non è quello reale. Due dita o doppio tocco per ingrandire.',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class FramingLegend extends StatelessWidget {
  const FramingLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Container(width: 14, height: 3, color: c),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]);
    return Wrap(spacing: 14, runSpacing: 4, children: <Widget>[
      item(AppColors.accent, '400 mm nativo'),
      item(AppColors.muted, '280 mm con riduttore'),
    ]);
  }
}

class _ZoomableFraming extends StatefulWidget {
  const _ZoomableFraming({required this.object, this.maxScale = 12});

  final DsObject object;
  final double maxScale;

  @override
  State<_ZoomableFraming> createState() => _ZoomableFramingState();
}

class _ZoomableFramingState extends State<_ZoomableFraming> {
  final TransformationController _ctrl = TransformationController();
  TapDownDetails? _tap;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _doubleTap() {
    if (_ctrl.value.getMaxScaleOnAxis() > 1.01) {
      _ctrl.value = Matrix4.identity();
      return;
    }
    final Offset p = _tap?.localPosition ?? Offset.zero;
    const double z = 4;
    _ctrl.value = Matrix4.diagonal3Values(z, z, 1)..setTranslationRaw(-p.dx * (z - 1), -p.dy * (z - 1), 0);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: GestureDetector(
        onDoubleTapDown: (TapDownDetails d) => _tap = d,
        onDoubleTap: _doubleTap,
        child: InteractiveViewer(
          transformationController: _ctrl,
          minScale: 1,
          maxScale: widget.maxScale,
          child: Semantics(
            label: 'Schema in scala di ${widget.object.title}: oggetto, campo a 400 millimetri e campo con riduttore',
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (BuildContext context, Widget? _) => CustomPaint(
                size: Size.infinite,
                painter: FramingPainter(widget.object, zoom: _ctrl.value.getMaxScaleOnAxis()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FramingFullScreen extends StatelessWidget {
  const _FramingFullScreen({required this.object});

  final DsObject object;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('Inquadratura · ${object.id}')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(child: _ZoomableFraming(object: object, maxScale: 20)),
            const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 12), child: FramingLegend()),
          ],
        ),
      ),
    );
  }
}

/// Disegna campi e oggetto. [zoom] serve a tenere sottili le linee quando
/// si ingrandisce.
class FramingPainter extends CustomPainter {
  FramingPainter(this.o, {this.zoom = 1});

  final DsObject o;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final double span = math.max(kFovReducerW, o.major) * 1.12;
    final double k = size.width / span; // pixel per primo d'arco
    final Offset c = size.center(Offset.zero);
    final double lw = 1.5 / zoom;

    if (o.major > 0) {
      final double a = math.max(1.5, o.major * k / 2); // semiasse maggiore, px
      final double b = math.max(1.5, (o.minor > 0 ? o.minor : o.major) * k / 2);
      final math.Random rnd = math.Random(_seed(o.id));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      // Orientamento non noto: un angolo fisso ma diverso per ogni oggetto.
      if (b < a * 0.95) canvas.rotate((rnd.nextDouble() - 0.5) * 0.6);
      _drawObject(canvas, a, b, rnd, lw);
      canvas.restore();
    }

    void frame(double w, double h, Color color) {
      canvas.drawRect(
        Rect.fromCenter(center: c, width: w * k, height: h * k),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = lw,
      );
    }

    frame(kFovReducerW, kFovReducerH, AppColors.muted);
    frame(kFovNativeW, kFovNativeH, AppColors.accent);
  }

  static int _seed(String s) {
    int h = 17;
    for (final int u in s.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return h;
  }

  void _drawObject(Canvas canvas, double a, double b, math.Random rnd, double lw) {
    switch (o.type) {
      case 'GAL':
        _galaxy(canvas, a, b, rnd);
      case 'GC':
        _globular(canvas, a, b, rnd);
      case 'OC':
      case 'AST':
        _openCluster(canvas, a, b, rnd);
      case 'PN':
        _planetary(canvas, a, b, rnd);
      case 'SNR':
        _remnant(canvas, a, b, rnd, lw);
      case 'DN':
        _dark(canvas, a, b, rnd, lw);
      case 'RN':
        _cloud(canvas, a, b, rnd, const Color(0xFF6FA8FF), 0.30);
        _star(canvas, Offset.zero, math.max(1.2, a * 0.03), Colors.white);
      case 'MIX':
        _cloud(canvas, a, b, rnd, AppColors.ha, 0.30);
        _cloud(canvas, a * 0.55, b * 0.55, rnd, const Color(0xFF6FA8FF), 0.30, offset: Offset(a * 0.25, -b * 0.2));
      default: // EN, NEB e altri: nube irregolare
        _cloud(canvas, a, b, rnd, AppColors.ha, 0.32);
        if (o.type == 'EN' && o.morph.contains('n')) _openCluster(canvas, a * 0.35, b * 0.35, rnd, count: 14);
    }
  }

  // Galassie: spirale, lenticolare/ellittica, o di taglio con banda di polvere.
  void _galaxy(Canvas canvas, double a, double b, math.Random rnd) {
    final String m = o.morph;
    final bool spiral = RegExp(r'S[AB]?[B]?\(?[rs]?.*?\)?[abcdm]').hasMatch(m) && !m.contains('S0');
    final bool edgeOn = b / a < 0.3;
    final Rect r = Rect.fromCenter(center: Offset.zero, width: a * 2, height: b * 2);
    // Alone diffuso.
    canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(colors: <Color>[
          const Color(0xFFFFF1D6).withValues(alpha: 0.85),
          const Color(0xFFE8D9B8).withValues(alpha: 0.35),
          const Color(0xFF9DB4FF).withValues(alpha: 0.0),
        ], stops: const <double>[0.0, 0.35, 1.0])
            .createShader(r),
    );
    if (spiral && !edgeOn) {
      // Due bracci a spirale logaritmica, schiacciati come l'ellisse.
      final Paint arm = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB8C8FF).withValues(alpha: 0.55)
        ..strokeWidth = math.max(1, b * 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, b * 0.05));
      for (int s = 0; s < 2; s++) {
        final Path p = Path();
        for (int i = 0; i <= 60; i++) {
          final double t = i / 60 * 3.2;
          final double rr = 0.18 * math.exp(0.53 * t);
          final double th = t + s * math.pi;
          final Offset q = Offset(math.cos(th) * rr * a, math.sin(th) * rr * b);
          if (rr > 1) break;
          i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(p, arm);
      }
    }
    // Nucleo.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: a * (spiral ? 0.35 : 0.5), height: b * (spiral ? 0.35 : 0.5)),
      Paint()
        ..color = const Color(0xFFFFF4E0).withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, b * 0.12)),
    );
    if (edgeOn) {
      canvas.drawLine(
        Offset(-a * 0.85, 0),
        Offset(a * 0.85, 0),
        Paint()
          ..color = AppColors.bg.withValues(alpha: 0.8)
          ..strokeWidth = math.max(0.8, b * 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.3, b * 0.08)),
      );
    }
  }

  // Globulari: tante stelle addensate verso il centro.
  void _globular(Canvas canvas, double a, double b, math.Random rnd) {
    final double r0 = math.min(a, b);
    canvas.drawCircle(
      Offset.zero,
      r0 * 0.5,
      Paint()
        ..color = const Color(0xFFFFF1D6).withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r0 * 0.3),
    );
    for (int i = 0; i < 380; i++) {
      // Distanza dal centro concentrata verso il nucleo.
      final double d = math.pow(rnd.nextDouble(), 2.2).toDouble() * r0;
      final double th = rnd.nextDouble() * 2 * math.pi;
      _star(canvas, Offset(math.cos(th) * d, math.sin(th) * d), math.max(0.35, r0 * 0.012) * (0.6 + rnd.nextDouble()), const Color(0xFFFFE7C2));
    }
  }

  // Ammassi aperti: stelle sparse, alcune più brillanti.
  void _openCluster(Canvas canvas, double a, double b, math.Random rnd, {int count = 60}) {
    final double base = math.max(0.5, math.min(a, b) * 0.025);
    for (int i = 0; i < count; i++) {
      final double d = math.sqrt(rnd.nextDouble());
      final double th = rnd.nextDouble() * 2 * math.pi;
      final bool bright = rnd.nextDouble() < 0.12;
      _star(canvas, Offset(math.cos(th) * d * a, math.sin(th) * d * b), base * (bright ? 2.2 : 0.6 + rnd.nextDouble()),
          bright ? const Color(0xFFCFE0FF) : Colors.white.withValues(alpha: 0.85));
    }
  }

  // Nebulose planetarie: anello con stella centrale.
  void _planetary(Canvas canvas, double a, double b, math.Random rnd) {
    final Rect r = Rect.fromCenter(center: Offset.zero, width: a * 2, height: b * 2);
    canvas.drawOval(
      r.deflate(a * 0.05),
      Paint()
        ..color = const Color(0xFF5FE3D3).withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, a * 0.15)),
    );
    canvas.drawOval(
      r.deflate(a * 0.18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, a * 0.28)
        ..color = AppColors.ha.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.3, a * 0.08)),
    );
    _star(canvas, Offset.zero, math.max(0.6, a * 0.06), Colors.white);
  }

  // Resti di supernova: archi e filamenti su un guscio.
  void _remnant(Canvas canvas, double a, double b, math.Random rnd, double lw) {
    for (int i = 0; i < 14; i++) {
      final double start = rnd.nextDouble() * 2 * math.pi;
      final double sweep = 0.3 + rnd.nextDouble() * 0.9;
      final double f = 0.75 + rnd.nextDouble() * 0.3;
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: a * 2 * f, height: b * 2 * f),
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(lw, a * 0.03)
          ..color = (i.isEven ? AppColors.ha : const Color(0xFF5FE3D3)).withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.2, a * 0.01)),
      );
    }
  }

  // Nebulose oscure: una zona senza stelle su un fondo stellato.
  void _dark(Canvas canvas, double a, double b, math.Random rnd, double lw) {
    for (int i = 0; i < 260; i++) {
      final Offset p = Offset((rnd.nextDouble() * 2 - 1) * a * 1.6, (rnd.nextDouble() * 2 - 1) * b * 1.6);
      _star(canvas, p, math.max(0.35, a * 0.01) * (0.5 + rnd.nextDouble()), Colors.white.withValues(alpha: 0.7));
    }
    final Path blob = _blobPath(a, b, rnd);
    canvas.drawPath(
      blob,
      Paint()
        ..color = AppColors.bg
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, a * 0.08)),
    );
    canvas.drawPath(
      blob,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lw
        ..color = AppColors.muted.withValues(alpha: 0.5),
    );
  }

  // Nebulose diffuse: più nuvole sfumate sovrapposte, contorno irregolare.
  void _cloud(Canvas canvas, double a, double b, math.Random rnd, Color color, double alpha, {Offset offset = Offset.zero}) {
    for (int i = 0; i < 9; i++) {
      final double th = rnd.nextDouble() * 2 * math.pi;
      final double d = rnd.nextDouble() * 0.55;
      final Offset p = offset + Offset(math.cos(th) * d * a, math.sin(th) * d * b);
      final double rx = a * (0.35 + rnd.nextDouble() * 0.35);
      final double ry = b * (0.35 + rnd.nextDouble() * 0.35);
      canvas.drawOval(
        Rect.fromCenter(center: p, width: rx * 2, height: ry * 2),
        Paint()
          ..color = color.withValues(alpha: alpha * (0.6 + rnd.nextDouble() * 0.6))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, math.min(rx, ry) * 0.45)),
      );
    }
  }

  Path _blobPath(double a, double b, math.Random rnd) {
    final Path p = Path();
    const int n = 14;
    final List<double> rr = <double>[for (int i = 0; i < n; i++) 0.7 + rnd.nextDouble() * 0.35];
    for (int i = 0; i <= n; i++) {
      final double th = i / n * 2 * math.pi;
      final double r = rr[i % n];
      final Offset q = Offset(math.cos(th) * a * r, math.sin(th) * b * r);
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  void _star(Canvas canvas, Offset p, double r, Color c) {
    canvas.drawCircle(p, r, Paint()..color = c);
  }

  @override
  bool shouldRepaint(FramingPainter old) => old.o.id != o.id || old.zoom != zoom;
}
