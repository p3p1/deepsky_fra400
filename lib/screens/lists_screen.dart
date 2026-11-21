// Le liste personali: preferiti, da fotografare, fotografati.

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../lists.dart';
import '../models.dart';
import '../theme.dart';
import 'catalog_screen.dart' show ObjectRow;

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key, required this.state, required this.onOpen, this.selected});

  final AppState state;
  final void Function(DsObject) onOpen;
  final DsObject? selected;

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  int _list = 0;
  bool _byScore = false;

  @override
  Widget build(BuildContext context) {
    final AppState st = widget.state;
    return ListenableBuilder(
      listenable: st.lists,
      builder: (BuildContext context, Widget? _) {
        final ObjectListKind kind = kObjectLists[_list];
        final List<DsObject> objs = <DsObject>[
          for (final String id in st.lists.ids(kind.id))
            if (st.objectById(id) != null) st.objectById(id)!,
        ];
        if (_byScore) objs.sort((DsObject a, DsObject b) => st.scoreOf(b).compareTo(st.scoreOf(a)));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: <ButtonSegment<int>>[
                  for (int i = 0; i < kObjectLists.length; i++)
                    ButtonSegment<int>(
                      value: i,
                      icon: Icon(kObjectLists[i].icon, color: kObjectLists[i].color, size: 18),
                      label: Text('${kObjectLists[i].name} (${st.lists.ids(kObjectLists[i].id).length})',
                          style: const TextStyle(fontSize: 12.5)),
                    ),
                ],
                selected: <int>{_list},
                onSelectionChanged: (Set<int> s) => setState(() => _list = s.first),
              ),
            ),
            Row(
              children: <Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    objs.isEmpty ? '' : '${objs.length} oggetti',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _byScore = !_byScore),
                  icon: Icon(_byScore ? Icons.star_rate : Icons.schedule, size: 18),
                  label: Text(_byScore ? 'Per punteggio' : 'Ultimi aggiunti'),
                ),
              ],
            ),
            Expanded(
              child: objs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'La lista «${kind.name}» è vuota.\n\nApri la scheda di un oggetto e tocca il segnalibro '
                          'accanto al nome per aggiungerlo.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: objs.length,
                      itemBuilder: (BuildContext context, int i) {
                        final DsObject o = objs[i];
                        return Dismissible(
                          key: ValueKey<String>('${kind.id}-${o.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(color: AppColors.q2.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.delete_outline),
                          ),
                          onDismissed: (_) {
                            st.lists.set(kind.id, o.id, false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('${o.id} tolto da «${kind.name}»'),
                              action: SnackBarAction(label: 'Annulla', onPressed: () => st.lists.set(kind.id, o.id, true)),
                            ));
                          },
                          child: ObjectRow(
                            state: st,
                            object: o,
                            selected: widget.selected?.index == o.index,
                            onTap: () => widget.onOpen(o),
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
