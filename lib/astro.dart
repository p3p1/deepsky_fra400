// Calcoli astronomici usati dall'app. Tutto gira offline.
//
// Precisione attesa: oggetti deep sky e Sole entro 0,05°, Luna entro 0,5°,
// comete entro 0,5° (orbita kepleriana senza perturbazioni).
// Fonti delle formule: J. Meeus, "Astronomical Algorithms" (precessione,
// tempo siderale, Keplero) e Astronomical Almanac (Sole e Luna a bassa precisione).

import 'dart:math' as math;

const double kDeg = math.pi / 180.0;
const double kGauss = 0.01720209895; // costante di Gauss, rad/giorno

double _rad(double d) => d * kDeg;
double _deg(double r) => r / kDeg;
double norm360(double d) {
  final double r = d % 360.0;
  return r < 0 ? r + 360.0 : r;
}

/// Differenza angolare a-b riportata in (-180, 180].
double angDiff(double a, double b) {
  double d = (a - b) % 360.0;
  if (d > 180.0) d -= 360.0;
  if (d <= -180.0) d += 360.0;
  return d;
}

double julianDate(DateTime t) => t.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

/// Tempo siderale medio di Greenwich, in gradi.
double gmstDeg(double jd) {
  final double d = jd - 2451545.0;
  final double t = d / 36525.0;
  return norm360(280.46061837 + 360.98564736629 * d + 0.000387933 * t * t - t * t * t / 38710000.0);
}

class Equatorial {
  const Equatorial(this.ra, this.dec);
  final double ra; // gradi
  final double dec; // gradi
}

class Horizontal {
  const Horizontal(this.alt, this.az);
  final double alt; // gradi sopra l'orizzonte
  final double az; // gradi da nord verso est
}

/// Precessione da J2000 all'equinozio della data (Meeus, cap. 21).
Equatorial precessFromJ2000(double raDeg, double decDeg, double jd) {
  final double t = (jd - 2451545.0) / 36525.0;
  final double zeta = _rad((2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) / 3600.0);
  final double z = _rad((2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) / 3600.0);
  final double theta = _rad((2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) / 3600.0);
  final double ra = _rad(raDeg);
  final double dec = _rad(decDeg);
  final double a = math.cos(dec) * math.sin(ra + zeta);
  final double b = math.cos(theta) * math.cos(dec) * math.cos(ra + zeta) - math.sin(theta) * math.sin(dec);
  final double c = math.sin(theta) * math.cos(dec) * math.cos(ra + zeta) + math.cos(theta) * math.sin(dec);
  return Equatorial(norm360(_deg(math.atan2(a, b) + z)), _deg(math.asin(c.clamp(-1.0, 1.0))));
}

/// Altezza e azimut da coordinate equatoriali della data.
Horizontal altAzOfDate(double raDeg, double decDeg, double jd, double latDeg, double lonDeg) {
  final double h = _rad(gmstDeg(jd) + lonDeg - raDeg);
  final double phi = _rad(latDeg);
  final double dec = _rad(decDeg);
  final double sinAlt = math.sin(phi) * math.sin(dec) + math.cos(phi) * math.cos(dec) * math.cos(h);
  final double alt = math.asin(sinAlt.clamp(-1.0, 1.0));
  final double az = math.atan2(
    -math.cos(dec) * math.sin(h),
    math.sin(dec) * math.cos(phi) - math.cos(dec) * math.sin(phi) * math.cos(h),
  );
  return Horizontal(_deg(alt), norm360(_deg(az)));
}

/// Altezza e azimut di un oggetto dato in coordinate J2000.
Horizontal altAzJ2000(double raDeg, double decDeg, double jd, double latDeg, double lonDeg) {
  final Equatorial e = precessFromJ2000(raDeg, decDeg, jd);
  return altAzOfDate(e.ra, e.dec, jd, latDeg, lonDeg);
}

class SunState {
  const SunState(this.eq, this.lambda, this.dist);
  final Equatorial eq; // equinozio della data
  final double lambda; // longitudine eclittica geocentrica, gradi (della data)
  final double dist; // distanza in UA
}

double _obliquity(double jd) => 23.439 - 0.0000004 * (jd - 2451545.0);

