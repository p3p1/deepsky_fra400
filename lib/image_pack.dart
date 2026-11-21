// Pacchetto offline delle immagini di repertorio.
//
// Viene creato su GitHub (ci/images/build_pack.py) e pubblicato come Release
// con tag "immagini-...": due file, repertorio.bin (tutte le immagini JPEG in
// fila) e repertorio.json (indice). L'app li scarica una volta sola e poi
// legge ogni immagine dal .bin, senza bisogno di rete.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'release_info.dart' show kReleaseRepo;

class PackEntry {
  const PackEntry(this.offset, this.length, this.fovDeg, this.source);
  final int offset;
  final int length;
  final double fovDeg; // campo dell'immagine sul lato lungo, gradi
  final String source; // dss2, panstarrs, mellinger, skyview, skyview_rgb
}

/// Crediti da mostrare sotto l'immagine, per fonte.
String packSourceCredit(String source) {
  switch (source) {
    case 'panstarrs':
      return 'Pan-STARRS DR1 (STScI/MAST), ritaglio CDS Strasburgo.';
    case 'skyview_rgb':
      return 'Digitized Sky Survey 2 (STScI/NASA), lastre infrarossa, rossa e blu ricomposte a colori, tramite NASA SkyView.';
    case 'skyview':
      return 'Digitized Sky Survey 2, rosso (STScI/NASA), tramite NASA SkyView.';
    case 'mellinger':
      return 'Milky Way Panorama di Axel Mellinger, ritaglio CDS Strasburgo.';
    default:
      return 'Digitized Sky Survey (STScI/NASA), colori e ritaglio CDS Strasburgo.';
  }
}

class PackRelease {
  const PackRelease(this.tag, this.binUrl, this.binSize, this.indexUrl);
  final String tag;
  final String binUrl;
  final int binSize;
  final String indexUrl;
}

/// Cerca la Release più recente con il pacchetto immagini.
PackRelease? findPackRelease(List<dynamic> releases) {
  for (final Object? r in releases) {
    if (r is! Map<String, dynamic>) continue;
    final Object? tag = r['tag_name'];
    if (tag is! String || !tag.startsWith('immagini-')) continue;
    String? bin, idx;
    int size = 0;
    for (final Object? a in (r['assets'] as List<dynamic>? ?? const <dynamic>[])) {
      if (a is! Map<String, dynamic>) continue;
      if (a['name'] == 'repertorio.bin') {
        bin = a['browser_download_url'] as String?;
        size = a['size'] is int ? a['size'] as int : 0;
      } else if (a['name'] == 'repertorio.json') {
        idx = a['browser_download_url'] as String?;
      }
    }
    if (bin != null && idx != null) return PackRelease(tag, bin, size, idx);
  }
  return null;
}

enum PackStatus { idle, checking, downloading, error }

class ImagePack extends ChangeNotifier {
  Map<String, PackEntry> _items = const <String, PackEntry>{};
  String? installedTag;
  DateTime? installedDate;
  int installedBytes = 0;
  /// Falso se il pacchetto sul telefono è parziale (creazione ancora in corso su GitHub).
  bool complete = true;

  PackRelease? available;
  PackStatus status = PackStatus.idle;
  double progress = 0;
  String? message;
  RandomAccessFile? _raf;

  bool get installed => _items.isNotEmpty;
  int get count => _items.length;
  bool get busy => status == PackStatus.checking || status == PackStatus.downloading;
  bool get updateAvailable => available != null && available!.tag != installedTag;

  PackEntry? entryFor(String id) => _items[id];

  Future<Directory> _dir() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory d = Directory('${base.path}/repertorio');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Legge l'indice salvato sul telefono, se c'è.
  Future<void> load() async {
    try {
      final Directory d = await _dir();
      final File idx = File('${d.path}/repertorio.json');
      final File bin = File('${d.path}/repertorio.bin');
      if (!idx.existsSync() || !bin.existsSync()) return;
      final Map<String, dynamic> j = jsonDecode(await idx.readAsString()) as Map<String, dynamic>;
      final Map<String, PackEntry> items = <String, PackEntry>{};
      (j['items'] as Map<String, dynamic>).forEach((String k, dynamic v) {
        final List<dynamic> l = v as List<dynamic>;
        items[k] = PackEntry((l[0] as num).toInt(), (l[1] as num).toInt(), (l[2] as num).toDouble(), l[3] as String);
      });
      _items = items;
      installedTag = j['tag'] as String?;
      complete = j['complete'] as bool? ?? true;
      installedDate = DateTime.tryParse((j['created'] as String?) ?? '');
      installedBytes = bin.lengthSync();
      await _raf?.close();
      _raf = await bin.open();
      notifyListeners();
    } catch (_) {
      _items = const <String, PackEntry>{};
    }
  }

