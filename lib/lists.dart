// Liste personali di oggetti (preferiti, da fotografare, fotografati),
// salvate sul telefono.

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ObjectListKind {
  const ObjectListKind(this.id, this.name, this.icon, this.color);
  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

const List<ObjectListKind> kObjectLists = <ObjectListKind>[
  ObjectListKind('fav', 'Preferiti', Icons.star, Color(0xFFF2C14E)),
  ObjectListKind('todo', 'Da fotografare', Icons.photo_camera, Color(0xFF5CC8C0)),
  ObjectListKind('done', 'Fotografati', Icons.check_circle, Color(0xFF7BC47F)),
];

class ObjectLists extends ChangeNotifier {
  final Map<String, List<String>> _lists = <String, List<String>>{
    for (final ObjectListKind k in kObjectLists) k.id: <String>[],
  };

  static String _key(String id) => 'list_$id';

  Future<void> load() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      for (final ObjectListKind k in kObjectLists) {
        _lists[k.id] = p.getStringList(_key(k.id)) ?? <String>[];
      }
      notifyListeners();
    } catch (_) {
      // Liste non leggibili: si parte vuoti.
    }
  }

  Future<void> _save(String list) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setStringList(_key(list), _lists[list]!);
    } catch (_) {}
  }

  /// Oggetti della lista, dal più recente al più vecchio.
  List<String> ids(String list) => List<String>.unmodifiable(_lists[list]!.reversed);

  bool contains(String list, String objectId) => _lists[list]!.contains(objectId);

  List<ObjectListKind> listsOf(String objectId) =>
      kObjectLists.where((ObjectListKind k) => _lists[k.id]!.contains(objectId)).toList();

  void set(String list, String objectId, bool value) {
    final List<String> l = _lists[list]!;
    if (value == l.contains(objectId)) return;
    if (value) {
      l.add(objectId);
      // Quando un oggetto diventa "fotografato" non è più "da fotografare".
      if (list == 'done') _lists['todo']!.remove(objectId);
      if (list == 'todo') _lists['done']!.remove(objectId);
    } else {
      l.remove(objectId);
    }
    notifyListeners();
    for (final ObjectListKind k in kObjectLists) {
      _save(k.id);
    }
  }
}

/// Pulsante segnalibro: apre un menu per mettere l'oggetto nelle liste.
class BookmarkButton extends StatelessWidget {
  const BookmarkButton({super.key, required this.lists, required this.objectId, required this.title});

  final ObjectLists lists;
  final String objectId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lists,
      builder: (BuildContext context, Widget? _) {
        final List<ObjectListKind> inLists = lists.listsOf(objectId);
        return IconButton(
          tooltip: 'Aggiungi a una lista',
          icon: inLists.isEmpty
              ? const Icon(Icons.bookmark_border)
              : Icon(inLists.length == 1 ? inLists.first.icon : Icons.bookmark, color: inLists.first.color),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (BuildContext context) => ListenableBuilder(
              listenable: lists,
              builder: (BuildContext context, Widget? _) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    for (final ObjectListKind k in kObjectLists)
                      CheckboxListTile(
                        secondary: Icon(k.icon, color: k.color),
                        title: Text(k.name),
                        value: lists.contains(k.id, objectId),
                        onChanged: (bool? v) => lists.set(k.id, objectId, v ?? false),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