SunState sunState(double jd) {
  final double n = jd - 2451545.0;
  final double l = norm360(280.460 + 0.9856474 * n);
  final double g = _rad(norm360(357.528 + 0.9856003 * n));
  final double lambda = norm360(l + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g));
  final double eps = _rad(_obliquity(jd));
  final double lam = _rad(lambda);
  final double ra = math.atan2(math.cos(eps) * math.sin(lam), math.cos(lam));
  final double dec = math.asin(math.sin(eps) * math.sin(lam));
  final double r = 1.00014 - 0.01671 * math.cos(g) - 0.00014 * math.cos(2 * g);
  return SunState(Equatorial(norm360(_deg(ra)), _deg(dec)), lambda, r);
}

double sunAltitude(double jd, double latDeg, double lonDeg) {
  final SunState s = sunState(jd);
  return altAzOfDate(s.eq.ra, s.eq.dec, jd, latDeg, lonDeg).alt;
}

class MoonState {
  const MoonState(this.eq, this.parallaxDeg, this.illumination);
  final Equatorial eq; // geocentrica, equinozio della data
  final double parallaxDeg; // parallasse orizzontale
  final double illumination; // frazione illuminata, 0..1
}

MoonState moonState(double jd) {
  final double t = (jd - 2451545.0) / 36525.0;
  double s(double a, double b) => math.sin(_rad(a + b * t));
  double c(double a, double b) => math.cos(_rad(a + b * t));
  final double lambda = norm360(218.32 +
      481267.881 * t +
      6.29 * s(135.0, 477198.87) -
      1.27 * s(259.3, -413335.36) +
      0.66 * s(235.7, 890534.22) +
      0.21 * s(269.9, 954397.74) -
      0.19 * s(357.5, 35999.05) -
      0.11 * s(186.5, 966404.03));
  final double beta = 5.13 * s(93.3, 483202.02) +
      0.28 * s(228.2, 960400.89) -
      0.28 * s(318.3, 6003.15) -
      0.17 * s(217.6, -407332.21);
  final double par = 0.9508 +
      0.0518 * c(135.0, 477198.87) +
      0.0095 * c(259.3, -413335.36) +
      0.0078 * c(235.7, 890534.22) +
      0.0028 * c(269.9, 954397.74);
  final double eps = _rad(_obliquity(jd));
  final double lam = _rad(lambda);
  final double bet = _rad(beta);
  final double x = math.cos(bet) * math.cos(lam);
  final double y = math.cos(eps) * math.cos(bet) * math.sin(lam) - math.sin(eps) * math.sin(bet);
  final double z = math.sin(eps) * math.cos(bet) * math.sin(lam) + math.cos(eps) * math.sin(bet);
  final Equatorial eq = Equatorial(norm360(_deg(math.atan2(y, x))), _deg(math.asin(z.clamp(-1.0, 1.0))));
  final SunState sun = sunState(jd);
  final double cosElong = math.sin(_rad(sun.eq.dec)) * math.sin(_rad(eq.dec)) +
      math.cos(_rad(sun.eq.dec)) * math.cos(_rad(eq.dec)) * math.cos(_rad(sun.eq.ra - eq.ra));
  // Angolo di fase ~ 180° - elongazione: frazione illuminata = (1 - cos(elongazione)) / 2.
  final double k = (1 - cosElong.clamp(-1.0, 1.0)) / 2.0;
  return MoonState(eq, par, k);
}

/// Altezza e azimut della Luna visti dall'osservatore (con parallasse).
Horizontal moonAltAz(double jd, double latDeg, double lonDeg) {
  final MoonState m = moonState(jd);
  final Horizontal h = altAzOfDate(m.eq.ra, m.eq.dec, jd, latDeg, lonDeg);
  return Horizontal(h.alt - m.parallaxDeg * math.cos(_rad(h.alt)), h.az);
}

const List<String> kCardinal16 = <String>[
  'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSO', 'SO', 'OSO', 'O', 'ONO', 'NO', 'NNO', //
];
const List<String> kCardinal16Long = <String>[
  'nord', 'nord-nord-est', 'nord-est', 'est-nord-est', 'est', 'est-sud-est', 'sud-est', 'sud-sud-est', //
  'sud', 'sud-sud-ovest', 'sud-ovest', 'ovest-sud-ovest', 'ovest', 'ovest-nord-ovest', 'nord-ovest', 'nord-nord-ovest',
];

int cardinalIndex(double azDeg) => ((norm360(azDeg) + 11.25) ~/ 22.5) % 16;
String cardinal(double azDeg) => kCardinal16[cardinalIndex(azDeg)];
String cardinalLong(double azDeg) => kCardinal16Long[cardinalIndex(azDeg)];

