// Elenco del catalogo con ricerca, filtri e ordinamento.

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../lists.dart';
import '../models.dart';
import '../settings.dart';
import '../theme.dart';
import 'object_detail.dart';

class CatalogFilters {
  String query = '';
  final Set<String> types = <String>{};
  String filter = ''; // '', 'S', 'U'
  String cfg = ''; // '', 'N', 'R', 'M'
  int? month; // 0..11
  double minScore = 0;
  bool fullOnly = false;
  String sort = 'score';

  int get activeCount =>
      types.length + (filter.isEmpty ? 0 : 1) + (cfg.isEmpty ? 0 : 1) + (month == null ? 0 : 1) + (minScore > 0 ? 1 : 0) + (fullOnly ? 1 : 0);
}

/// Selettore del sito attivo, condiviso da più schermate.
class SiteSwitch extends StatelessWidget {
  const SiteSwitch({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SiteMode>(
      segments: const <ButtonSegment<SiteMode>>[
        ButtonSegment<SiteMode>(value: SiteMode.home, label: Text('Casa')),
        ButtonSegment<SiteMode>(value: SiteMode.travel, label: Text('Trasferta')),
      ],
      selected: <SiteMode>{state.settings.mode},
      showSelectedIcon: false,
      onSelectionChanged: (Set<SiteMode> s) => state.changeSettings((AppSettings a) => a.mode = s.first),
    );
  }
}

class ObjectRow extends StatelessWidget {
  const ObjectRow({super.key, required this.state, required this.object, required this.onTap, this.selected = false, this.trailing});

  final AppState state;
  final DsObject object;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final DsObject o = object;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: selected ? AppColors.accent : AppColors.line),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: <Widget>[
                SizedBox(width: 58, child: ScoreBadge(score: state.scoreOf(o), partial: o.partialData)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                          ListenableBuilder(
                            listenable: state.lists,
                            builder: (BuildContext context, Widget? _) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                for (final ObjectListKind k in state.lists.listsOf(o.id))
                                  Padding(padding: const EdgeInsets.only(left: 4), child: Icon(k.icon, size: 14, color: k.color)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${o.info.singular} · ${o.sizeText} · ${o.filterShort} · ${o.cfgShort}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ?? MonthStrip(hours: state.monthsOf(o), threshold: state.settings.monthThreshold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.state, required this.onOpen, this.selected});

  final AppState state;
  final void Function(DsObject object) onOpen;
  final DsObject? selected;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final CatalogFilters _f = CatalogFilters();
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DsObject> _apply() {
    final AppState st = widget.state;
    final double thr = st.settings.monthThreshold;
    final List<DsObject> out = st.objects.where((DsObject o) {
      if (_f.types.isNotEmpty && !_f.types.contains(o.type)) return false;
      if (_f.filter.isNotEmpty && !o.info.filter.contains(_f.filter)) return false;
      if (_f.cfg.isNotEmpty && o.cfgGroup != _f.cfg) return false;
      if (_f.month != null && st.monthsOf(o)[_f.month!] < thr) return false;
      if (st.scoreOf(o) < _f.minScore) return false;
      if (_f.fullOnly && o.partialData) return false;
      return o.matches(_f.query);
    }).toList();
    switch (_f.sort) {
      case 'name':
        out.sort((DsObject a, DsObject b) => a.id.compareTo(b.id));
      case 'size':
        out.sort((DsObject a, DsObject b) => b.major.compareTo(a.major));
      case 'ra':
        out.sort((DsObject a, DsObject b) => a.ra.compareTo(b.ra));
      default:
        out.sort((DsObject a, DsObject b) {
          final int c = st.scoreOf(b).compareTo(st.scoreOf(a));
          return c != 0 ? c : a.index.compareTo(b.index);
        });
    }
    return out;
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (BuildContext context, StateSetter setSheet) {
          void update(VoidCallback change) {
            setSheet(change);
            setState(() {});
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Tipo di oggetto', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: <Widget>[
                      for (final TypeInfo t in kTypes)
                        FilterChip(
                          label: Text(t.plural),
                          selected: _f.types.contains(t.code),
                          onSelected: (bool on) => update(() => on ? _f.types.add(t.code) : _f.types.remove(t.code)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _dropdown<String>('Filtro', _f.filter, const <String, String>{'': 'Tutti', 'S': 'S200 dual-band', 'U': 'UV/IR-cut (banda larga)'},
                      (String v) => update(() => _f.filter = v)),
                  _dropdown<String>('Inquadratura', _f.cfg, const <String, String>{'': 'Tutte', 'N': 'Nativo 400 mm', 'R': 'Riduttore 280 mm', 'M': 'Mosaico'},
                      (String v) => update(() => _f.cfg = v)),
                  _dropdown<int>(
                    'Mese utile',
                    _f.month ?? -1,
                    <int, String>{-1: 'Qualsiasi', for (int m = 0; m < 12; m++) m: kMonthsLong[m]},
                    (int v) => update(() => _f.month = v < 0 ? null : v),
                  ),
                  _dropdown<String>(
                    'Ordina per',
                    _f.sort,
                    const <String, String>{'score': 'Punteggio', 'name': 'Sigla', 'size': 'Dimensione', 'ra': 'Ascensione retta'},
                    (String v) => update(() => _f.sort = v),
                  ),
                  const SizedBox(height: 8),
                  Text('Punteggio minimo: ${_f.minScore.round()}', style: const TextStyle(fontSize: 13.5)),
                  Slider(
                    value: _f.minScore,
                    min: 0,
                    max: 9,
                    divisions: 9,
                    label: '${_f.minScore.round()}',
                    onChanged: (double v) => update(() => _f.minScore = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo oggetti con dati completi'),
                    value: _f.fullOnly,
                    onChanged: (bool v) => update(() => _f.fullOnly = v),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _dropdown<T>(String label, T value, Map<T, String> options, void Function(T value) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: <DropdownMenuItem<T>>[
          for (final MapEntry<T, String> e in options.entries) DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
        ],
        onChanged: (T? v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (BuildContext context, Widget? _) {
        final AppState st = widget.state;
        final List<DsObject> list = _apply();
        final int good = list.where((DsObject o) => st.scoreOf(o) >= 6).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: 'Cerca per sigla, nome o costellazione',
                      hintText: 'M 31, Velo, Sh2-240…',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _f.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Cancella la ricerca',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                setState(() => _f.query = '');
                              },
                            ),
                    ),
                    onChanged: (String v) => setState(() => _f.query = v),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: <Widget>[
                      SiteSwitch(state: st),
                      OutlinedButton.icon(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.filter_list),
                        label: Text(_f.activeCount == 0 ? 'Filtri' : 'Filtri · ${_f.activeCount}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    st.computing
                        ? 'Calcolo i punteggi per ${st.settings.siteName}…'
                        : '${fmtThousands(list.length)} oggetti su ${fmtThousands(st.objects.length)} · $good con punteggio da 6 in su',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (st.computing) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nessun oggetto con questi filtri. Abbassa il punteggio minimo o togli un filtro.',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int i) {
                        final DsObject o = list[i];
                        return ObjectRow(state: st, object: o, selected: widget.selected?.index == o.index, onTap: () => widget.onOpen(o));
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
