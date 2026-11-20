// Elementi orbitali delle comete: scaricati dal Minor Planet Center quando
// c'è internet e conservati sul dispositivo per l'uso sul campo.
//
// Formato del file CometEls.txt ("Ephemerides and Orbital Elements Format"):
// https://docs.minorplanetcenter.net/mpc-ops-docs/orbits/comet-orbit-format/

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'comet_parser.dart';

export 'comet_parser.dart';

const String kCometUrl = 'https://www.minorplanetcenter.net/iau/MPCORB/CometEls.txt';

class CometStore {
  static Future<File> _file() async {
    final Directory dir = await getApplicationSupportDirectory();
    return File('${dir.path}/CometEls.txt');
  }

  /// Dati salvati sul dispositivo, oppure elenco vuoto se non ce ne sono.
  static Future<List<Comet>> loadCached() async {
    final File f = await _file();
    if (!f.existsSync()) return <Comet>[];
    return parseCometElements(await f.readAsString());
  }

  static Future<DateTime?> lastUpdate() async {
    final File f = await _file();
    return f.existsSync() ? f.lastModifiedSync() : null;
  }

  /// Scarica gli elementi aggiornati. Lancia un'eccezione se la rete non
  /// risponde o se il file ricevuto non contiene comete leggibili.
  static Future<List<Comet>> download() async {
    final http.Response r = await http.get(Uri.parse(kCometUrl)).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) {
      throw HttpException('Il server ha risposto ${r.statusCode}');
    }
    final List<Comet> comets = parseCometElements(r.body);
    if (comets.length < 10) {
      throw const FormatException('Il file ricevuto non ha il formato atteso');
    }
    final File f = await _file();
    await f.writeAsString(r.body);
    return comets;
  }
}