/// Vero se l'azimut cade nel settore che va da [from] a [to] girando verso est
/// (cioè in senso orario sulla bussola). from == to significa tutto l'orizzonte.
bool azInSector(double az, double from, double to) {
  final double a = norm360(az);
  final double f = norm360(from);
  final double t = norm360(to);
  if ((f - t).abs() < 1e-9) return true;
  if (f < t) return a >= f && a <= t;
  return a >= f || a <= t;
}

class SkyWindow {
  const SkyWindow({required this.altMin, required this.altMax, required this.azFrom, required this.azTo});
  final double altMin;
  final double altMax;
  final double azFrom;
  final double azTo;
  bool contains(double alt, double az) => alt >= altMin && alt <= altMax && azInSector(az, azFrom, azTo);
}

class TrackPoint {
  const TrackPoint(this.time, this.alt, this.az, this.sunAlt);
  final DateTime time; // ora locale del dispositivo
  final double alt;
  final double az;
  final double sunAlt;
  bool get isNight => sunAlt <= -18.0;
}

/// Posizione di un oggetto in J2000 in funzione del tempo. Per gli oggetti
/// deep sky è costante; per le comete cambia con la data.
typedef EquatorialAt = Equatorial Function(double jd);

/// Traiettoria dal mezzogiorno locale di [day] al mezzogiorno successivo.
List<TrackPoint> computeTrack({
  required EquatorialAt positionJ2000,
  required double latDeg,
  required double lonDeg,
  required DateTime day,
  int stepMinutes = 5,
}) {
  final DateTime start = DateTime(day.year, day.month, day.day, 12);
  final int n = (24 * 60) ~/ stepMinutes;
  final List<TrackPoint> out = <TrackPoint>[];
  for (int i = 0; i <= n; i++) {
    final DateTime t = start.add(Duration(minutes: i * stepMinutes));
    final double jd = julianDate(t);
    final Equatorial p = positionJ2000(jd);
    final Horizontal h = altAzJ2000(p.ra, p.dec, jd, latDeg, lonDeg);
    out.add(TrackPoint(t, h.alt, h.az, sunAltitude(jd, latDeg, lonDeg)));
  }
  return out;
}

class NightSummary {
  const NightSummary({
    required this.nightStart,
    required this.nightEnd,
    required this.windowStart,
    required this.windowEnd,
    required this.windowHours,
    required this.culmination,
  });
  final DateTime? nightStart; // inizio notte astronomica
  final DateTime? nightEnd;
  final DateTime? windowStart; // primo istante utile (notte + finestra)
  final DateTime? windowEnd;
  final double windowHours;
  final TrackPoint? culmination; // punto più alto durante la notte
}

NightSummary summarizeTrack(List<TrackPoint> track, SkyWindow window, int stepMinutes) {
  DateTime? ns;
  DateTime? ne;
  DateTime? ws;
  DateTime? we;
  int count = 0;
  TrackPoint? top;
  for (final TrackPoint p in track) {
    if (!p.isNight) continue;
    ns ??= p.time;
    ne = p.time;
    if (top == null || p.alt > top.alt) top = p;
    if (window.contains(p.alt, p.az)) {
      ws ??= p.time;
      we = p.time;
      count++;
    }
  }
  return NightSummary(
    nightStart: ns,
    nightEnd: ne,
    windowStart: ws,
    windowEnd: we,
    windowHours: count * stepMinutes / 60.0,
    culmination: top,
  );
}

// ---------------------------------------------------------------- comete

class CometElements {
  const CometElements({
    required this.name,
    required this.perihelionJd,
    required this.q,
    required this.e,
    required this.argPeri,
    required this.node,
    required this.incl,
    required this.h,
    required this.g,
  });
  final String name;
  final double perihelionJd; // istante del perielio (TT), giorno giuliano
  final double q; // distanza al perielio, UA
  final double e; // eccentricità
  final double argPeri; // gradi, J2000
  final double node; // gradi, J2000
  final double incl; // gradi, J2000
  final double? h; // magnitudine assoluta
  final double? g; // parametro di pendenza
}

class CometPosition {
  const CometPosition(this.eq, this.sunDist, this.earthDist, this.magnitude);
  final Equatorial eq; // J2000
  final double sunDist; // UA
  final double earthDist; // UA
  final double? magnitude; // stima: m = H + 5 log Δ + 2,5 G log r
}

double _cbrt(double x) => x < 0 ? -math.pow(-x, 1.0 / 3.0).toDouble() : math.pow(x, 1.0 / 3.0).toDouble();
double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2.0;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2.0;

