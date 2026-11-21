// Vista AR: la traiettoria, i punti cardinali e le linee di elevazione
// disegnati sopra l'immagine della fotocamera, orientati con i sensori del
// telefono (accelerometro e magnetometro).

import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../app_state.dart';
import '../astro.dart';
import '../models.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/clock_chip.dart';
import 'trajectory_view.dart' show tonightDate;

class ArScreen extends StatefulWidget {
  const ArScreen({super.key, required this.state, required this.target, required this.day});

  final AppState state;
  final SkyTarget target;
  final DateTime day;

  @override
  State<ArScreen> createState() => _ArScreenState();
}

/// Orientamento del telefono: versori est, nord e alto espressi negli assi
/// del dispositivo (x verso destra, y verso l'alto dello schermo, z verso chi guarda).
class DevicePose {
  const DevicePose(this.east, this.north, this.up);
  final List<double> east;
  final List<double> north;
  final List<double> up;

  /// Dai vettori grezzi di accelerometro e magnetometro. Null se i dati non
  /// bastano a definire l'orientamento.
  static DevicePose? fromSensors(List<double> acc, List<double> mag) {
    final double an = _norm(acc);
    if (an < 1e-6) return null;
    final List<double> up = <double>[acc[0] / an, acc[1] / an, acc[2] / an];
    List<double> east = _cross(mag, up);
    final double en = _norm(east);
    if (en < 1e-6) return null;
    east = <double>[east[0] / en, east[1] / en, east[2] / en];
    final List<double> north = _cross(up, east);
    return DevicePose(east, north, up);
  }

  static double _norm(List<double> v) => math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
  static List<double> _cross(List<double> a, List<double> b) =>
      <double>[a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];

  /// Componenti nel dispositivo di una direzione del cielo (azimut magnetico).
  List<double> toDevice(double altDeg, double azMagDeg) {
    final double alt = altDeg * kDeg, az = azMagDeg * kDeg;
    final double e = math.sin(az) * math.cos(alt), n = math.cos(az) * math.cos(alt), u = math.sin(alt);
    return <double>[
      east[0] * e + north[0] * n + up[0] * u,
      east[1] * e + north[1] * n + up[1] * u,
      east[2] * e + north[2] * n + up[2] * u,
    ];
  }

  /// Direzione in cui guarda la fotocamera posteriore (asse -z): altezza e azimut magnetico.
  Horizontal get lookingAt {
    final double e = -east[2], n = -north[2], u = -up[2];
    return Horizontal(math.asin(u.clamp(-1.0, 1.0)) / kDeg, norm360(math.atan2(e, n) / kDeg));
  }
}

/// Quale asse dei sensori punta verso l'alto dello schermo: +y, +x, -y o -x.
///
/// Android dà accelerometro e bussola negli assi del corpo del telefono, ma
/// sui pieghevoli lo schermo interno può essere ruotato di 90° rispetto a
/// quegli assi. Invece di fidarsi della rotazione dichiarata dal sistema, si
/// guarda la gravità: chi usa la vista AR tiene il telefono con la parte alta
/// dello schermo rivolta verso il cielo.
enum ScreenUp { plusY, plusX, minusY, minusX }

/// Proietta un vettore negli assi dei sensori sugli assi dello schermo
/// (destra, alto, profondità davanti alla fotocamera posteriore).
List<double> deviceToScreen(List<double> d, ScreenUp up) {
  switch (up) {
    case ScreenUp.plusY:
      return <double>[d[0], d[1], -d[2]];
    case ScreenUp.plusX:
      return <double>[-d[1], d[0], -d[2]];
    case ScreenUp.minusY:
      return <double>[-d[0], -d[1], -d[2]];
    case ScreenUp.minusX:
      return <double>[d[1], -d[0], -d[2]];
  }
}

