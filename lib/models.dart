// Modello degli oggetti del catalogo e testi derivati (tipo, filtro,
// inquadratura, parametri di partenza). I dati vengono da assets/catalog.json.

import 'astro.dart';

/// Campo inquadrato dalla ASI2600MC Pro, in primi d'arco.
const double kFovNativeW = 201.8, kFovNativeH = 134.9; // 400 mm f/5,6
const double kFovReducerW = 288.2, kFovReducerH = 192.7; // 280 mm f/3,9
const double kScaleNative = 1.94; // secondi d'arco per pixel a 400 mm

String fmt(double v, [int decimals = 1]) => v.toStringAsFixed(decimals).replaceAll('.', ',');

String fmtThousands(int v) {
  final String s = v.abs().toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return (v < 0 ? '-' : '') + b.toString();
}

String fmtRa(double raDeg) {
  final int t = (raDeg / 15.0 * 3600.0).round() % 86400;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t ~/ 3600)}h${two(t % 3600 ~/ 60)}m${two(t % 60)}s';
}

String fmtDec(double decDeg) {
  final int t = (decDeg.abs() * 60.0).round();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${decDeg < 0 ? '−' : '+'}${two(t ~/ 60)}°${two(t % 60)}′';
}

String fmtTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const List<String> kMonthsShort = <String>['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
const List<String> kMonthsLong = <String>[
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', //
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

String fmtDate(DateTime d) => '${d.day} ${kMonthsShort[d.month - 1]} ${d.year}';

class TypeInfo {
  const TypeInfo(this.code, this.plural, this.singular, this.filter, this.urbanFactor);
  final String code;
  final String plural;
  final String singular;
  final String filter; // 'S' = S200, 'U' = banda larga, 'SU' = entrambi
  final double urbanFactor;
}

const List<TypeInfo> kTypes = <TypeInfo>[
  TypeInfo('EN', 'Emissione', 'Nebulosa a emissione', 'S', 1.0),
  TypeInfo('PN', 'Planetarie', 'Nebulosa planetaria', 'S', 1.0),
  TypeInfo('SNR', 'Resti di supernova', 'Resto di supernova', 'S', 1.0),
  TypeInfo('MIX', 'Emissione + riflessione', 'Nebulosa a emissione e riflessione', 'SU', 0.8),
  TypeInfo('RN', 'Riflessione', 'Nebulosa a riflessione', 'U', 0.3),
  TypeInfo('DN', 'Oscure', 'Nebulosa oscura', 'U', 0.15),
  TypeInfo('NEB', 'Natura non indicata', 'Nebulosa (natura non indicata)', 'SU', 0.6),
  TypeInfo('GAL', 'Galassie', 'Galassia', 'U', 0.5),
  TypeInfo('GC', 'Globulari', 'Ammasso globulare', 'U', 0.85),
  TypeInfo('OC', 'Ammassi aperti', 'Ammasso aperto', 'U', 0.9),
  TypeInfo('AST', 'Associazioni', 'Associazione stellare', 'U', 0.7),
  TypeInfo('OTH', 'Altro', 'Altro oggetto Messier', 'U', 0.9),
];

TypeInfo typeInfo(String code) => kTypes.firstWhere((TypeInfo t) => t.code == code, orElse: () => kTypes.last);

class DsObject {
  DsObject({
    required this.index,
    required this.id,
    required this.aliases,
    required this.names,
    required this.type,
    required this.catalogType,
    required this.morph,
    required this.constellation,
    required this.ra,
    required this.dec,
    required this.major,
    required this.minor,
    required this.otherSize,
    required this.magBand,
    required this.mag,
    required this.brightness,
    required this.distance,
    required this.redshift,
    required this.cfg,
    required this.panels,
    required this.fScale,
    required this.fBright,
    required this.flags,
    required this.source,
  }) : info = typeInfo(type) {
    final List<String> all = <String>[id, ...aliases, ...names, constellation, info.singular];
    searchText = all.join(' | ').toLowerCase();
    searchKeys = <String>[id, ...aliases].map((String s) => s.toLowerCase().replaceAll(RegExp(r'[\s-]'), '')).toList();
  }

  factory DsObject.fromJson(int index, Map<String, dynamic> j) {
    double? numOrNull(Object? v) => v is num ? v.toDouble() : null;
    List<String> strings(Object? v) => v is List ? v.map((Object? e) => e.toString()).toList() : <String>[];
    final Object? m = j['m'];
    final Object? osz = j['osz'];
    return DsObject(
      index: index,
      id: j['i'] as String,
      aliases: strings(j['a']),
      names: strings(j['n']),
      type: j['t'] as String,
      catalogType: (j['st'] as String?) ?? '',
      morph: (j['mo'] as String?) ?? '',
      constellation: (j['c'] as String?) ?? '',
      ra: (j['ra'] as num).toDouble(),
      dec: (j['de'] as num).toDouble(),
      major: numOrNull(j['D']) ?? 0,
      minor: numOrNull(j['d']) ?? 0,
      otherSize: osz is List ? osz.map((Object? e) => (e as num).toDouble()).toList() : null,
      magBand: m is List && m.length == 2 ? m[0].toString() : null,
      mag: m is List && m.length == 2 ? numOrNull(m[1]) : null,
      brightness: j['b'] as String?,
      distance: j['ds'] as String?,
      redshift: numOrNull(j['z']),
      cfg: (j['cfg'] as String?) ?? 'ND',
      panels: (numOrNull(j['pan']) ?? 0).round(),
      fScale: numOrNull(j['fs']),
      fBright: numOrNull(j['fb']) ?? 0.5,
      flags: strings(j['fl']),
      source: (j['src'] as String?) ?? '',
    );
  }

  final int index;
  final String id;
  final List<String> aliases;
  final List<String> names;
  final String type;
  final String catalogType;
  final String morph;
  final String constellation;
  final double ra; // J2000, gradi
  final double dec;
  final double major; // primi d'arco, 0 = non catalogata
  final double minor;
  final List<double>? otherSize;
  final String? magBand;
  final double? mag;
  final String? brightness;
  final String? distance;
  final double? redshift;
  final String cfg; // N, NL, R, M, ND
  final int panels;
  final double? fScale;
  final double fBright;
  final List<String> flags;
  final String source;
  final TypeInfo info;
  late final String searchText;
  late final List<String> searchKeys;

  String get title => names.isEmpty ? id : '$id · ${names.first}';
  bool get partialData => flags.contains('nobright') || flags.contains('nosize') || flags.contains('clustersize');
  double get scaleFactor => fScale ?? 0.5;

  Equatorial get j2000 => Equatorial(ra, dec);

  bool matches(String query) {
    final String q = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) return true;
    if (searchText.contains(q)) return true;
    final String qn = q.replaceAll(RegExp(r'[\s-]'), '');
    return searchKeys.any((String k) => k == qn || (qn.length > 3 && k.startsWith(qn)));
  }

  String get sizeText {
    if (major <= 0) return 'n/d';
    String f(double x) => x >= 10 ? fmt(x, 0) : fmt(x, 1);
    return minor > 0 ? '${f(major)} × ${f(minor)}′' : '${f(major)}′';
  }

  int get pixelsNative => (major * 60.0 / kScaleNative).round();

  String get cfgShort {
    if (flags.contains('clustersize')) return 'Da verificare';
    switch (cfg) {
      case 'N':
        return 'Nativo';
      case 'NL':
        return 'Nativo al limite';
      case 'R':
        return 'Riduttore';
      case 'M':
        return 'Mosaico ×$panels';
      default:
        return 'n/d';
    }
  }

  /// 'N' nativo, 'R' riduttore (anche "al limite"), 'M' mosaico, '' non nota.
  String get cfgGroup => cfg == 'NL' ? 'R' : (cfg == 'ND' ? '' : cfg);

  String get cfgLong {
    switch (cfg) {
      case 'N':
        final String base = 'Entra nel campo nativo a 400 mm f/5,6 (circa ${fmtThousands(pixelsNative)} pixel sul lato lungo).';
        if (major < 2) return '$base A questa focale è molto piccolo: aspettati pochi dettagli.';
        if (major >= 100) return '$base Con il riduttore avresti più margine attorno.';
        return base;
      case 'NL':
        return 'Entra a 400 mm solo senza margine. Meglio il riduttore a 280 mm, oppure un mosaico di 2 pannelli.';
      case 'R':
        return 'Non entra a 400 mm. Entra con il riduttore a 280 mm f/3,9; senza riduttore serve un mosaico.';
      case 'M':
        return 'Più grande del campo anche con il riduttore: mosaico di circa $panels pannelli a 280 mm (con il 20% di sovrapposizione).';
      default:
        return 'Dimensione non catalogata: inquadratura da verificare.';
    }
  }

  String get filterShort {
    switch (info.filter) {
      case 'S':
        return 'S200';
      case 'U':
        return 'UV/IR-cut';
      default:
        return type == 'MIX' ? 'S200 + UV/IR-cut' : 'S200 o UV/IR-cut';
    }
  }

  List<String> get filterLong {
    switch (type) {
      case 'EN':
        return <String>['S200 dual-band (Hα + OIII), che hai già.', 'Opzionale: un dual-band SII + OIII per la palette SHO.'];
      case 'SNR':
        return <String>[
          'S200 dual-band: i resti di supernova sono forti in OIII e Hα.',
          'Opzionale: un dual-band SII + OIII per la palette SHO.',
        ];
      case 'PN':
        return <String>['S200 dual-band: le planetarie emettono soprattutto in OIII e Hα.'];
      case 'MIX':
        return <String>['S200 per la parte a emissione e UV/IR-cut per la parte a riflessione, in due sessioni distinte.'];
      case 'RN':
        return <String>['UV/IR-cut sotto un cielo rurale. L\'S200 non va bene: la luce riflessa è continua e il filtro la taglia.'];
      case 'DN':
        return <String>['UV/IR-cut sotto un cielo rurale: la nebulosa oscura si vede per contrasto sul fondo di stelle.'];
      case 'NEB':
        return <String>['Il catalogo non dice se è a emissione o a riflessione: prova prima l\'S200, poi la banda larga con UV/IR-cut.'];
      case 'GAL':
        final bool spiral = major >= 10 && RegExp(r'^(S[^0]|I)').hasMatch(morph);
        return <String>[
          'UV/IR-cut.',
          'Dalla città aiuta un filtro antinquinamento a banda larga.',
          if (spiral) 'Opzionale: una serie con l\'S200 per far risaltare le regioni HII nei bracci.',
        ];
      default:
        return <String>['UV/IR-cut o nessun filtro.', 'Dalla città un filtro antinquinamento a banda larga è opzionale.'];
    }
  }

  /// Filtri commerciali noti adatti a questo tipo di oggetto, con il loro ruolo.
  /// Il primo elemento indica se è il filtro che hai già.
  List<FilterSuggestion> get filterSuggestions {
    const FilterSuggestion s200 = FilterSuggestion('SVBONY S200', 'Dual-band Hα + OIII', 'Quello che hai già: va bene da un sito urbano e con la Luna.', owned: true);
    const FilterSuggestion lExtreme = FilterSuggestion('Optolong L-eXtreme', 'Dual-band Hα + OIII, 7 nm',
        'Il riferimento per le camere a colori sotto cielo urbano: fondo cielo più scuro dell\'S200.');
    const FilterSuggestion alpT = FilterSuggestion('Antlia ALP-T', 'Dual-band Hα + OIII, 5 nm',
        'Bande più strette: più contrasto con la Luna, stelle più piccole.');
    const FilterSuggestion lSynergy = FilterSuggestion('Optolong L-Synergy', 'Dual-band SII + OIII, 7 nm',
        'Da usare insieme a un Hα + OIII per comporre la palette SHO (Hubble).');
    const FilterSuggestion lEnhance = FilterSuggestion('Optolong L-eNhance', 'Tri-band Hα, Hβ, OIII',
        'Bande più larghe: colori più naturali, adatto a cieli poco o mediamente inquinati.');
    const FilterSuggestion uvir = FilterSuggestion('Baader UV/IR-Cut', 'Banda larga',
        'Lascia passare tutto il visibile: colori naturali sotto un cielo rurale.');
    const FilterSuggestion lPro = FilterSuggestion('Optolong L-Pro', 'Antinquinamento a banda larga',
        'Taglia le righe dell\'illuminazione stradale conservando il colore delle stelle: utile in città.');
    const FilterSuggestion lpsD1 = FilterSuggestion('IDAS LPS-D1', 'Antinquinamento a banda larga',
        'Alternativa al L-Pro, con resa del colore molto neutra.');
    switch (type) {
      case 'EN':
        return const <FilterSuggestion>[s200, lExtreme, alpT, lSynergy];
      case 'SNR':
        return const <FilterSuggestion>[s200, lExtreme, alpT, lSynergy];
      case 'PN':
        return const <FilterSuggestion>[s200, lExtreme, alpT, lEnhance];
      case 'MIX':
        return const <FilterSuggestion>[s200, lEnhance, lPro, uvir];
      case 'NEB':
        return const <FilterSuggestion>[s200, lEnhance, lPro, uvir];
      case 'RN':
      case 'DN':
        return const <FilterSuggestion>[uvir, lPro, lpsD1];
      case 'GAL':
        final bool spiral = major >= 10 && RegExp(r'^(S[^0]|I)').hasMatch(morph);
        return <FilterSuggestion>[
          uvir,
          lPro,
          lpsD1,
          if (spiral)
            const FilterSuggestion('SVBONY S200', 'Dual-band Hα + OIII',
                'Quello che hai già: solo come serie aggiuntiva per le regioni HII nei bracci.', owned: true),
        ];
      default:
        return const <FilterSuggestion>[uvir, lPro, lpsD1];
    }
  }

  bool get _isCluster => type == 'OC' || type == 'GC' || type == 'AST' || type == 'OTH';

  /// Coppie etichetta/valore con i parametri di ripresa di partenza.
  List<List<String>> get shooting {
    final bool s200 = info.filter.startsWith('S');
    final bool reducer = cfg == 'R' || cfg == 'NL' || cfg == 'M';
    final String sub = s200
        ? (reducer ? '120 s con il riduttore, 180 s a 400 mm' : '180 s (120 s se usi il riduttore)')
        : (_isCluster ? '30–60 s' : '60 s da un sito rurale, 30 s da un sito urbano');
    String integ;
    if (_isCluster) {
      integ = '1–2 ore';
    } else if (flags.contains('nobright')) {
      integ = 'luminosità non catalogata: parti da 4–6 ore e valuta sul risultato';
    } else {
      integ = fBright >= 0.85 ? '2–4 ore' : (fBright >= 0.6 ? '4–8 ore' : '8–12 ore o più');
    }
    return <List<String>>[
      <String>['Camera', 'gain 100, offset 50, −10 °C'],
      <String>['Posa', sub],
      <String>['Integrazione', integ],
      <String>['Dithering', 'ogni 1–2 pose'],
    ];
  }

  List<String> get notes {
    final List<String> n = <String>[];
    if (flags.contains('clustersize')) {
      n.add('La dimensione catalogata si riferisce all\'ammasso o alla parte NGC/IC. La nebulosa Sharpless associata è più estesa: verifica l\'estensione reale prima di scegliere tra nativo e riduttore.');
    }
    if (flags.contains('nobright')) n.add('Luminosità non catalogata: il punteggio usa il fattore prudente 0,5.');
    if (flags.contains('nosize')) n.add('Dimensione non catalogata: il punteggio usa il fattore di inquadratura 0,5.');
    if (flags.contains('nebnature')) n.add('Il catalogo segnala una nebulosità associata all\'ammasso ma non ne indica la natura.');
    if (otherSize != null && otherSize!.isNotEmpty) {
      final List<double> o = otherSize!;
      n.add('OpenNGC riporta una dimensione diversa: ${fmt(o[0])}${o.length > 1 && o[1] > 0 ? ' × ${fmt(o[1])}' : ''}′.');
    }
    if (source == 'OpenNGC') n.add('Dati presi da OpenNGC: l\'oggetto manca nell\'edizione standard del catalogo di Stellarium.');
    return n;
  }
}

class FilterSuggestion {
  const FilterSuggestion(this.name, this.kind, this.why, {this.owned = false});
  final String name;
  final String kind;
  final String why;
  final bool owned;
}

/// Qualcosa di cui si può disegnare la traiettoria: un oggetto del catalogo
/// (posizione fissa) oppure una cometa (posizione che cambia con la data).
class SkyTarget {
  const SkyTarget({required this.title, required this.subtitle, required this.position});
  final String title;
  final String subtitle;
  final EquatorialAt position;

  factory SkyTarget.fromObject(DsObject o) {
    final Equatorial e = o.j2000;
    return SkyTarget(
      title: o.title,
      subtitle: 'AR ${fmtRa(o.ra)} · Dec ${fmtDec(o.dec)} · ${o.constellation}',
      position: (double jd) => e,
    );
  }
}

String verdict(double score) {
  if (score >= 8) return 'Ottima';
  if (score >= 6) return 'Buona';
  if (score >= 4) return 'Impegnativa';
  if (score >= 2) return 'Difficile';
  if (score > 0) return 'Sconsigliata';
  return 'Non fattibile';
}

/// Elenco compatto dei mesi in cui [hours] supera [threshold].
String monthRanges(List<double> hours, double threshold) {
  final List<bool> on = hours.map((double h) => h >= threshold).toList();
  final int n = on.where((bool b) => b).length;
  if (n == 0) return 'nessun mese';
  if (n == 12) return 'tutto l\'anno';
  int start = 0;
  for (start = 0; start < 12; start++) {
    if (on[start] && !on[(start + 11) % 12]) break;
  }
  final List<String> out = <String>[];
  int i = 0;
  while (i < 12) {
    final int a = (start + i) % 12;
    if (!on[a]) {
      i++;
      continue;
    }
    int j = i;
    while (j + 1 < 12 && on[(start + j + 1) % 12]) {
      j++;
    }
    final int b = (start + j) % 12;
    out.add(a == b ? kMonthsShort[a] : '${kMonthsShort[a]}–${kMonthsShort[b]}');
    i = j + 1;
  }
  return out.join(', ');
}
