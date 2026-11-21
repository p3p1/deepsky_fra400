// Immagine di repertorio di un oggetto, dal Digitized Sky Survey a colori
// (DSS2, STScI/NASA) ritagliata con il servizio hips2fits del CDS di
// Strasburgo. Viene scaricata la prima volta e poi conservata sul telefono,
// così resta disponibile anche senza rete.

import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import '../theme.dart';

const int _w = 640, _h = 480;

/// Campo dell'immagine in gradi (sul lato lungo): l'oggetto con un po' di
/// cielo attorno, oppure tutto il campo del FRA400 con il riduttore.
double referenceFovDeg(DsObject o, {required bool showFrames}) {
  if (showFrames) return kFovReducerW / 60.0 * 1.15;
  final double d = o.major > 0 ? o.major / 60.0 * 1.8 : 0.5;
  return d.clamp(0.15, 6.0);
}

Uri referenceImageUrl(DsObject o, double fovDeg, {bool mirror = false}) => Uri.https(
      mirror ? 'alaskybis.cds.unistra.fr' : 'alasky.cds.unistra.fr',
      '/hips-image-services/hips2fits',
      <String, String>{
        'hips': 'CDS/P/DSS2/color',
        'width': '$_w',
        'height': '$_h',
        'fov': fovDeg.toStringAsFixed(4),
        'projection': 'TAN',
        'coordsys': 'icrs',
        'ra': o.ra.toStringAsFixed(5),
        'dec': o.dec.toStringAsFixed(5),
        'format': 'jpg',
      },
    );

Future<File> _cachedImage(DsObject o, double fovDeg) async {
  final Directory base = await getApplicationSupportDirectory();
  final Directory dir = Directory('${base.path}/repertorio');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final String safe = o.id.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  final File f = File('${dir.path}/${safe}_${(fovDeg * 1000).round()}.jpg');
  if (f.existsSync() && f.lengthSync() > 1000) return f;
  Object? lastError;
  for (final bool mirror in <bool>[false, true]) {
    try {
      final http.Response r = await http.get(referenceImageUrl(o, fovDeg, mirror: mirror)).timeout(const Duration(seconds: 25));
      final String type = r.headers['content-type'] ?? '';
      if (r.statusCode == 200 && type.contains('image') && r.bodyBytes.length > 1000) {
        await f.writeAsBytes(r.bodyBytes, flush: true);
        return f;
      }
      lastError = 'risposta ${r.statusCode}';
    } catch (e) {
      lastError = e;
    }
  }
  throw Exception(lastError ?? 'immagine non disponibile');
}

class ReferenceImage extends StatefulWidget {
  const ReferenceImage({super.key, required this.object});

  final DsObject object;

  @override
  State<ReferenceImage> createState() => _ReferenceImageState();
}

class _ReferenceImageState extends State<ReferenceImage> {
  bool _frames = false;
  late Future<File> _file = _load();

  Future<File> _load() => _cachedImage(widget.object, referenceFovDeg(widget.object, showFrames: _frames));

  void _setFrames(bool v) {
    if (v == _frames) return;
    setState(() {
      _frames = v;
      _file = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final DsObject o = widget.object;
    final double fov = referenceFovDeg(o, showFrames: _frames);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: false, label: Text('Oggetto')),
                  ButtonSegment<bool>(value: true, label: Text('Campo FRA400')),
                ],
                selected: <bool>{_frames},
                showSelectedIcon: false,
                onSelectionChanged: (Set<bool> s) => _setFrames(s.first),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AspectRatio(
                  aspectRatio: _w / _h,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FutureBuilder<File>(
                      future: _file,
                      builder: (BuildContext context, AsyncSnapshot<File> snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const ColoredBox(color: AppColors.bg, child: Center(child: CircularProgressIndicator()));
                        }
                        if (snap.hasError || snap.data == null) {
                          return ColoredBox(
                            color: AppColors.bg,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Text('Immagine non disponibile: serve internet la prima volta.',
                                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                                    TextButton(onPressed: () => setState(() => _file = _load()), child: const Text('Riprova')),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.file(snap.data!, fit: BoxFit.cover, semanticLabel: 'Immagine del Digitized Sky Survey di ${o.title}'),
                            if (_frames) CustomPaint(painter: _FramesOverlay(fovDeg: fov)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _frames
                  ? 'Campo di ${fmt(fov, 1)}° con i riquadri della ASI2600MC: 400 mm (verde acqua) e 280 mm con riduttore (grigio). Nord in alto, est a sinistra.'
                  : 'Campo di ${fov >= 1 ? '${fmt(fov, 1)}°' : '${(fov * 60).round()}′'} centrato sull\'oggetto. Nord in alto, est a sinistra.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const Text(
              'Digitized Sky Survey (STScI/NASA), colori e ritaglio CDS Strasburgo (hips2fits). Immagine fotografica di riferimento, non una ripresa con il tuo setup.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Disegna i campi a 400 mm e 280 mm, in scala con l'immagine.
class _FramesOverlay extends CustomPainter {
  _FramesOverlay({required this.fovDeg});

  final double fovDeg; // campo dell'immagine sul lato lungo

  @override
  void paint(Canvas canvas, Size size) {
    final double pxPerArcmin = size.width / (fovDeg * 60.0);
    void frame(double wArcmin, double hArcmin, Color c) {
      final Rect r = Rect.fromCenter(center: size.center(Offset.zero), width: wArcmin * pxPerArcmin, height: hArcmin * pxPerArcmin);
      canvas.drawRect(
          r,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, size.width / 300));
    }

    frame(kFovReducerW, kFovReducerH, AppColors.muted);
    frame(kFovNativeW, kFovNativeH, AppColors.accent);
  }

  @override
  bool shouldRepaint(_FramesOverlay old) => old.fovDeg != fovDeg;
}