/// Asse dei sensori più allineato con la verticale, se la gravità nel piano
/// dello schermo è abbastanza forte da deciderlo senza ambiguità.
ScreenUp? screenUpFromGravity(List<double> acc) {
  final double x = acc[0], y = acc[1];
  final double inPlane = math.sqrt(x * x + y * y);
  if (inPlane < 3.0) return null; // telefono quasi orizzontale: non si decide
  if (y.abs() >= 0.8 * inPlane) return y > 0 ? ScreenUp.plusY : ScreenUp.minusY;
  if (x.abs() >= 0.8 * inPlane) return x > 0 ? ScreenUp.plusX : ScreenUp.minusX;
  return null; // telefono inclinato di traverso: si tiene la scelta precedente
}

class _ArScreenState extends State<ArScreen> {
  CameraController? _camera;
  String? _cameraNote;
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  final List<double> _acc = <double>[0, 0, 0];
  final List<double> _mag = <double>[0, 0, 0];
  bool _hasAcc = false, _hasMag = false;
  String? _sensorNote;
  DateTime _lastPaint = DateTime.fromMillisecondsSinceEpoch(0);
  late List<TrackPoint> _track;
  late int _clockSeen = widget.state.clockVersion;
  bool _showTuning = false;
  ScreenUp _screenUp = ScreenUp.plusY;
  ScreenUp? _candidateUp;
  int _candidateCount = 0;

  static const double _alpha = 0.12; // filtro passa-basso sui sensori

