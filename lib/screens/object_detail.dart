// Scheda di un oggetto: dati di catalogo, inquadratura, filtro, parametri
// di ripresa, punteggio e traiettoria.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'trajectory_view.dart';

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.score, required this.partial, this.big = false});

  final double score;
  final bool partial;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final Color c = scoreColor(score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('${fmt(score)}${partial ? '*' : ''}', style: TextStyle(color: c, fontSize: big ? 26 : 19, fontWeight: FontWeight.w600)),
        Text(verdict(score), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ],
    );
  }
}

/// Dodici barrette: ore utili per notte, mese per mese.
class MonthStrip extends StatelessWidget {
  const MonthStrip({super.key, required this.hours, required this.threshold, this.height = 22, this.width = 84});

  final List<double> hours;
  final double threshold;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mesi utili: ${monthRanges(hours, threshold)}',
      child: SizedBox(width: width, height: height, child: CustomPaint(painter: _MonthPainter(hours, threshold))),
    );
  }
}

class _MonthPainter extends CustomPainter {
  _MonthPainter(this.hours, this.threshold);
  final List<double> hours;
  final double threshold;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width / 12;
    for (int i = 0; i < 12 && i < hours.length; i++) {
      final double h = math.max(2, math.min(1.0, hours[i] / 8.0) * size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * w + 1, size.height - h, w - 2, h), const Radius.circular(1.5)),
        Paint()..color = hours[i] >= threshold ? AppColors.accent : AppColors.line,
      );
    }
  }

  @override
  bool shouldRepaint(_MonthPainter old) => old.hours != hours || old.threshold != threshold;
}

/// Oggetto e campi inquadrati (nativo e con riduttore), in scala.
class _FramePainter extends CustomPainter {
  _FramePainter(this.major, this.minor);
  final double major;
  final double minor;

