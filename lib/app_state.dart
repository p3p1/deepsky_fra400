// Stato condiviso dell'app: catalogo, impostazioni, punteggi e comete.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';

import 'comets.dart';
import 'details.dart';
import 'lists.dart';
import 'models.dart';
import 'scoring.dart';
import 'image_pack.dart';
import 'settings.dart';
import 'updater.dart';

class AppState extends ChangeNotifier {
  AppSettings settings = AppSettings();
  List<DsObject> objects = const <DsObject>[];
  bool ready = false;
  String? loadError;

  /// Ore utili per notte, n × 12 (un valore per mese).
  Float32List? _monthly;
  List<double> _scores = const <double>[];
  List<double> _bestHours = const <double>[];
  bool computing = false;
  int _generation = 0;

  Float64List _ra = Float64List(0);
  Float64List _dec = Float64List(0);
  Float64List get raList => _ra;
  Float64List get decList => _dec;

  /// Aggiornamenti dell'app pubblicati su GitHub.
  final UpdateService updater = UpdateService();

  /// Pacchetto offline delle immagini di repertorio.
  final ImagePack images = ImagePack();

  /// Dettagli scientifici (Wikidata/Wikipedia), dentro l'app.
  final DetailsStore details = DetailsStore();

  /// Liste personali: preferiti, da fotografare, fotografati.
  final ObjectLists lists = ObjectLists();

  Map<String, DsObject> _byId = const <String, DsObject>{};
  DsObject? objectById(String id) => _byId[id];

  // ---------------------------------------------------------------- orologio
  // L'ora usata da traiettorie, "Stanotte", comete e vista AR. Di norma è
  // quella reale; si può simulare un'altra data e ora, e l'orologio continua
  // a scorrere da lì. Non viene salvata: alla riapertura si torna all'ora reale.
  Duration _clockOffset = Duration.zero;

  bool get simulatingTime => _clockOffset != Duration.zero;

  /// Cambia ogni volta che si imposta o si toglie un'ora simulata.
  int clockVersion = 0;

  DateTime now() => DateTime.now().add(_clockOffset);

  void simulateTime(DateTime t) {
    _clockOffset = t.difference(DateTime.now());
    clockVersion++;
    notifyListeners();
  }

  void useRealTime() {
    if (_clockOffset == Duration.zero) return;
    _clockOffset = Duration.zero;
    clockVersion++;
    notifyListeners();
  }

  List<Comet> comets = const <Comet>[];
  DateTime? cometsUpdated;
  bool cometsBusy = false;
  String? cometsError;

  Future<void> init() async {
    try {
      settings = await AppSettings.load();
      final String raw = await rootBundle.loadString('assets/catalog.json');
      final Map<String, dynamic> j = jsonDecode(raw) as Map<String, dynamic>;
      final List<dynamic> list = j['objs'] as List<dynamic>;
      final List<DsObject> parsed = <DsObject>[];
      for (int i = 0; i < list.length; i++) {
        parsed.add(DsObject.fromJson(i, list[i] as Map<String, dynamic>));
      }
      objects = parsed;
      _byId = <String, DsObject>{for (final DsObject o in parsed) o.id: o};
      await details.load();
      await lists.load();
      _ra = Float64List.fromList(parsed.map((DsObject o) => o.ra).toList());
      _dec = Float64List.fromList(parsed.map((DsObject o) => o.dec).toList());
      ready = true;
      notifyListeners();
      await recompute();
      unawaited(_initComets());
      unawaited(updater.check(silent: true));
      unawaited(images.load().then((_) => images.check(silent: true)));
    } catch (e) {
      loadError = 'Non riesco a leggere il catalogo: $e';
      notifyListeners();
    }
  }

  SiteParams get siteParams {
    final AppSettings s = settings;
    final w = s.window;
    return SiteParams(lat: s.lat, lon: s.lon, altMin: w.altMin, altMax: w.altMax, azFrom: w.azFrom, azTo: w.azTo);
  }