/// Posizione nel piano orbitale (x verso il perielio), in UA.
List<double> _orbitPlane(double q, double e, double dt) {
  if ((e - 1.0).abs() < 1e-8) {
    // Parabola: equazione di Barker.
    final double w = 3.0 * kGauss / math.sqrt(2.0) * dt / math.pow(q, 1.5);
    final double y = _cbrt(w / 2.0 + math.sqrt(w * w / 4.0 + 1.0));
    final double s = y - 1.0 / y;
    final double r = q * (1.0 + s * s);
    final double nu = 2.0 * math.atan(s);
    return <double>[r * math.cos(nu), r * math.sin(nu)];
  }
  if (e < 1.0) {
    final double a = q / (1.0 - e);
    final double m = kGauss / math.pow(a, 1.5) * dt;
    double mm = m % (2 * math.pi);
    if (mm > math.pi) mm -= 2 * math.pi;
    if (mm < -math.pi) mm += 2 * math.pi;
    // Bisezione su E in [-pi, pi]: sempre convergente, anche con e vicino a 1.
    double lo = -math.pi;
    double hi = math.pi;
    double ecc = mm;
    for (int i = 0; i < 80; i++) {
      ecc = (lo + hi) / 2.0;
      final double f = ecc - e * math.sin(ecc) - mm;
      if (f > 0) {
        hi = ecc;
      } else {
        lo = ecc;
      }
    }
    return <double>[a * (math.cos(ecc) - e), a * math.sqrt(1.0 - e * e) * math.sin(ecc)];
  }
  final double a = q / (e - 1.0);
  final double m = kGauss / math.pow(a, 1.5) * dt;
  // Iperbole: e sinh H - H = M, con Newton a partire da una stima robusta.
  double hh = m.abs() < 1.0 ? m : (m.isNegative ? -1.0 : 1.0) * math.log(2.0 * m.abs() / e + 1.8);
  for (int i = 0; i < 60; i++) {
    final double f = e * _sinh(hh) - hh - m;
    final double df = e * _cosh(hh) - 1.0;
    final double step = f / df;
    hh -= step;
    if (step.abs() < 1e-13) break;
  }
  return <double>[a * (e - _cosh(hh)), a * math.sqrt(e * e - 1.0) * _sinh(hh)];
}

CometPosition cometPosition(CometElements el, double jd) {
  final List<double> p = _orbitPlane(el.q, el.e, jd - el.perihelionJd);
  final double w = _rad(el.argPeri);
  final double o = _rad(el.node);
  final double i = _rad(el.incl);
  final double cw = math.cos(w), sw = math.sin(w);
  final double co = math.cos(o), so = math.sin(o);
  final double ci = math.cos(i), si = math.sin(i);
  // Eclittiche eliocentriche J2000.
  final double xh = (co * cw - so * sw * ci) * p[0] + (-co * sw - so * cw * ci) * p[1];
  final double yh = (so * cw + co * sw * ci) * p[0] + (-so * sw + co * cw * ci) * p[1];
  final double zh = (sw * si) * p[0] + (cw * si) * p[1];
  // Terra: opposta al Sole geocentrico. La longitudine della data si riporta
  // a J2000 togliendo la precessione generale (1,3970° per secolo).
  final SunState s = sunState(jd);
  final double t = (jd - 2451545.0) / 36525.0;
  final double lamE = _rad(s.lambda - 1.3970 * t + 180.0);
  final double xe = s.dist * math.cos(lamE);
  final double ye = s.dist * math.sin(lamE);
  final double x = xh - xe;
  final double y = yh - ye;
  final double z = zh;
  final double eps = _rad(23.43929111);
  final double xq = x;
  final double yq = y * math.cos(eps) - z * math.sin(eps);
  final double zq = y * math.sin(eps) + z * math.cos(eps);
  final double delta = math.sqrt(x * x + y * y + z * z);
  final double r = math.sqrt(xh * xh + yh * yh + zh * zh);
  final double ra = norm360(_deg(math.atan2(yq, xq)));
  final double dec = _deg(math.asin((zq / delta).clamp(-1.0, 1.0)));
  double? mag;
  if (el.h != null && el.g != null) {
    mag = el.h! + 5.0 * math.log(delta) / math.ln10 + 2.5 * el.g! * math.log(r) / math.ln10;
  }
  return CometPosition(Equatorial(ra, dec), r, delta, mag);
}

/// Giorno giuliano (TT) da data di calendario con giorno frazionario.
double jdFromCalendar(int year, int month, double day) {
  final int whole = day.floor();
  final DateTime d = DateTime.utc(year, month, whole);
  return d.millisecondsSinceEpoch / 86400000.0 + 2440587.5 + (day - whole);
}
