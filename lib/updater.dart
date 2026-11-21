// Aggiornamento dell'app senza disinstallare: controlla l'ultima versione
// pubblicata nelle Release del repository GitHub, scarica l'APK e apre
// l'installazione di Android, che la installa sopra quella presente.
//
// Funziona perché ogni build è firmata con la stessa chiave
// (ci/debug.keystore) e ha un numero di versione sempre più alto.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'release_info.dart';

export 'release_info.dart';

enum UpdateStatus { idle, checking, upToDate, available, downloading, installing, error }

class UpdateService extends ChangeNotifier {
  UpdateStatus status = UpdateStatus.idle;
  String installedVersion = '';
  int installedBuild = 0;
  Release? latest;
  double progress = 0; // 0..1 durante lo scaricamento
  String? message;
  DateTime? lastCheck;

  /// Vero dopo che l'utente ha chiuso l'avviso "aggiornamento disponibile".
  bool bannerDismissed = false;

  void dismissBanner() {
    bannerDismissed = true;
    notifyListeners();
  }

  bool get updateAvailable => latest != null && latest!.build > installedBuild;
  bool get busy => status == UpdateStatus.checking || status == UpdateStatus.downloading || status == UpdateStatus.installing;

  Future<void> _loadInstalled() async {
    if (installedBuild > 0) return;
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      installedVersion = info.version;
      installedBuild = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      // Versione non leggibile: ogni release pubblicata risulterà più recente.
    }
  }

  /// Controlla se c'è una versione più recente. Con [silent] un errore di
  /// rete non viene mostrato (controllo automatico all'avvio).
  Future<void> check({bool silent = false}) async {
    if (busy) return;
    await _loadInstalled();
    status = UpdateStatus.checking;
    message = null;
    notifyListeners();
    try {
      final http.Response r = await http.get(
        Uri.parse('https://api.github.com/repos/$kReleaseRepo/releases/latest'),
        headers: const <String, String>{'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 20));
      lastCheck = DateTime.now();
      if (r.statusCode == 404) {
        latest = null;
        status = UpdateStatus.upToDate;
        message = 'Non è ancora stata pubblicata nessuna versione.';
      } else if (r.statusCode != 200) {
        throw HttpException('GitHub ha risposto ${r.statusCode}');
      } else {
        latest = parseRelease(jsonDecode(r.body) as Map<String, dynamic>);
        if (latest == null) throw const FormatException('l\'ultima release non contiene un APK');
        status = updateAvailable ? UpdateStatus.available : UpdateStatus.upToDate;
      }
    } catch (e) {
      status = silent ? UpdateStatus.idle : UpdateStatus.error;
      message = silent ? null : 'Controllo non riuscito: verifica la connessione ($e).';
    }
    notifyListeners();
  }

  /// Scarica l'APK e apre l'installazione di Android.
  Future<void> downloadAndInstall() async {
    final Release? rel = latest;
    if (rel == null || busy) return;
    status = UpdateStatus.downloading;
    progress = 0;
    message = null;
    notifyListeners();
    final http.Client client = http.Client();
    try {
      final http.StreamedResponse r =
          await client.send(http.Request('GET', Uri.parse(rel.apkUrl))).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) throw HttpException('download non riuscito (${r.statusCode})');
      final int total = r.contentLength ?? rel.apkSize;
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/deepsky_fra400-${rel.build}.apk');
      final IOSink sink = file.openWrite();
      int received = 0;
      DateTime lastNotify = DateTime.now();
      await for (final List<int> chunk in r.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && DateTime.now().difference(lastNotify).inMilliseconds > 150) {
          progress = received / total;
          lastNotify = DateTime.now();
          notifyListeners();
        }
      }
      await sink.close();
      if (total > 0 && received < total) throw const HttpException('download interrotto');
      status = UpdateStatus.installing;
      progress = 1;
      notifyListeners();
      final OpenResult res = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (res.type != ResultType.done) {
        throw Exception(res.message);
      }
      // Android mostra la sua schermata di installazione: se l'utente la
      // annulla, l'app resta com'è e l'aggiornamento resta disponibile.
      status = UpdateStatus.available;
      message = 'Conferma l\'installazione nella schermata di Android. La prima volta Android chiede di '
          'consentire all\'app di installare app sconosciute.';
    } catch (e) {
      status = UpdateStatus.error;
      message = 'Aggiornamento non riuscito: $e';
    } finally {
      client.close();
    }
    notifyListeners();
  }
}
