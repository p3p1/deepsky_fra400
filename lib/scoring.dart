// Calcoli pesanti eseguiti fuori dal thread dell'interfaccia: ore utili per
// mese (per il punteggio) e finestra di ogni oggetto in una notte precisa.

import 'dart:math' as math;
import 'dart:typed_data';

import 'astro.dart';

class SiteParams {
  const SiteParams({
    required this.lat,
    required this.lon,
    required this.altMin,
    required this.altMax,
    required this.azFrom,
    required this.azTo,
  });
  final double lat;
  final double lon;
  final double altMin;
  final double altMax;
  final double azFrom;
  final double azTo;
}

class MonthlyRequest {
  const MonthlyRequest(this.ra, this.dec, this.site, this.year);
  final Float64List ra;
  final Float64List dec;
  final SiteParams site;
  final int year;
}

const int _stepMinutes = 6;

/// Tempi siderali locali (gradi) dei campioni di notte astronomica tra il
/// mezzogiorno di [day] e quello successivo.
List<double> _nightLst(DateTime day, SiteParams site, List<DateTime>? times) {
  final DateTime start = DateTime(day.year, day.month, day.day, 12);
  final List<double> out = <double>[];
  for (int m = 0; m <= 24 * 60; m += _stepMinutes) {
    final DateTime t = start.add(Duration(minutes: m));
    final double jd = julianDate(t);
    if (sunAltitude(jd, site.lat, site.lon) <= -18.0) {
      out.add(gmstDeg(jd) + site.lon);
      times?.add(t);
    }
  }
  return out;
}

class _Geometry {
  _Geometry(SiteParams site)
      : sinLat = math.sin(site.lat * kDeg),
        cosLat = math.cos(site.lat * kDeg);
  final double sinLat;
  final double cosLat;
}

/// Ore per notte dentro la finestra del sito, per ogni oggetto e per ogni mese
/// (giorno 15). Risultato: n × 12 valori.
Float32List computeMonthlyHours(MonthlyRequest req) {
  final int n = req.ra.length;
  final Float32List out = Float32List(n * 12);
  final _Geometry g = _Geometry(req.site);
  final bool allAz = (norm360(req.site.azFrom) - norm360(req.site.azTo)).abs() < 1e-9 ||
      (req.site.azFrom == 0 && req.site.azTo == 360);
  final double sinMin = math.sin(req.site.altMin * kDeg);
  final double sinMax = math.sin(math.min(req.site.altMax, 90.0) * kDeg);
  for (int month = 0; month < 12; month++) {
    final List<double> lst = _nightLst(DateTime(req.year, month + 1, 15), req.site, null);
    if (lst.isEmpty) continue;
    for (int i = 0; i < n; i++) {
      final double dec = req.dec[i] * kDeg;
      final double sinDec = math.sin(dec);
      final double cosDec = math.cos(dec);
      int count = 0;
      for (final double l in lst) {
        final double h = (l - req.ra[i]) * kDeg;
        final double cosH = math.cos(h);
        final double sinAlt = g.sinLat * sinDec + g.cosLat * cosDec * cosH;
        if (sinAlt < sinMin || sinAlt > sinMax) continue;
        if (!allAz) {
          final double az = math.atan2(-cosDec * math.sin(h), sinDec * g.cosLat - cosDec * g.sinLat * cosH) / kDeg;
          if (!azInSector(az, req.site.azFrom, req.site.azTo)) continue;
        }
        count++;
      }
      out[i * 12 + month] = count * _stepMinutes / 60.0;
    }
  }
  return out;
}

class NightRequest {
  const NightRequest(this.ra, this.dec, this.site, this.day);
  final Float64List ra;
  final Float64List dec;
  final SiteParams site;
  final DateTime day;
}

/// Finestra di un oggetto in una notte: valori per oggetto, in quest'ordine:
/// ore utili, minuti dall'inizio del giorno di calcolo per inizio e fine,
/// azimut e altezza all'inizio, azimut e altezza alla fine.
class NightResult {
  const NightResult(this.values, this.dayStart);
  final Float32List values; // n × 7
  final DateTime dayStart; // mezzogiorno locale da cui partono i minuti
  static const int stride = 7;
}

NightResult computeNight(NightRequest req) {
  final int n = req.ra.length;
  final Float32List out = Float32List(n * NightResult.stride);
  final DateTime start = DateTime(req.day.year, req.day.month, req.day.day, 12);
  final List<DateTime> times = <DateTime>[];
  final List<double> lst = _nightLst(req.day, req.site, times);
  final _Geometry g = _Geometry(req.site);
  final SkyWindow w = SkyWindow(
    altMin: req.site.altMin,
    altMax: req.site.altMax,
    azFrom: req.site.azFrom,
    azTo: req.site.azTo,
  );
  for (int i = 0; i < n; i++) {
    final double dec = req.dec[i] * kDeg;
    final double sinDec = math.sin(dec);
    final double cosDec = math.cos(dec);
    int count = 0;
    int first = -1;
    int last = -1;
    double az0 = 0, alt0 = 0, az1 = 0, alt1 = 0;
    for (int k = 0; k < lst.length; k++) {
      final double h = (lst[k] - req.ra[i]) * kDeg;
      final double cosH = math.cos(h);
      final double sinAlt = (g.sinLat * sinDec + g.cosLat * cosDec * cosH).clamp(-1.0, 1.0);
      final double alt = math.asin(sinAlt) / kDeg;
      if (alt < w.altMin || alt > w.altMax) continue;
      final double az = norm360(math.atan2(-cosDec * math.sin(h), sinDec * g.cosLat - cosDec * g.sinLat * cosH) / kDeg);
      if (!azInSector(az, w.azFrom, w.azTo)) continue;
      if (first < 0) {
        first = k;
        az0 = az;
        alt0 = alt;
      }
      last = k;
      az1 = az;
      alt1 = alt;
      count++;
    }
    final int o = i * NightResult.stride;
    out[o] = count * _stepMinutes / 60.0;
    out[o + 1] = first < 0 ? -1 : times[first].difference(start).inMinutes.toDouble();
    out[o + 2] = last < 0 ? -1 : times[last].difference(start).inMinutes.toDouble();
    out[o + 3] = az0;
    out[o + 4] = alt0;
    out[o + 5] = az1;
    out[o + 6] = alt1;
  }
  return NightResult(out, start);
}

double windowFactor(double hours) {
  if (hours >= 4) return 1.0;
  if (hours >= 2.5) return 0.85;
  if (hours >= 1.5) return 0.65;
  if (hours >= 0.5) return 0.4;
  return 0.0;
}

double altitudeFactor(double altMax, double altMin) {
  if (altMax >= 40) return 1.0;
  if (altMax >= 30) return 0.9;
  if (altMax >= 20) return 0.7;
  if (altMax >= altMin) return 0.5;
  return 0.0;
}