  /// Immagine JPEG dell'oggetto, letta dal pacchetto.
  Future<Uint8List?> imageFor(String id) async {
    final PackEntry? e = _items[id];
    final RandomAccessFile? raf = _raf;
    if (e == null || raf == null) return null;
    // Le letture sullo stesso file vanno fatte una alla volta.
    final Future<Uint8List?> read = _lock.then((_) async {
      await raf.setPosition(e.offset);
      return raf.read(e.length);
    });
    _lock = read.catchError((Object _) => null);
    return read;
  }

  Future<Uint8List?> _lock = Future<Uint8List?>.value(null);

  /// Controlla su GitHub se c'è un pacchetto (o uno più recente).
  Future<void> check({bool silent = false}) async {
    if (busy) return;
    status = PackStatus.checking;
    message = null;
    notifyListeners();
    try {
      final http.Response r = await http.get(
        Uri.parse('https://api.github.com/repos/$kReleaseRepo/releases?per_page=30'),
        headers: const <String, String>{'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw HttpException('GitHub ha risposto ${r.statusCode}');
      available = findPackRelease(jsonDecode(r.body) as List<dynamic>);
      if (available == null && !silent) message = 'Il pacchetto delle immagini non è ancora stato pubblicato.';
      status = PackStatus.idle;
    } catch (e) {
      status = silent ? PackStatus.idle : PackStatus.error;
      message = silent ? null : 'Controllo non riuscito: verifica la connessione ($e).';
    }
    notifyListeners();
  }

  /// Scarica il pacchetto completo e lo sostituisce a quello presente.
  Future<void> download() async {
    if (busy) return;
    if (available == null) await check();
    final PackRelease? rel = available;
    if (rel == null) return;
    status = PackStatus.downloading;
    progress = 0;
    message = null;
    notifyListeners();
    final http.Client client = http.Client();
    final Directory d = await _dir();
    final File binPart = File('${d.path}/repertorio.bin.part');
    final File idxPart = File('${d.path}/repertorio.json.part');
    try {
      final http.Response idx = await client.get(Uri.parse(rel.indexUrl)).timeout(const Duration(seconds: 60));
      if (idx.statusCode != 200) throw HttpException('indice non scaricato (${idx.statusCode})');
      final Map<String, dynamic> j = jsonDecode(utf8.decode(idx.bodyBytes)) as Map<String, dynamic>;
      j['tag'] = rel.tag;
      await idxPart.writeAsString(jsonEncode(j), flush: true);

      final http.StreamedResponse r = await client.send(http.Request('GET', Uri.parse(rel.binUrl))).timeout(const Duration(seconds: 60));
      if (r.statusCode != 200) throw HttpException('immagini non scaricate (${r.statusCode})');
      final int total = r.contentLength ?? rel.binSize;
      final IOSink sink = binPart.openWrite();
      int received = 0;
      DateTime last = DateTime.now();
      await for (final List<int> chunk in r.stream.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && DateTime.now().difference(last).inMilliseconds > 200) {
          progress = received / total;
          last = DateTime.now();
          notifyListeners();
        }
      }
      await sink.close();
      if (total > 0 && received < total) throw const HttpException('download interrotto');

      await _raf?.close();
      _raf = null;
      await binPart.rename('${d.path}/repertorio.bin');
      await idxPart.rename('${d.path}/repertorio.json');
      status = PackStatus.idle;
      progress = 1;
      await load();
      message = 'Immagini scaricate: ${fmtCount(count)} oggetti, disponibili anche senza rete.';
    } catch (e) {
      status = PackStatus.error;
      message = 'Download non riuscito: $e. Puoi riprovare: serve una connessione stabile (meglio il WiFi).';
      for (final File f in <File>[binPart, idxPart]) {
        if (f.existsSync()) f.deleteSync();
      }
    } finally {
      client.close();
    }
    notifyListeners();
  }

  Future<void> delete() async {
    await _raf?.close();
    _raf = null;
    final Directory d = await _dir();
    for (final String n in <String>['repertorio.bin', 'repertorio.json']) {
      final File f = File('${d.path}/$n');
      if (f.existsSync()) f.deleteSync();
    }
    _items = const <String, PackEntry>{};
    installedTag = null;
    installedDate = null;
    installedBytes = 0;
    message = 'Immagini eliminate dal telefono.';
    notifyListeners();
  }
}

String fmtCount(int v) {
  final String s = v.toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtMegabytes(int bytes) => '${(bytes / 1e6).toStringAsFixed(0)} MB';
