// Scheda di un oggetto: dati di catalogo, inquadratura, filtro, parametri
// di ripresa, punteggio e traiettoria.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../details.dart';
import '../lists.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/framing_view.dart';
import '../widgets/reference_image.dart';
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
                  BookmarkButton(lists: st.lists, objectId: o.id, title: o.title),
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
        _section('Immagine di repertorio'),
        ReferenceImage(key: ValueKey<String>('img-${o.id}'), object: o, pack: st.images),
        _section('L\'oggetto'),
        _AboutObject(object: o, details: st.details.of(o.id)),
        _section('Approfondisci'),
        _SourceLinks(object: o, details: st.details.of(o.id)),
        _section('Inquadratura in scala'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FramingView(key: ValueKey<String>('frame-${o.id}'), object: o),
                const SizedBox(height: 6),
                Text(o.cfgLong, style: const TextStyle(fontSize: 13.5)),
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
          if (o.redshift != null) <String>['Redshift', 'z = ${o.redshift.toString().replaceAll('.', ',')}'],
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
        const SizedBox(height: 6),
        Text('Filtri più usati per questo tipo di oggetto', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final FilterSuggestion f in o.filterSuggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Icon(f.owned ? Icons.check_circle : Icons.filter_alt_outlined, size: 16, color: f.owned ? AppColors.accent : AppColors.muted),
                ),
                Expanded(
                  child: Text.rich(TextSpan(children: <InlineSpan>[
                    TextSpan(text: f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: ' · ${f.kind}\n', style: const TextStyle(color: AppColors.muted)),
                    TextSpan(text: f.why),
                  ]), style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        const Text(
          'Con il riduttore a f/3,9 i filtri a banda molto stretta (5 nm o meno) possono perdere segnale: verifica che il produttore li dichiari adatti a ottiche veloci.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
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


/// Descrizione scientifica: che cos'è, dove si trova, quanto è lontano e grande.
class _AboutObject extends StatefulWidget {
  const _AboutObject({required this.object, required this.details});

  final DsObject object;
  final ObjectDetails? details;

  @override
  State<_AboutObject> createState() => _AboutObjectState();
}

class _AboutObjectState extends State<_AboutObject> {
  bool _wikiOpen = false;

  @override
  Widget build(BuildContext context) {
    final DsObject o = widget.object;
    final ObjectDetails? d = widget.details;
    final List<double> gal = galactic(o.ra, o.dec);

    // Distanza: Wikidata, poi il catalogo, poi (galassie) il redshift.
    double? ly = d?.lightYears;
    String? distText;
    String? distNote;
    if (ly != null && ly > 0) {
      distText = fmtLightYears(ly);
      final List<double>? r = d!.range;
      if (r != null) distNote = 'le stime pubblicate vanno da ${fmtLightYears(r[0])} a ${fmtLightYears(r[1])}';
    } else if (o.distance != null) {
      distText = o.distance!.replaceAll('a.l.', 'anni luce');
      // Formati del catalogo: "2.500 a.l.", "23,5 milioni di a.l.".
      final String digits = (RegExp(r'[0-9.,]+').firstMatch(o.distance!)?.group(0) ?? '').replaceAll('.', '').replaceAll(',', '.');
      final double? v = double.tryParse(digits);
      if (v != null && v > 0) ly = o.distance!.contains('milioni') ? v * 1e6 : v;
    } else {
      final double? z = d?.redshift ?? o.redshift;
      if (z != null && z > 0 && z < 0.1) {
        ly = hubbleDistanceLy(z);
        distText = 'circa ${fmtLightYears(ly)}';
        distNote = 'stimata dal redshift z = ${z.toString().replaceAll('.', ',')} con la legge di Hubble';
      }
    }

    final List<List<String>> rows = <List<String>>[
      <String>['Costellazione', o.constellation],
      if (d != null && d.types.isNotEmpty) <String>['Classificato come', d.types.join(', ')],
      if (d != null && d.partOf.isNotEmpty) <String>['Fa parte di', d.partOf.join(', ')],
      if (distText != null) <String>['Distanza', distNote == null ? distText : '$distText ($distNote)'],
      if (ly != null && ly > 0) <String>['La luce che fotografi', 'è partita circa ${fmtLightYears(ly).replaceAll(' anni luce', ' anni')} fa'],
      if (ly != null && ly > 0 && o.major > 0)
        <String>[
          'Dimensioni reali',
          o.minor > 0 && o.minor < o.major * 0.9
              ? 'circa ${fmtLightYears(realSizeLy(ly, o.major))} × ${fmtLightYears(realSizeLy(ly, o.minor))}'
              : 'circa ${fmtLightYears(realSizeLy(ly, o.major))} di diametro',
        ],
      <String>[
        'Coordinate galattiche',
        'l ${gal[0].toStringAsFixed(1).replaceAll('.', ',')}°, b ${gal[1] >= 0 ? '+' : '−'}${gal[1].abs().toStringAsFixed(1).replaceAll('.', ',')}° · ${galacticNote(gal[1])}',
      ],
    ];
    final String type = typeExplanation(o.type);
    final String? morph = morphExplanation(o);
    final String? wiki = d?.wiki;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (type.isNotEmpty) ...<Widget>[
              Text(o.info.singular, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(type, style: const TextStyle(fontSize: 13.5, height: 1.35)),
              const SizedBox(height: 10),
            ],
            Table(
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
            ),
            if (morph != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(morph, style: const TextStyle(fontSize: 13, height: 1.35)),
            ],
            if (wiki != null) ...<Widget>[
              const Divider(height: 22),
              Text('Da Wikipedia${d!.wikiTitle != null ? ' · ${d.wikiTitle}' : ''}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: Text(
                  wiki,
                  maxLines: _wikiOpen ? null : 5,
                  overflow: _wikiOpen ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ),
              if (wiki.length > 300)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => setState(() => _wikiOpen = !_wikiOpen),
                    child: Text(_wikiOpen ? 'Mostra meno' : 'Leggi tutto'),
                  ),
                ),
              const Text('Testo di Wikipedia in italiano, licenza CC BY-SA 4.0.', style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
            if (d != null && d.lightYears != null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Distanza da Wikidata (valore mediano delle misure pubblicate).', style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Collegamenti a fonti esterne sull'oggetto (si aprono nel browser).
class _SourceLinks extends StatelessWidget {
  const _SourceLinks({required this.object, required this.details});

  final DsObject object;
  final ObjectDetails? details;

  @override
  Widget build(BuildContext context) {
    final DsObject o = object;
    final ObjectDetails? d = details;
    final String id = Uri.encodeQueryComponent(o.id);
    final double fov = math.max(0.25, math.min(10, (o.major > 0 ? o.major : 20) / 60 * 2.5));
    final List<(IconData, String, String, String)> links = <(IconData, String, String, String)>[
      if (d?.wikiTitle != null)
        (Icons.menu_book, 'Wikipedia', 'voce in italiano', 'https://it.wikipedia.org/wiki/${Uri.encodeComponent(d!.wikiTitle!.replaceAll(' ', '_'))}')
      else
        (Icons.menu_book, 'Wikipedia', 'cerca in italiano', 'https://it.wikipedia.org/w/index.php?search=$id'),
      (Icons.language, 'Wikipedia (inglese)', 'spesso più completa', 'https://en.wikipedia.org/w/index.php?search=$id'),
      (Icons.science_outlined, 'SIMBAD', 'banca dati del CDS: misure, bibliografia', 'https://simbad.cds.unistra.fr/simbad/sim-id?Ident=$id'),
      (Icons.travel_explore, 'Aladin Lite', 'atlante del cielo interattivo, molte survey',
          'https://aladin.cds.unistra.fr/AladinLite/?target=${o.ra.toStringAsFixed(4)}%20${o.dec >= 0 ? '%2B' : ''}${o.dec.toStringAsFixed(4)}&fov=${fov.toStringAsFixed(2)}&survey=CDS%2FP%2FDSS2%2Fcolor'),
      if (o.type == 'GAL') (Icons.blur_circular, 'NED', 'database extragalattico NASA/IPAC', 'https://ned.ipac.caltech.edu/byname?objname=$id'),
      if (d?.wikidata != null) (Icons.hub_outlined, 'Wikidata', 'dati strutturati e fonti', 'https://www.wikidata.org/wiki/${d!.wikidata}'),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (final (IconData icon, String title, String sub, String url) in links)
            ListTile(
              leading: Icon(icon, color: AppColors.accent),
              title: Text(title),
              subtitle: Text(sub, style: const TextStyle(fontSize: 12.5)),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                bool ok = false;
                try {
                  ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } catch (_) {}
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non riesco ad aprire il link: serve un browser e la rete.')));
                }
              },
            ),
        ],
      ),
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