  @override
  void paint(Canvas canvas, Size size) {
    final double span = math.max(kFovReducerW, major) * 1.12;
    final double k = size.width / span;
    final Offset c = size.center(Offset.zero);
    void frame(double w, double h, Color color) {
      canvas.drawRect(
        Rect.fromCenter(center: c, width: w * k, height: h * k),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    frame(kFovReducerW, kFovReducerH, AppColors.muted);
    frame(kFovNativeW, kFovNativeH, AppColors.accent);
    if (major > 0) {
      final double d = minor > 0 ? minor : major;
      final Rect r = Rect.fromCenter(center: c, width: math.max(3, major * k), height: math.max(3, d * k));
      canvas.drawOval(r, Paint()..color = AppColors.ha.withValues(alpha: 0.22));
      canvas.drawOval(
        r,
        Paint()
          ..color = AppColors.ha
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.major != major || old.minor != minor;
}

class ObjectDetail extends StatefulWidget {
  const ObjectDetail({super.key, required this.state, required this.object, this.initialDay, this.startOnTrack = false});

  final AppState state;
  final DsObject object;
  final DateTime? initialDay;
  final bool startOnTrack;

  @override
  State<ObjectDetail> createState() => _ObjectDetailState();
}

class _ObjectDetailState extends State<ObjectDetail> {
  late bool _track = widget.startOnTrack;

  @override
  Widget build(BuildContext context) {
    final DsObject o = widget.object;
    return ListenableBuilder(
      listenable: widget.state,
      builder: (BuildContext context, Widget? _) {
        final AppState st = widget.state;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ScoreBadge(score: st.scoreOf(o), partial: o.partialData, big: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(o.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        Text('${o.info.singular} · ${o.constellation}', style: const TextStyle(color: AppColors.muted)),
                        Text('AR ${fmtRa(o.ra)} · Dec ${fmtDec(o.dec)} (J2000)', style: kMono.copyWith(fontSize: 12.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(value: false, label: Text('Scheda')),
                    ButtonSegment<bool>(value: true, label: Text('Traiettoria')),
                  ],
                  selected: <bool>{_track},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<bool> s) => setState(() => _track = s.first),
                ),
              ),
              const SizedBox(height: 12),
              if (_track)
                TrajectoryView(
                  key: ValueKey<String>('track-${o.id}'),
                  state: st,
                  target: SkyTarget.fromObject(o),
                  initialDay: widget.initialDay,
                )
              else
                _sheet(st, o),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(title.toUpperCase(), style: const TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
      );

  Widget _facts(List<List<String>> rows) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: <TableRow>[
        for (final List<String> r in rows)
          TableRow(children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 14, bottom: 5),
              child: Text(r[0], style: const TextStyle(color: AppColors.muted, fontSize: 13.5)),
            ),
            Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(r[1], style: const TextStyle(fontSize: 13.5))),
          ]),
      ],
    );
  }

  Widget _sheet(AppState st, DsObject o) {
    final List<double> months = st.monthsOf(o);
    final double thr = st.settings.monthThreshold;
    final List<MapEntry<String, double>> factors = st.factorsOf(o);
    final String formula =
        '10 × ${factors.map((MapEntry<String, double> f) => '${f.key} ${fmt(f.value, 2)}').join(' × ')} = ${fmt(st.scoreOf(o))}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _section('Inquadratura in scala'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: AspectRatio(
                      aspectRatio: 300 / 210,
                      child: Semantics(
                        label: 'Schema in scala: oggetto, campo a 400 millimetri e campo con riduttore',
                        child: CustomPaint(painter: _FramePainter(o.major, o.minor), size: Size.infinite),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Wrap(spacing: 14, children: <Widget>[
                  _Legend(color: AppColors.ha, text: 'Oggetto'),
                  _Legend(color: AppColors.accent, text: '400 mm'),
                  _Legend(color: AppColors.muted, text: '280 mm (riduttore)'),
                ]),
                const SizedBox(height: 6),
                Text(o.cfgLong, style: const TextStyle(fontSize: 13.5)),
                const Text('Lo schema non rappresenta l\'orientamento reale dell\'oggetto.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ),
        _section('Dati di catalogo'),
        _facts(<List<String>>[
          <String>['Tipo', '${o.info.singular} (${o.catalogType})${o.morph.isEmpty ? '' : ' · classe ${o.morph}'}'],
          <String>['Dimensioni', o.major > 0 ? '${o.sizeText} · circa ${fmtThousands(o.pixelsNative)} pixel a 400 mm' : 'non catalogate'],
          <String>['Luminosità', o.brightness ?? 'non catalogata'],
          <String>['Magnitudine', o.mag == null ? 'non catalogata' : '${o.magBand} ${fmt(o.mag!)}'],
          <String>[
            'Distanza',
            o.distance ?? (o.redshift != null ? 'redshift z = ${o.redshift.toString().replaceAll('.', ',')}' : 'non catalogata'),
          ],
          <String>['Altezza massima', '${st.altMaxOf(o).round()}° da ${st.settings.siteName}'],
          <String>['Altre sigle', o.aliases.isEmpty ? 'nessuna' : o.aliases.join(', ')],
          if (o.names.length > 1) <String>['Altri nomi', o.names.skip(1).join(', ')],
        ]),
        for (final String n in o.notes)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(padding: EdgeInsets.only(top: 2, right: 8), child: Icon(Icons.info_outline, size: 16, color: AppColors.amber)),
                Expanded(child: Text(n, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
        _section('Filtro'),
        for (final String f in o.filterLong) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(f, style: const TextStyle(fontSize: 13.5))),
        _section('Parametri di partenza'),
        _facts(o.shooting),
        _section('Ore utili per notte, mese per mese'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (int m = 0; m < 12; m++)
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(months[m] < 0.05 ? '0' : fmt(months[m]),
                        style: kMono.copyWith(fontSize: 10.5, color: months[m] >= thr ? AppColors.accentSoft : AppColors.muted)),
                    Text(kMonthsShort[m], style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Mesi utili da ${st.settings.siteName}: ${monthRanges(months, thr)}.', style: const TextStyle(fontSize: 13.5)),
        _section('Punteggio'),
        Text(formula, style: kMono.copyWith(fontSize: 12.5)),
        if (o.partialData)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('* Dati di catalogo incompleti: il punteggio è prudente.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 14, height: 2, color: color),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}

/// Pagina a tutto schermo con la scheda, usata sugli schermi stretti.
class ObjectPage extends StatelessWidget {
  const ObjectPage({super.key, required this.state, required this.object, this.initialDay, this.startOnTrack = false});

  final AppState state;
  final DsObject object;
  final DateTime? initialDay;
  final bool startOnTrack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(object.id)),
      body: SafeArea(child: ObjectDetail(state: state, object: object, initialDay: initialDay, startOnTrack: startOnTrack)),
    );
  }
}