  @override
  void initState() {
    super.initState();
    final AppSettings s = widget.state.settings;
    _track = computeTrack(positionJ2000: widget.target.position, latDeg: s.lat, lonDeg: s.lon, day: widget.day);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
    _startCamera();
    _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (AccelerometerEvent e) {
        _blend(_acc, e.x, e.y, e.z, _hasAcc);
        _hasAcc = true;
        _updateScreenUp();
        _requestPaint();
      },
      onError: (Object _) => _noSensors(),
      cancelOnError: true,
    );
    _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (MagnetometerEvent e) {
        _blend(_mag, e.x, e.y, e.z, _hasMag);
        _hasMag = true;
      },
      onError: (Object _) => _noSensors(),
      cancelOnError: true,
    );
  }

  void _blend(List<double> v, double x, double y, double z, bool started) {
    if (!started) {
      v[0] = x;
      v[1] = y;
      v[2] = z;
      return;
    }
    v[0] += _alpha * (x - v[0]);
    v[1] += _alpha * (y - v[1]);
    v[2] += _alpha * (z - v[2]);
  }

  /// Cambia l'asse "alto" solo dopo circa mezzo secondo di letture concordi,
  /// così un movimento brusco non fa ruotare la scena.
  void _updateScreenUp() {
    final ScreenUp? up = screenUpFromGravity(_acc);
    if (up == null || up == _screenUp) {
      _candidateUp = null;
      _candidateCount = 0;
      return;
    }
    if (up == _candidateUp) {
      _candidateCount++;
    } else {
      _candidateUp = up;
      _candidateCount = 1;
    }
    if (_candidateCount >= 25) {
      _screenUp = up;
      _candidateUp = null;
      _candidateCount = 0;
    }
  }

  void _noSensors() {
    if (mounted) setState(() => _sensorNote = 'Questo telefono non espone accelerometro o bussola: la vista AR non può orientarsi.');
  }

  void _requestPaint() {
    final DateTime now = DateTime.now();
    if (now.difference(_lastPaint).inMilliseconds < 33 || !mounted) return;
    _lastPaint = now;
    setState(() {});
  }

  Future<void> _startCamera() async {
    try {
      final List<CameraDescription> cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _cameraNote = 'Nessuna fotocamera disponibile: sfondo nero.');
        return;
      }
      final CameraDescription back = cams.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final CameraController c = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_requestPaint);
      setState(() => _camera = c);
    } catch (e) {
      if (mounted) setState(() => _cameraNote = 'Fotocamera non disponibile (permesso negato o occupata): sfondo nero.');
    }
  }

  @override
  void dispose() {
    _accSub?.cancel();
    _magSub?.cancel();
    _camera?.removeListener(_requestPaint);
    _camera?.dispose();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings s = widget.state.settings;
    final CameraController? cam = _camera;
    final DevicePose? pose = _hasAcc && _hasMag ? DevicePose.fromSensors(_acc, _mag) : null;
    final Size screen = MediaQuery.sizeOf(context);
    // Schermo quasi quadrato = pieghevole aperto; stretto e lungo = chiuso.
    final bool open = screen.shortestSide / screen.longestSide > 0.7;
    final double compassOffset = s.compassOffsetFor(open: open);
    final Size? shown = cam != null && cam.value.isInitialized ? _shownPreview(cam, screen) : null;
    // Altezza in pixel di tutta l'immagine della fotocamera come appare sullo
    // schermo (può uscire dai bordi): il campo della fotocamera si riferisce a quella.
    final double frameHeight = shown?.height ?? screen.height;
    if (widget.state.clockVersion != _clockSeen) {
      // Ora simulata impostata o tolta: traiettoria della notte di quel momento.
      _clockSeen = widget.state.clockVersion;
      _track = computeTrack(positionJ2000: widget.target.position, latDeg: s.lat, lonDeg: s.lon, day: tonightDate(widget.state.now()));
    }
    final DateTime now = widget.state.now();
    final double jd = julianDate(now);
    final Equatorial p = widget.target.position(jd);
    final Horizontal target = altAzJ2000(p.ra, p.dec, jd, s.lat, s.lon);
    final Horizontal? look = pose?.lookingAt;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (cam != null && cam.value.isInitialized) _preview(cam),
          if (pose != null)
            CustomPaint(
              painter: _ArPainter(
                pose: pose,
                screenUp: _screenUp,
                fovDeg: s.cameraFov,
                frameHeight: frameHeight,
                compassOffset: compassOffset,
                track: _track,
                window: s.window,
                target: target,
                title: widget.target.title,
              ),
              size: Size.infinite,
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Indietro',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(widget.target.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            Text(
                              target.alt > 0
                                  ? '${widget.state.simulatingTime ? 'Alle ${fmtTime(now)}' : 'Adesso'}: ${cardinal(target.az)} · azimut ${target.az.round() % 360}° · elevazione ${target.alt.round()}°'
                                  : '${widget.state.simulatingTime ? 'Alle ${fmtTime(now)}' : 'Adesso'} è sotto l\'orizzonte (${target.alt.round()}°)',
                              style: const TextStyle(color: AppColors.amber, fontSize: 12.5),
                            ),
                            if (look != null)
                              Text(
                                'Stai puntando: ${cardinal(look.az + compassOffset)} · azimut ${norm360(look.az + compassOffset).round() % 360}° · elevazione ${look.alt.round()}°',
                                style: const TextStyle(color: AppColors.ink, fontSize: 12.5),
                              ),
                            ClockChip(state: widget.state, compact: true),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Taratura',
                        onPressed: () => setState(() => _showTuning = !_showTuning),
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_sensorNote != null) _banner(_sensorNote!),
                if (_cameraNote != null) _banner(_cameraNote!),
                if (pose == null && _sensorNote == null) _banner('In attesa dei sensori… muovi il telefono descrivendo un otto per tarare la bussola.'),
                if (_showTuning) _tuning(s, open),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lati dell'immagine della fotocamera nell'orientamento dello schermo.
  Size? _previewAspect(CameraController cam) {
    final Size? size = cam.value.previewSize;
    if (size == null) return null;
    // previewSize è riferito al sensore (lato lungo orizzontale): con lo
    // schermo verticale si scambiano i lati.
    final bool portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return portrait ? Size(size.height, size.width) : size;
  }

  /// Dimensioni con cui l'immagine della fotocamera viene disegnata per
  /// riempire lo schermo (BoxFit.cover): una parte esce dai bordi.
  Size? _shownPreview(CameraController cam, Size screen) {
    final Size? a = _previewAspect(cam);
    if (a == null || a.width <= 0 || a.height <= 0) return null;
    final double k = math.max(screen.width / a.width, screen.height / a.height);
    return Size(a.width * k, a.height * k);
  }

  Widget _preview(CameraController cam) {
    final Size? a = _previewAspect(cam);
    if (a == null) return CameraPreview(cam);
    final double w = a.width;
    final double h = a.height;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: w, height: h, child: CameraPreview(cam)),
      ),
    );
  }

  Widget _banner(String text) => Container(
        color: Colors.black.withValues(alpha: 0.6),
        padding: const EdgeInsets.all(10),
        child: Text(text, style: const TextStyle(color: AppColors.ink, fontSize: 13)),
      );

  Widget _tuning(AppSettings s, bool open) {
    final double offset = s.compassOffsetFor(open: open);
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Correzione bussola, telefono ${open ? 'aperto' : 'chiuso'}: ${fmt(offset)}°', style: const TextStyle(fontSize: 13)),
          Slider(
            value: offset.clamp(-30.0, 30.0),
            min: -30,
            max: 30,
            divisions: 120,
            label: '${fmt(offset)}°',
            onChanged: (double v) => setState(() => s.setCompassOffset(v, open: open)),
            onChangeEnd: (_) => s.save(),
          ),
          Text('Campo della fotocamera (lato lungo): ${s.cameraFov.round()}°', style: const TextStyle(fontSize: 13)),
          Slider(
            value: s.cameraFov.clamp(35.0, 100.0),
            min: 35,
            max: 100,
            divisions: 65,
            label: '${s.cameraFov.round()}°',
            onChanged: (double v) => setState(() => s.cameraFov = v),
            onChangeEnd: (_) => s.save(),
          ),
          const Text(
            'Punta la Luna o una stella brillante che riconosci: regola la bussola finché le direzioni coincidono, '
            'e il campo finché la distanza tra due riferimenti corrisponde a quella reale. '
            'Telefono chiuso e aperto hanno correzioni separate: dopo averlo aperto o chiuso, muovilo descrivendo un otto.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ArPainter extends CustomPainter {
  _ArPainter({
    required this.pose,
    required this.screenUp,
    required this.fovDeg,
    required this.frameHeight,
    required this.compassOffset,
    required this.track,
    required this.window,
    required this.target,
    required this.title,
  });

  final DevicePose pose;
  final ScreenUp screenUp;
  final double fovDeg;
  final double frameHeight;
  final double compassOffset;
  final List<TrackPoint> track;
  final SkyWindow window;
  final Horizontal target;
  final String title;

  late Size _size;
  late double _focal;

  /// Componenti (destra, alto, profondità) rispetto allo schermo come è ruotato adesso.
  List<double> _screenVec(double alt, double azTrue) {
    return deviceToScreen(pose.toDevice(alt, azTrue - compassOffset), screenUp);
  }

  /// Punto sullo schermo, oppure null se la direzione è dietro la fotocamera.
  Offset? _project(double alt, double azTrue) {
    final List<double> v = _screenVec(alt, azTrue);
    if (v[2] < 0.08) return null;
    return Offset(_size.width / 2 + _focal * v[0] / v[2], _size.height / 2 - _focal * v[1] / v[2]);
  }

  bool _near(Offset o) => o.dx > -_size.width && o.dx < 2 * _size.width && o.dy > -_size.height && o.dy < 2 * _size.height;

  void _polyline(Canvas canvas, List<Offset?> pts, Paint paint) {
    for (int i = 0; i + 1 < pts.length; i++) {
      final Offset? a = pts[i], b = pts[i + 1];
      if (a == null || b == null || !_near(a) || !_near(b)) continue;
      canvas.drawLine(a, b, paint);
    }
  }

  void _text(Canvas canvas, String s, Offset at, {Color color = AppColors.ink, double size = 12, FontWeight weight = FontWeight.w600}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight, shadows: const <Shadow>[Shadow(blurRadius: 3)]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    // Il campo della fotocamera copre l'intera immagine, che con lo schermo
    // quasi quadrato del pieghevole aperto esce in alto e in basso.
    _focal = (frameHeight / 2) / math.tan(fovDeg * kDeg / 2);

    final Paint horizon = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2;
    final Paint ring = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final Paint limit = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2;

    // Orizzonte e cerchi di elevazione.
    for (int alt = 0; alt <= 75; alt += 15) {
      final List<Offset?> pts = <Offset?>[for (int az = 0; az <= 360; az += 3) _project(alt.toDouble(), az.toDouble())];
      _polyline(canvas, pts, alt == 0 ? horizon : ring);
    }
    // Limiti di altezza del sito, solo nel settore utile.
    for (final double alt in <double>[window.altMin, window.altMax]) {
      if (alt <= 0 || alt >= 90) continue;
      final List<Offset?> pts = <Offset?>[
        for (int az = 0; az <= 360; az += 3) azInSector(az.toDouble(), window.azFrom, window.azTo) ? _project(alt, az.toDouble()) : null,
      ];
      _polyline(canvas, pts, limit);
    }
    // Punti cardinali: linee verticali per gli 8 principali, etichette per tutti e 16.
    for (int i = 0; i < 16; i++) {
      final double az = i * 22.5;
      final bool main = i % 2 == 0;
      if (main) {
        final List<Offset?> pts = <Offset?>[for (int alt = 0; alt <= 80; alt += 5) _project(alt.toDouble(), az)];
        _polyline(canvas, pts, ring);
      }
      for (final double alt in main ? <double>[0, 30, 60] : <double>[0]) {
        final Offset? o = _project(alt, az);
        if (o == null || !size.contains(o)) continue;
        final String label = alt == 0 ? kCardinal16[i] : '${kCardinal16[i]} ${alt.round()}°';
        _text(canvas, label, o + const Offset(0, 14), size: main ? (alt == 0 ? 16 : 11) : 11, color: main ? AppColors.ink : AppColors.muted);
      }
    }

    // Traiettoria della notte.
    final Paint nightPaint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2.5;
    final Paint windowPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i + 1 < track.length; i++) {
      final TrackPoint a = track[i], b = track[i + 1];
      if (!a.isNight || !b.isNight || a.alt < 0 || b.alt < 0) continue;
      final Offset? pa = _project(a.alt, a.az), pb = _project(b.alt, b.az);
      if (pa == null || pb == null || !_near(pa) || !_near(pb)) continue;
      final bool inWin = window.contains(a.alt, a.az) && window.contains(b.alt, b.az);
      canvas.drawLine(pa, pb, inWin ? windowPaint : nightPaint);
    }
    for (final TrackPoint p in track) {
      if (p.time.minute != 0 || !p.isNight || p.alt <= 0) continue;
      final Offset? o = _project(p.alt, p.az);
      if (o == null || !size.contains(o)) continue;
      canvas.drawCircle(o, 4, Paint()..color = AppColors.bg);
      canvas.drawCircle(
          o,
          4,
          Paint()
            ..color = AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      _text(canvas, fmtTime(p.time), o + const Offset(0, -14), size: 11);
    }

    // Posizione attuale dell'oggetto, oppure freccia verso di essa.
    final Offset center = size.center(Offset.zero);
    final Offset? cur = target.alt > -5 ? _project(target.alt, target.az) : null;
    if (cur != null && size.contains(cur)) {
      canvas.drawCircle(cur, 16, Paint()..color = AppColors.amber.withValues(alpha: 0.25));
      canvas.drawCircle(
          cur,
          16,
          Paint()
            ..color = AppColors.amber
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      _text(canvas, title, cur + const Offset(0, 30), color: AppColors.amber, size: 12.5);
    } else {
      final List<double> v = _screenVec(target.alt, target.az);
      final double len = math.sqrt(v[0] * v[0] + v[1] * v[1]);
      if (len > 1e-6) {
        final Offset dir = Offset(v[0] / len, -v[1] / len);
        final double r = math.min(size.width, size.height) * 0.32;
        final Offset tip = center + dir * r;
        final Offset base = center + dir * (r - 26);
        final Offset side = Offset(-dir.dy, dir.dx) * 11;
        final Path arrow = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(base.dx + side.dx, base.dy + side.dy)
          ..lineTo(base.dx - side.dx, base.dy - side.dy)
          ..close();
        canvas.drawPath(arrow, Paint()..color = AppColors.amber);
        _text(canvas, 'Gira da questa parte', center + dir * (r - 48), color: AppColors.amber, size: 12);
      }
    }

    // Mirino.
    final Paint cross = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.5;
    canvas.drawLine(center - const Offset(12, 0), center + const Offset(12, 0), cross);
    canvas.drawLine(center - const Offset(0, 12), center + const Offset(0, 12), cross);
  }

  @override
  bool shouldRepaint(_ArPainter old) => true;
}
