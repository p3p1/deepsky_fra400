// Deep Sky FRA400: catalogo, punteggi di fattibilità e traiettorie nel cielo
// per Askar FRA400 e ASI2600MC Pro.

import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'models.dart';
import 'panel/panel.dart' show PanelPage, panelTheme;
import 'screens/catalog_screen.dart';
import 'screens/comets_screen.dart';
import 'screens/lists_screen.dart';
import 'screens/object_detail.dart';
import 'screens/settings_screen.dart';
import 'screens/tonight_screen.dart';
import 'theme.dart';
import 'updater.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeepSkyApp());
}

class DeepSkyApp extends StatefulWidget {
  const DeepSkyApp({super.key});

  @override
  State<DeepSkyApp> createState() => _DeepSkyAppState();
}

class _DeepSkyAppState extends State<DeepSkyApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deep Sky FRA400',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: RootShell(state: _state),
    );
  }
}

/// Le due sezioni dell'app: Deep Sky e Flat panel. Restano entrambe in vita
/// quando si passa dall'una all'altra, così il collegamento Bluetooth al
/// pannello e i calcoli del catalogo non ripartono da capo.
class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.state});

  final AppState state;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _section = 0;

  static const List<String> _labels = <String>['Deep Sky', 'Flat panel'];
  static const List<IconData> _icons = <IconData>[Icons.auto_awesome, Icons.light_mode_outlined];

  @override
  Widget build(BuildContext context) {
    final Widget stack = IndexedStack(
      index: _section,
      children: <Widget>[
        HomeShell(state: widget.state),
        Theme(data: panelTheme(), child: const PanelPage()),
      ],
    );
    final Widget sections = Column(
      children: <Widget>[
        _UpdateBanner(updater: widget.state.updater),
        Expanded(child: stack),
      ],
    );
    final bool wide = MediaQuery.sizeOf(context).width >= kTwoPaneWidth;
    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: <Widget>[
              NavigationRail(
                selectedIndex: _section,
                onDestinationSelected: (int i) => setState(() => _section = i),
                labelType: NavigationRailLabelType.all,
                destinations: <NavigationRailDestination>[
                  for (int i = 0; i < _labels.length; i++) NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_labels[i])),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: sections),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: sections,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: (int i) => setState(() => _section = i),
        destinations: <NavigationDestination>[
          for (int i = 0; i < _labels.length; i++) NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
        ],
      ),
    );
  }
}

/// Avviso in cima all'app quando c'è una versione più recente da installare.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.updater});

  final UpdateService updater;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updater,
      builder: (BuildContext context, Widget? _) {
        final UpdateService u = updater;
        if (!u.updateAvailable || u.bannerDismissed) return const SizedBox.shrink();
        final bool downloading = u.status == UpdateStatus.downloading || u.status == UpdateStatus.installing;
        return Material(
          color: AppColors.chip,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.system_update, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          downloading
                              ? 'Scarico l\'aggiornamento… ${(u.progress * 100).round()}%'
                              : 'Nuova versione disponibile: ${u.latest!.name}',
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                      if (!downloading) ...<Widget>[
                        TextButton(
                          onPressed: u.dismissBanner,
                          child: const Text('Più tardi'),
                        ),
                        FilledButton(onPressed: u.downloadAndInstall, child: const Text('Aggiorna')),
                      ],
                    ],
                  ),
                  if (downloading) ...<Widget>[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: u.progress > 0 ? u.progress : null),
                  ],
                  if (u.message != null && u.status != UpdateStatus.downloading)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(u.message!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Larghezza oltre la quale elenco e scheda stanno affiancati (tablet e
/// pieghevoli aperti, come lo schermo interno di un Galaxy Z Fold).
const double kTwoPaneWidth = 600;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final TabController _tabs = TabController(length: _labels.length, vsync: this)
    ..addListener(() {
      if (_tabs.index != _tab) setState(() => _tab = _tabs.index);
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
  DsObject? _selected;
  DateTime? _selectedDay;
  bool _selectedOnTrack = false;

  static const List<String> _labels = <String>['Catalogo', 'Stanotte', 'Liste', 'Comete', 'Impostazioni'];
  static const List<IconData> _icons = <IconData>[Icons.list_alt, Icons.nights_stay, Icons.bookmarks, Icons.wb_twilight, Icons.settings];

  void _open(DsObject o, {DateTime? day, bool track = false}) {
    final bool twoPane = MediaQuery.sizeOf(context).width >= kTwoPaneWidth;
    if (twoPane) {
      setState(() {
        _selected = o;
        _selectedDay = day;
        _selectedOnTrack = track;
      });
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (BuildContext context) => ObjectPage(state: widget.state, object: o, initialDay: day, startOnTrack: track),
      ));
    }
  }

  Widget _body(bool twoPane) {
    final AppState st = widget.state;
    final Widget list = switch (_tab) {
      0 => CatalogScreen(state: st, selected: twoPane ? _selected : null, onOpen: (DsObject o) => _open(o)),
      2 => ListsScreen(state: st, selected: twoPane ? _selected : null, onOpen: (DsObject o) => _open(o)),
      _ => TonightScreen(
          state: st,
          selected: twoPane ? _selected : null,
          onOpen: (DsObject o, DateTime day) => _open(o, day: day, track: true),
        ),
    };
    if (_tab == 3) return CometsScreen(state: st);
    if (_tab == 4) return SettingsScreen(state: st);
    if (!twoPane) return list;
    final DsObject? sel = _selected;
    return Row(
      children: <Widget>[
        SizedBox(width: 380, child: list),
        const VerticalDivider(width: 1),
        Expanded(
          child: sel == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Scegli un oggetto dall\'elenco per vedere scheda e traiettoria.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  ),
                )
              : ObjectDetail(
                  key: ValueKey<String>('detail-${sel.index}-$_selectedDay-$_selectedOnTrack'),
                  state: st,
                  object: sel,
                  initialDay: _selectedDay,
                  startOnTrack: _selectedOnTrack,
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (BuildContext context, Widget? _) {
        final AppState st = widget.state;
        if (st.loadError != null) {
          return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(st.loadError!))));
        }
        if (!st.ready) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[CircularProgressIndicator(), SizedBox(height: 16), Text('Carico il catalogo…')],
              ),
            ),
          );
        }
        final bool twoPane = MediaQuery.sizeOf(context).width >= kTwoPaneWidth;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: <Widget>[
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: <Widget>[
                    for (int i = 0; i < _labels.length; i++) Tab(icon: Icon(_icons[i]), text: _labels[i]),
                  ],
                ),
                Expanded(child: _body(twoPane)),
              ],
            ),
          ),
        );
      },
    );
  }
}