  /// Ricalcola ore utili e punteggi per il sito attivo.
  Future<void> recompute() async {
    final int gen = ++_generation;
    computing = true;
    notifyListeners();
    final Float32List res = await compute(computeMonthlyHours, MonthlyRequest(_ra, _dec, siteParams, now().year));
    if (gen != _generation) return; // nel frattempo sono cambiate le impostazioni
    _monthly = res;
    final int n = objects.length;
    final List<double> scores = List<double>.filled(n, 0);
    final List<double> best = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double hmax = 0;
      for (int m = 0; m < 12; m++) {
        final double h = res[i * 12 + m];
        if (h > hmax) hmax = h;
      }
      best[i] = hmax;
      final DsObject o = objects[i];
      double site;
      if (settings.isHome) {
        site = windowFactor(hmax);
      } else {
        site = hmax < 0.5 ? 0.0 : altitudeFactor(altMaxOf(o), settings.travelAltMin);
      }
      if (settings.urban) site *= o.info.urbanFactor;
      scores[i] = (10.0 * o.scaleFactor * o.fBright * site * 10.0).round() / 10.0;
    }
    _scores = scores;
    _bestHours = best;
    computing = false;
    notifyListeners();
  }

  bool get hasScores => _scores.length == objects.length && objects.isNotEmpty;
  double scoreOf(DsObject o) => hasScores ? _scores[o.index] : 0;
  double bestHoursOf(DsObject o) => hasScores ? _bestHours[o.index] : 0;
  double altMaxOf(DsObject o) => 90.0 - (settings.lat - o.dec).abs();

  List<double> monthsOf(DsObject o) {
    final Float32List? m = _monthly;
    if (m == null || m.length < (o.index + 1) * 12) return List<double>.filled(12, 0);
    return <double>[for (int k = 0; k < 12; k++) m[o.index * 12 + k]];
  }

  /// Fattori usati per il punteggio dell'oggetto nel sito attivo.
  List<MapEntry<String, double>> factorsOf(DsObject o) {
    final double h = bestHoursOf(o);
    return <MapEntry<String, double>>[
      MapEntry<String, double>('inquadratura', o.scaleFactor),
      MapEntry<String, double>('luminosità', o.fBright),
      if (settings.isHome)
        MapEntry<String, double>('finestra', windowFactor(h))
      else
        MapEntry<String, double>('altezza', h < 0.5 ? 0.0 : altitudeFactor(altMaxOf(o), settings.travelAltMin)),
      if (settings.urban) MapEntry<String, double>('cielo urbano', o.info.urbanFactor),
    ];
  }

  Future<void> changeSettings(void Function(AppSettings s) change, {bool rescore = true}) async {
    change(settings);
    notifyListeners();
    await settings.save();
    if (rescore) await recompute();
  }

  /// Legge la posizione dal GPS per la trasferta. Restituisce null se è
  /// andata bene, altrimenti il motivo dell'errore.
  Future<String?> refreshGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'La posizione del telefono è disattivata: attivala e riprova.';
      }
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        return 'Permesso di posizione negato: concedilo nelle impostazioni di Android.';
      }
      final Position pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 40));
      await changeSettings((AppSettings s) {
        s.travelLat = pos.latitude;
        s.travelLon = pos.longitude;
        s.travelFix = DateTime.now();
      }, rescore: !settings.isHome);
      return null;
    } on TimeoutException {
      return 'Il GPS non ha trovato la posizione in tempo: riprova all\'aperto.';
    } catch (e) {
      return 'Posizione non disponibile: $e';
    }
  }

  Future<void> _initComets() async {
    try {
      comets = await CometStore.loadCached();
      cometsUpdated = await CometStore.lastUpdate();
      notifyListeners();
    } catch (_) {
      // Nessun dato salvato: l'elenco resta vuoto finché non si scarica.
    }
    final DateTime? last = cometsUpdated;
    if (last == null || DateTime.now().difference(last).inDays >= 7) {
      await updateComets(silent: true);
    }
  }

  /// Scarica gli elementi orbitali aggiornati. Con [silent] un errore di rete
  /// non viene mostrato (aggiornamento automatico all'avvio).
  Future<void> updateComets({bool silent = false}) async {
    if (cometsBusy) return;
    cometsBusy = true;
    cometsError = null;
    notifyListeners();
    try {
      comets = await CometStore.download();
      cometsUpdated = DateTime.now();
    } catch (e) {
      if (!silent) cometsError = 'Aggiornamento non riuscito: controlla la connessione ($e).';
    }
    cometsBusy = false;
    notifyListeners();
  }
}
