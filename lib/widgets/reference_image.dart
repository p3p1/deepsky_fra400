// Immagine di repertorio di un oggetto, letta dal pacchetto offline
// (vedi image_pack.dart). Se il pacchetto non è ancora sul telefono si
// propone di scaricarlo.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../image_pack.dart';
import '../models.dart';
import '../theme.dart';

class ReferenceImage extends StatefulWidget {
  const ReferenceImage({super.key, required this.object, required this.pack});

  final DsObject object;
  final ImagePack pack;

  @override
  State<ReferenceImage> createState() => _ReferenceImageState();
}

class _ReferenceImageState extends State<ReferenceImage> {
  bool _frames = false;
  Future<Uint8List?>? _bytes;
  String? _loadedTag;

  Future<Uint8List?> _load() => widget.pack.imageFor(widget.object.id);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pack,
      builder: (BuildContext context, Widget? _) {
        final ImagePack p = widget.pack;
        if (!p.installed) return _missingPack(p);
        if (_bytes == null || _loadedTag != p.installedTag) {
          _loadedTag = p.installedTag;
          _bytes = _load();
        }
        final PackEntry? e = p.entryFor(widget.object.id);
        if (e == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Per questo oggetto le survey disponibili non hanno un\'immagine utilizzabile.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
          );
        }
        // I riquadri del FRA400 hanno senso solo se l'immagine è abbastanza ampia da contenerli almeno in parte.
        final bool canFrame = e.fovDeg * 60 >= kFovNativeW * 0.6;
        final bool frames = _frames && canFrame;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List?>(
                          future: _bytes,
                          builder: (BuildContext context, AsyncSnapshot<Uint8List?> snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const ColoredBox(color: AppColors.bg, child: Center(child: CircularProgressIndicator()));
                            }
                            final Uint8List? b = snap.data;
                            if (b == null) {
                              return const ColoredBox(
                                color: AppColors.bg,
                                child: Center(child: Text('Immagine non leggibile.', style: TextStyle(color: AppColors.muted))),
                              );
                            }
                            return Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true, semanticLabel: 'Immagine di repertorio di ${widget.object.title}'),
                                if (frames) CustomPaint(painter: _FramesOverlay(fovDeg: e.fovDeg)),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (canFrame)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Mostra il campo del FRA400', style: TextStyle(fontSize: 13.5)),
                    subtitle: const Text('400 mm in verde acqua, 280 mm con riduttore in grigio', style: TextStyle(fontSize: 12)),
                    value: _frames,
                    onChanged: (bool v) => setState(() => _frames = v),
                  ),
                Text(
                  'Campo di ${e.fovDeg >= 1 ? '${fmt(e.fovDeg, 1)}°' : '${(e.fovDeg * 60).round()}′'} centrato sull\'oggetto. Nord in alto, est a sinistra.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  '${packSourceCredit(e.source)} Immagine fotografica di riferimento, non una ripresa con il tuo setup.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _missingPack(ImagePack p) {
    final bool downloading = p.status == PackStatus.downloading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Le immagini di repertorio si scaricano una volta sola per tutti gli oggetti e poi restano sul telefono, anche senza rete.',
                style: TextStyle(fontSize: 13.5)),
            const SizedBox(height: 8),
            if (downloading) ...<Widget>[
              LinearProgressIndicator(value: p.progress > 0 ? p.progress : null),
              const SizedBox(height: 4),
              Text('Scarico… ${(p.progress * 100).round()}%', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ] else
              FilledButton.icon(
                onPressed: p.busy ? null : p.download,
                icon: const Icon(Icons.download),
                label: Text(p.available != null && p.available!.binSize > 0
                    ? 'Scarica le immagini (${fmtMegabytes(p.available!.binSize)})'
                    : 'Scarica le immagini'),
              ),
            if (p.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(p.message!, style: TextStyle(color: p.status == PackStatus.error ? AppColors.q2 : AppColors.muted, fontSize: 12.5)),
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
