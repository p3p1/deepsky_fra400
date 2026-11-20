// Lettura del file di elementi orbitali delle comete del Minor Planet Center.
//
// Formato ("Ephemerides and Orbital Elements Format"):
// https://docs.minorplanetcenter.net/mpc-ops-docs/orbits/comet-orbit-format/

import 'astro.dart';

class Comet {
  const Comet(this.elements);
  final CometElements elements;
  String get name => elements.name;
}

String _col(String line, int from, int to) {
  // Colonne numerate da 1, estremi inclusi, come nella documentazione MPC.
  if (line.length < from) return '';
  return line.substring(from - 1, line.length < to ? line.length : to).trim();
}

/// Legge il file del Minor Planet Center. Le righe che non rispettano il
/// formato vengono saltate.
List<Comet> parseCometElements(String text) {
  final List<Comet> out = <Comet>[];
  for (final String line in text.split('\n')) {
    if (line.length < 100) continue;
    final int? year = int.tryParse(_col(line, 15, 18));
    final int? month = int.tryParse(_col(line, 20, 21));
    final double? day = double.tryParse(_col(line, 23, 29));
    final double? q = double.tryParse(_col(line, 31, 39));
    final double? e = double.tryParse(_col(line, 42, 49));
    final double? peri = double.tryParse(_col(line, 52, 59));
    final double? node = double.tryParse(_col(line, 62, 69));
    final double? incl = double.tryParse(_col(line, 72, 79));
    if (year == null || month == null || day == null || q == null || e == null || peri == null || node == null || incl == null) {
      continue;
    }
    if (month < 1 || month > 12 || day < 1 || day >= 32 || q <= 0 || e < 0) continue;
    final String name = _col(line, 103, 158);
    if (name.isEmpty) continue;
    out.add(Comet(CometElements(
      name: name,
      perihelionJd: jdFromCalendar(year, month, day),
      q: q,
      e: e,
      argPeri: peri,
      node: node,
      incl: incl,
      h: double.tryParse(_col(line, 92, 95)),
      g: double.tryParse(_col(line, 97, 100)),
    )));
  }
  return out;
}
