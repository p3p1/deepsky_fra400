// Traiettoria di un oggetto nella notte scelta: grafico, cupola, riepilogo
// e tabella oraria con direzione ed elevazione.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../astro.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/clock_chip.dart';
import '../widgets/sky_charts.dart';
import 'ar_screen.dart';

const int _stepMinutes = 5;

/// La "notte di oggi": prima di mezzogiorno è quella iniziata ieri sera.
DateTime tonightDate([DateTime? now]) {
  final DateTime n = now ?? DateTime.now();
  final DateTime d = DateTime(n.year, n.month, n.day);
  return n.hour < 12 ? d.subtract(const Duration(days: 1)) : d;
}

String nightLabel(DateTime day) {
  final DateTime next = day.add(const Duration(days: 1));
  if (next.month == day.month) return 'Notte ${day.day}–${next.day} ${kMonthsShort[day.month - 1]} ${day.year}';
  return 'Notte ${day.day} ${kMonthsShort[day.month - 1]}–${next.day} ${kMonthsShort[next.month - 1]} ${next.year}';
}

class TrajectoryView extends StatefulWidget {
  const TrajectoryView({super.key, required this.state, required this.target, this.initialDay});

  final AppState state;
  final SkyTarget target;
  final DateTime? initialDay;

  @override
  State<TrajectoryView> createState() => _TrajectoryViewState();
}

class _TrajectoryViewState extends State<TrajectoryView> {
  late DateTime _day = widget.initialDay ?? tonightDate(widget.state.now());
  late int _clockSeen = widget.state.clockVersion;
  bool _dome = false;
  Timer? _timer;
  late DateTime _now = widget.state.now();

  String? _cacheKey;
  List<TrackPoint> _track = const <TrackPoint>[];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = widget.state.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<TrackPoint> _trackFor(double lat, double lon) {
    final String key = '${widget.target.title}|$_day|$lat|$lon';
    if (key != _cacheKey) {
      _track = computeTrack(positionJ2000: widget.target.position, latDeg: lat, lonDeg: lon, day: _day, stepMinutes: _stepMinutes);
      _cacheKey = key;
    }
    return _track;
  }

