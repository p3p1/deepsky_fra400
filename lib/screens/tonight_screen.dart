// "Stanotte": gli oggetti che entrano nella finestra utile del sito nella
// notte scelta, con orari e direzione.

import 'package:flutter/foundation.dart' show compute;
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../astro.dart';
import '../models.dart';
import '../scoring.dart';
import '../theme.dart';
import '../widgets/clock_chip.dart';
import 'catalog_screen.dart';
import 'trajectory_view.dart';

class _Entry {
  const _Entry(this.object, this.hours, this.start, this.end, this.az0, this.alt0, this.az1, this.alt1);
  final DsObject object;
  final double hours;
  final DateTime start;
  final DateTime end;
  final double az0;
  final double alt0;
  final double az1;
  final double alt1;
}

class TonightScreen extends StatefulWidget {
  const TonightScreen({super.key, required this.state, required this.onOpen, this.selected});

  final AppState state;
  final void Function(DsObject object, DateTime day) onOpen;
  final DsObject? selected;

  @override
  State<TonightScreen> createState() => _TonightScreenState();
}

class _TonightScreenState extends State<TonightScreen> {
  late DateTime _day = tonightDate(widget.state.now());
  late int _clockSeen = widget.state.clockVersion;
  double _minScore = 6;
  String? _key;
  bool _busy = false;
  NightResult? _result;

  String _keyNow() {
    final SiteParams s = widget.state.siteParams;
    return '$_day|${s.lat}|${s.lon}|${s.altMin}|${s.altMax}|${s.azFrom}|${s.azTo}';
  }

  Future<void> _ensure() async {
    final String key = _keyNow();
    if (key == _key || _busy || !widget.state.ready) return;
    _busy = true;
    final AppState st = widget.state;
    final NightResult res = await compute(computeNight, NightRequest(st.raList, st.decList, st.siteParams, _day));
    if (!mounted) return;
    setState(() {
      _result = res;
      _key = key;
      _busy = false;
    });
    if (_keyNow() != key) _ensure();
  }

  List<_Entry> _entries() {
    final NightResult? r = _result;
    final AppState st = widget.state;
    if (r == null || r.values.length != st.objects.length * NightResult.stride) return <_Entry>[];
    final List<_Entry> out = <_Entry>[];
    for (final DsObject o in st.objects) {
      final int k = o.index * NightResult.stride;
      final double hours = r.values[k];
      if (hours < 0.5 || st.scoreOf(o) < _minScore) continue;
      out.add(_Entry(
        o,
        hours,
        r.dayStart.add(Duration(minutes: r.values[k + 1].round())),
        r.dayStart.add(Duration(minutes: r.values[k + 2].round())),
        r.values[k + 3],
        r.values[k + 4],
        r.values[k + 5],
        r.values[k + 6],
      ));
    }
    out.sort((_Entry a, _Entry b) {
      final int c = st.scoreOf(b.object).compareTo(st.scoreOf(a.object));
      return c != 0 ? c : b.hours.compareTo(a.hours);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (BuildContext context, Widget? _) {
        final AppState st = widget.state;
        if (st.clockVersion != _clockSeen) {
          // Ora simulata impostata o tolta: si passa alla notte di quel momento.
          _clockSeen = st.clockVersion;
          _day = tonightDate(st.now());
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _ensure());
        final bool stale = _key != _keyNow();
        final List<_Entry> list = stale ? <_Entry>[] : _entries();
        final DateTime midnight = DateTime(_day.year, _day.month, _day.day).add(const Duration(days: 1));
        final double illum = moonState(julianDate(midnight)).illumination;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
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
                        child: Text(nightLabel(_day), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        tooltip: 'Notte successiva',
                        onPressed: () => setState(() => _day = _day.add(const Duration(days: 1))),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      SiteSwitch(state: st),
                      ClockChip(state: st, compact: true),
                      SegmentedButton<double>(
                        segments: const <ButtonSegment<double>>[
                          ButtonSegment<double>(value: 8, label: Text('Da 8')),
                          ButtonSegment<double>(value: 6, label: Text('Da 6')),
                          ButtonSegment<double>(value: 4, label: Text('Da 4')),
                          ButtonSegment<double>(value: 0, label: Text('Tutti')),
                        ],
                        selected: <double>{_minScore},
                        showSelectedIcon: false,
                        onSelectionChanged: (Set<double> s) => setState(() => _minScore = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stale || st.computing
                        ? 'Calcolo la notte per ${st.settings.siteName}…'
                        : '${fmtThousands(list.length)} oggetti nella finestra utile · Luna illuminata al ${(illum * 100).round()}%',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (stale || st.computing) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          stale ? '' : 'Nessun oggetto con questo punteggio entra nella finestra utile in questa notte.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int i) {
                        final _Entry e = list[i];
                        return ObjectRow(
                          state: st,
                          object: e.object,
                          selected: widget.selected?.index == e.object.index,
                          onTap: () => widget.onOpen(e.object, _day),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text('${fmtTime(e.start)}–${fmtTime(e.end)}', style: kMono.copyWith(fontSize: 12.5, color: AppColors.accentSoft)),
                              Text('${cardinal(e.az0)} ${e.alt0.round()}° → ${cardinal(e.az1)} ${e.alt1.round()}°',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                              Text('${fmt(e.hours)} ore', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
