// Dettagli scientifici degli oggetti.
//
// Due fonti, entrambe dentro l'app e quindi disponibili senza rete:
//  * assets/details.json, creato su GitHub da ci/details/build_details.py:
//    distanza, tipo e appartenenza da Wikidata, riassunto da Wikipedia;
//  * spiegazioni scritte qui: che cos'è ogni tipo di oggetto e come si
//    leggono le classificazioni del catalogo (Trumpler, Shapley-Sawyer, ecc.).

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

class ObjectDetails {
  const ObjectDetails({this.wikidata, this.lightYears, this.range, this.types = const <String>[], this.partOf = const <String>[], this.redshift, this.wiki, this.wikiTitle});

  factory ObjectDetails.fromJson(Map<String, dynamic> j) {
    final List<dynamic>? r = j['lyr'] as List<dynamic>?;
    return ObjectDetails(
      wikidata: j['wd'] as String?,
      lightYears: (j['ly'] as num?)?.toDouble(),
      range: r == null ? null : <double>[(r[0] as num).toDouble(), (r[1] as num).toDouble()],
      types: ((j['ty'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
      partOf: ((j['pt'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
      redshift: (j['z'] as num?)?.toDouble(),
      wiki: j['wk'] as String?,
      wikiTitle: j['wt'] as String?,
    );
  }

  final String? wikidata;
  final double? lightYears;
  final List<double>? range; // stime minima e massima, se molto diverse
  final List<String> types;
  final List<String> partOf;
  final double? redshift;
  final String? wiki;
  final String? wikiTitle;
}

class DetailsStore {
  Map<String, ObjectDetails> _items = const <String, ObjectDetails>{};
  String source = '';

  Future<void> load() async {
    try {
      final Map<String, dynamic> j = jsonDecode(await rootBundle.loadString('assets/details.json')) as Map<String, dynamic>;
      final Map<String, ObjectDetails> m = <String, ObjectDetails>{};
      (j['items'] as Map<String, dynamic>).forEach((String k, dynamic v) => m[k] = ObjectDetails.fromJson(v as Map<String, dynamic>));
      _items = m;
      source = (j['source'] as String?) ?? '';
    } catch (_) {
      _items = const <String, ObjectDetails>{};
    }
  }

  ObjectDetails? of(String id) => _items[id];
  int get count => _items.length;
}

// ------------------------------------------------------------------ numeri

/// Distanza in anni luce leggibile, con le parole italiane per i grandi numeri.
String fmtLightYears(double ly) {
  if (ly >= 1e9) return '${_dec(ly / 1e9)} miliardi di anni luce';
  if (ly >= 1e6) return '${_dec(ly / 1e6)} milioni di anni luce';
  if (ly >= 1e4) return '${_thousands((ly / 100).round() * 100)} anni luce';
  if (ly >= 100) return '${_thousands((ly / 10).round() * 10)} anni luce';
  return '${_dec(ly)} anni luce';
}

String _dec(double v) => (v >= 100 ? v.round().toString() : v.toStringAsFixed(v >= 10 ? 0 : 1)).replaceAll('.', ',');

String _thousands(int v) {
  final String s = v.toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Diametro reale in anni luce dato il diametro apparente (primi d'arco).
double realSizeLy(double distanceLy, double arcmin) => 2 * distanceLy * math.tan(arcmin / 60 * math.pi / 180 / 2);

/// Distanza da un redshift piccolo con la legge di Hubble (H0 = 70 km/s/Mpc).
double hubbleDistanceLy(double z) => z * 299792.458 / 70 * 3.2616e6;

/// Coordinate galattiche (l, b) in gradi da AR e Dec J2000 in gradi.
List<double> galactic(double raDeg, double decDeg) {
  const double raGp = 192.85948, decGp = 27.12825, lNcp = 122.93192;
  final double r = math.pi / 180;
  final double ra = raDeg * r, dec = decDeg * r;
  final double sinb = math.sin(dec) * math.sin(decGp * r) + math.cos(dec) * math.cos(decGp * r) * math.cos(ra - raGp * r);
  final double b = math.asin(sinb);
  final double y = math.cos(dec) * math.sin(ra - raGp * r);
  final double x = math.sin(dec) * math.cos(decGp * r) - math.cos(dec) * math.sin(decGp * r) * math.cos(ra - raGp * r);
  double l = lNcp - math.atan2(y, x) / r;
  l = (l % 360 + 360) % 360;
  return <double>[l, b / r];
}

String galacticNote(double b) {
  final double a = b.abs();
  if (a < 5) return 'sul piano della Via Lattea, tra polveri e regioni di formazione stellare';
  if (a < 20) return 'vicino al piano della Via Lattea';
  if (a < 60) return 'lontano dal piano della Via Lattea';
  return 'verso il polo galattico, dove la polvere della nostra galassia quasi non disturba';
}

// ---------------------------------------------------------- spiegazioni

/// Che cos'è fisicamente ogni tipo di oggetto.
String typeExplanation(String code) {
  switch (code) {
    case 'EN':
      return 'Nube di gas, soprattutto idrogeno, ionizzata dalla radiazione ultravioletta di stelle giovani e calde '
          '(tipi spettrali O e B, oltre 25.000 K). Quando gli elettroni si ricombinano con i protoni il gas emette '
          'righe precise: H-alfa a 656,3 nm (rosso), OIII a 495,9 e 500,7 nm (verde-azzurro), SII a 671,6 nm. '
          'Sono le "regioni HII", culle di stelle: dentro ci sono spesso ammassi appena nati.';
    case 'PN':
      return 'Guscio di gas espulso da una stella di massa simile al Sole alla fine della sua vita. Il nucleo rimasto, '
          'una nana bianca caldissima (fino a 100.000 K e oltre), ionizza il gas che brilla soprattutto in OIII e H-alfa. '
          'Dura poche decine di migliaia di anni: per questo è un oggetto raro. Il nome "planetaria" viene dal '
          'Settecento, quando al telescopio sembravano dischetti come i pianeti.';
    case 'SNR':
      return 'Ciò che resta dell\'esplosione di una supernova: gas espulso a migliaia di km/s che si scontra con il '
          'mezzo interstellare e lo riscalda con onde d\'urto. Brilla in H-alfa, OIII e SII con filamenti sottili. '
          'Può essere esteso molti gradi e restare visibile per decine di migliaia di anni.';
    case 'MIX':
      return 'Regione con due componenti: gas ionizzato che emette luce propria (rosso, H-alfa) e polvere che '
          'riflette la luce delle stelle vicine (azzurro). Il colore complessivo dipende dal peso delle due parti.';
    case 'RN':
      return 'Nube di polvere che non emette luce propria: riflette e diffonde la luce di stelle vicine. I granelli '
          'di polvere diffondono di più la luce blu, come l\'atmosfera di giorno, per questo appare azzurra. Lo spettro '
          'è quello continuo della stella che la illumina: i filtri a banda stretta non aiutano.';
    case 'DN':
      return 'Nube densa di polvere e gas freddo (pochi kelvin sopra lo zero assoluto) che blocca la luce delle stelle '
          'e del gas dietro di lei: si vede come una "macchia" scura su un fondo luminoso. Dentro le più dense nascono '
          'nuove stelle. Si fotografano solo con cieli bui e lunghe integrazioni a banda larga.';
    case 'NEB':
      return 'Nebulosa di natura non indicata nel catalogo: può essere a emissione, a riflessione o entrambe.';
    case 'GAL':
      return 'Sistema indipendente di miliardi di stelle, gas, polvere e materia oscura, fuori dalla Via Lattea. '
          'La luce che fotografi è partita milioni di anni fa. Lo spettro è continuo (luce di stelle), con regioni HII '
          'rosse lungo i bracci delle spirali.';
    case 'GC':
      return 'Ammasso sferico di centinaia di migliaia di stelle molto vecchie (10–13 miliardi di anni), legate dalla '
          'gravità in poche decine di anni luce. Orbitano nell\'alone della galassia, lontano dal disco. Sono tra gli '
          'oggetti più antichi che si possano osservare.';
    case 'OC':
      return 'Gruppo di decine o centinaia di stelle nate dalla stessa nube, con la stessa età e composizione chimica. '
          'Sono giovani (da pochi milioni a qualche miliardo di anni) e stanno nel disco della Via Lattea; con il tempo '
          'le forze di marea le disperdono.';
    case 'AST':
      return 'Gruppo di stelle giovani con origine comune ma non legate dalla gravità: si stanno allontanando tra loro.';
    default:
      return '';
  }
}

/// Spiegazione della classe morfologica del catalogo, se la si sa leggere.
String? morphExplanation(DsObject o) {
  final String m = o.morph.trim();
  if (m.isEmpty) return null;
  final List<String> out = <String>[];

  // Trumpler (ammassi aperti): es. III2p, I3rn.
  final RegExpMatch? tr = RegExp(r'\b(IV|III|II|I)([123])([prm])(n?)\b').firstMatch(m);
  if (tr != null && (o.type == 'OC' || o.type == 'AST' || o.type == 'EN' || o.type == 'MIX')) {
    const Map<String, String> conc = <String, String>{
      'I': 'molto concentrato verso il centro',
      'II': 'poco concentrato verso il centro',
      'III': 'senza concentrazione verso il centro',
      'IV': 'poco distinto dal campo stellare',
    };
    const Map<String, String> range = <String, String>{
      '1': 'stelle di luminosità simile',
      '2': 'stelle di luminosità moderatamente diversa',
      '3': 'stelle brillanti e deboli insieme',
    };
    const Map<String, String> rich = <String, String>{'p': 'povero (meno di 50 stelle)', 'm': 'medio (50–100 stelle)', 'r': 'ricco (oltre 100 stelle)'};
    out.add('Classe di Trumpler ${tr.group(0)}: ${conc[tr.group(1)]}, ${range[tr.group(2)]}, ${rich[tr.group(3)]}'
        '${tr.group(4) == 'n' ? ', con nebulosità associata' : ''}.');
  }

  // Sharpless (nebulose a emissione): forma, struttura, luminosità, es. "3, 2, 3".
  final RegExpMatch? sh = RegExp(r'\b([123]), ([123]), ([123])\b').firstMatch(m);
  if (sh != null) {
    const List<String> form = <String>['circolare', 'ellittica', 'irregolare'];
    const List<String> str = <String>['amorfa', 'con struttura normale', 'filamentosa'];
    const List<String> lum = <String>['debole', 'di media luminosità', 'brillante'];
    out.add('Classe Sharpless ${sh.group(0)}: forma ${form[int.parse(sh.group(1)!) - 1]}, '
        'struttura ${str[int.parse(sh.group(2)!) - 1]}, ${lum[int.parse(sh.group(3)!) - 1]}.');
  }

  // van den Bergh (nebulose a riflessione): "I, VBR".
  final RegExpMatch? vdb = RegExp(r'\b(I|II|III), (VBR|BR|M|F|VF)\b').firstMatch(m);
  if (vdb != null) {
    const Map<String, String> kind = <String, String>{
      'I': 'la stella che la illumina è dentro la nebulosa',
      'II': 'la stella è al bordo della nebulosa',
      'III': 'la stella è separata dalla nebulosa',
    };
    const Map<String, String> br = <String, String>{'VBR': 'molto brillante', 'BR': 'brillante', 'M': 'di media luminosità', 'F': 'debole', 'VF': 'molto debole'};
    out.add('Classe ${vdb.group(0)} (catalogo van den Bergh/Cederblad): ${kind[vdb.group(1)]}, ${br[vdb.group(2)]}.');
  }

  // Shapley-Sawyer (globulari): I–XII.
  if (o.type == 'GC') {
    final RegExpMatch? ss = RegExp(r'^(XII|XI|X|IX|VIII|VII|VI|V|IV|III|II|I)$').firstMatch(m);
    if (ss != null) {
      out.add('Classe di Shapley-Sawyer ${ss.group(0)}: la scala va da I (stelle molto addensate al centro) '
          'a XII (distribuzione quasi uniforme).');
    }
  }

  // Galassie: Hubble / de Vaucouleurs e nucleo attivo.
  if (o.type == 'GAL') {
    final String h = m.split(',').first.trim();
    String? kind;
    if (RegExp(r'^E\d?').hasMatch(h) || h.startsWith('cE')) {
      final RegExpMatch? e = RegExp(r'E(\d)').firstMatch(h);
      kind = 'ellittica${e != null ? ' (E${e.group(1)}: 0 = rotonda, 7 = molto schiacciata)' : ''}: stelle vecchie, poco gas, niente bracci';
    } else if (h.contains('S0')) {
      kind = 'lenticolare: disco e nucleo come una spirale, ma senza bracci e con poca formazione stellare';
    } else if (RegExp(r'^\(?R?\)?\s*S').hasMatch(h)) {
      final bool bar = h.contains('SB');
      final bool weak = h.contains('SAB');
      final RegExpMatch? arm = RegExp(r'\)?(a|ab|b|bc|c|cd|d|dm|m)\b').firstMatch(h.replaceAll(RegExp(r'\(.*?\)'), ''));
      const Map<String, String> arms = <String, String>{
        'a': 'bracci molto avvolti e nucleo grande',
        'ab': 'bracci avvolti e nucleo grande',
        'b': 'bracci moderatamente aperti',
        'bc': 'bracci abbastanza aperti',
        'c': 'bracci aperti e nucleo piccolo',
        'cd': 'bracci molto aperti e nucleo piccolo',
        'd': 'bracci frammentati e nucleo quasi assente',
        'dm': 'struttura quasi irregolare',
        'm': 'tipo Magellanico, quasi irregolare',
      };
      kind = 'spirale${weak ? ' con barra debole' : bar ? ' barrata' : ''}'
          '${arm != null && arms.containsKey(arm.group(1)) ? ', ${arms[arm.group(1)]}' : ''}';
    } else if (h.startsWith('I') || h.startsWith('Im') || h.startsWith('IB')) {
      kind = 'irregolare: senza forma definita, spesso ricca di gas e stelle giovani';
    }
    if (kind != null) out.add('Classe $h: galassia $kind.');
    if (m.contains('Sy')) out.add('Nucleo attivo di tipo Seyfert: al centro c\'è un buco nero supermassiccio che accresce materia e rende il nucleo molto brillante.');
    if (m.contains('LINER')) out.add('Nucleo LINER: il centro emette righe di atomi poco ionizzati, segno di un\'attività del nucleo debole.');
    if (m.contains('HII')) out.add('Nucleo con regioni HII: intensa formazione stellare al centro.');
  }
  return out.isEmpty ? null : out.join(' ');
}