  Future<void> _pickDay() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040, 12, 31),
      helpText: 'Sera di inizio della notte',
    );
    if (d != null && mounted) setState(() => _day = DateTime(d.year, d.month, d.day));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (BuildContext context, Widget? _) {
        final settings = widget.state.settings;
        if (widget.state.clockVersion != _clockSeen) {
          // Ora simulata impostata o tolta: si passa alla notte di quel momento.
          _clockSeen = widget.state.clockVersion;
          _now = widget.state.now();
          _day = tonightDate(_now);
        }
        final double lat = settings.lat, lon = settings.lon;
        final SkyWindow window = settings.window;
        final List<TrackPoint> track = _trackFor(lat, lon);
        final NightSummary sum = summarizeTrack(track, window, _stepMinutes);
        final DateTime now = _now;
        final bool live = !now.isBefore(track.first.time) && !now.isAfter(track.last.time);

        return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
          final bool wide = box.maxWidth >= 640;
          final Widget chart = _plotCard(
            label: 'Elevazione dell\'oggetto in funzione della direzione, con i punti cardinali',
            height: 290,
            painter: TrackChartPainter(track: track, window: window, now: live ? now : null),
          );
          final Widget dome = _plotCard(
            label: 'Cupola del cielo vista dall\'alto: nord in alto, est a destra, zenit al centro',
            height: wide ? 290 : 340,
            painter: DomePainter(track: track, window: window, now: live ? now : null),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Notte precedente',
                    onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _pickDay,
                      child: Text(nightLabel(_day), textAlign: TextAlign.center),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notte successiva',
                    onPressed: () => setState(() => _day = _day.add(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Text(
                '${settings.siteName} · ${fmt(lat, 4)}° N, ${fmt(lon, 4)}° E'
                '${!settings.isHome && !settings.hasTravelFix ? ' (GPS non ancora letto: uso le coordinate del sito urbano)' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Center(child: ClockChip(state: widget.state)),
              const SizedBox(height: 4),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[Expanded(flex: 5, child: chart), const SizedBox(width: 10), Expanded(flex: 4, child: dome)],
                )
              else ...<Widget>[
                Center(
                  child: SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(value: false, icon: AppIcon('chart', size: 18), label: Text('Grafico')),
                      ButtonSegment<bool>(value: true, icon: AppIcon('dome', size: 18), label: Text('Cupola')),
                    ],
                    selected: <bool>{_dome},
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<bool> s) => setState(() => _dome = s.first),
                  ),
                ),
                const SizedBox(height: 8),
                if (_dome) dome else chart,
              ],
              if (wide || _dome)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Cupola: il centro è lo zenit, il bordo è l\'orizzonte. Nord in alto ed est a destra, come su una bussola tenuta in piano.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),
              _tiles(track, sum, window, lat, lon, live ? now : null),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (BuildContext context) => ArScreen(state: widget.state, target: widget.target, day: _day),
                  )),
                  icon: const AppIcon('ar', size: 20),
                  label: const Text('Vista AR nel cielo'),
                ),
              ),
              const SizedBox(height: 14),
              _hourTable(track, window),
            ],
          );
        });
      },
    );
  }

  Widget _plotCard({required String label, required double height, required CustomPainter painter}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Semantics(
          label: label,
          child: SizedBox(height: height, child: CustomPaint(painter: painter, size: Size.infinite)),
        ),
      ),
    );
  }

  Widget _tiles(List<TrackPoint> track, NightSummary sum, SkyWindow window, double lat, double lon, DateTime? now) {
    final List<Widget> tiles = <Widget>[];
    if (now != null) {
      final double jd = julianDate(now);
      final Equatorial p = widget.target.position(jd);
      final Horizontal h = altAzJ2000(p.ra, p.dec, jd, lat, lon);
      tiles.add(_Tile(
        title: 'Adesso',
        value: h.alt > 0 ? '${cardinal(h.az)} · ${h.alt.round()}°' : 'Sotto l\'orizzonte',
        note: h.alt > 0 ? 'azimut ${h.az.round() % 360}°' : 'altezza ${h.alt.round()}°',
        color: AppColors.amber,
      ));
    }
    final TrackPoint? top = sum.culmination;
    tiles.add(_Tile(
      title: 'Punto più alto di notte',
      value: top == null ? 'Nessuna notte astronomica' : '${fmtTime(top.time)} · ${top.alt.round()}°',
      note: top == null ? '' : 'verso ${cardinalLong(top.az)}',
    ));
    tiles.add(_Tile(
      title: 'Finestra utile',
      value: sum.windowStart == null ? 'Nessuna' : '${fmtTime(sum.windowStart!)}–${fmtTime(sum.windowEnd!)}',
      note: sum.windowStart == null
          ? 'fuori dai limiti del sito'
          : '${fmt(sum.windowHours)} ore tra ${window.altMin.round()}° e ${window.altMax.round()}°',
      color: AppColors.accent,
    ));
    // Luna: frazione illuminata a metà notte e ore sopra l'orizzonte durante la notte.
    final List<TrackPoint> night = track.where((TrackPoint p) => p.isNight).toList();
    if (night.isNotEmpty) {
      final double illum = moonState(julianDate(night[night.length ~/ 2].time)).illumination;
      int up = 0;
      for (final TrackPoint p in night) {
        if (moonAltAz(julianDate(p.time), lat, lon).alt > 0) up++;
      }
      final double hoursUp = up * _stepMinutes / 60.0;
      tiles.add(_Tile(
        title: 'Luna',
        value: 'illuminata al ${(illum * 100).round()}%',
        note: hoursUp < 0.1 ? 'assente per tutta la notte' : 'in cielo per ${fmt(hoursUp)} ore di notte',
      ));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: tiles);
  }

  Widget _hourTable(List<TrackPoint> track, SkyWindow window) {
    final List<TrackPoint> rows = track.where((TrackPoint p) => p.time.minute == 0 && p.isNight && p.alt > 0).toList();
    if (rows.isEmpty) {
      return const Text('Di notte l\'oggetto resta sotto l\'orizzonte.', style: TextStyle(color: AppColors.muted));
    }
    const TextStyle head = TextStyle(color: AppColors.muted, fontSize: 11.5);
    Widget cell(String s, {TextAlign align = TextAlign.left, TextStyle? style}) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8), child: Text(s, textAlign: align, style: style));
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(64),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(72),
        3: FixedColumnWidth(88),
      },
      border: const TableBorder(horizontalInside: BorderSide(color: AppColors.line)),
      children: <TableRow>[
        TableRow(children: <Widget>[
          cell('Ora', style: head),
          cell('Direzione', style: head),
          cell('Azimut', align: TextAlign.right, style: head),
          cell('Elevazione', align: TextAlign.right, style: head),
        ]),
        for (final TrackPoint p in rows)
          TableRow(
            decoration: window.contains(p.alt, p.az) ? BoxDecoration(color: AppColors.accent.withValues(alpha: 0.13)) : null,
            children: <Widget>[
              cell(fmtTime(p.time), style: kMono),
              cell('${cardinal(p.az)} · ${cardinalLong(p.az)}'),
              cell('${p.az.round() % 360}°', align: TextAlign.right, style: kMono),
              cell('${p.alt.round()}°', align: TextAlign.right, style: kMono),
            ],
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.value, required this.note, this.color});

  final String title;
  final String value;
  final String note;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: color ?? AppColors.ink, fontSize: 16, fontWeight: FontWeight.w600)),
              if (note.isNotEmpty) Text(note, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
