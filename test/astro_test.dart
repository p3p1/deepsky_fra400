// Controllo dei calcoli astronomici contro valori di riferimento ottenuti
// con astropy per Roma (41,9028° N, 12,4964° E).

import 'dart:math' as math;

import 'package:deepsky_fra400/astro.dart';
import 'package:flutter_test/flutter_test.dart';

const double lat = 41.9028;
const double lon = 12.4964;

/// Distanza in gradi tra due direzioni date come altezza e azimut.
double separation(double alt1, double az1, double alt2, double az2) {
  final double a1 = alt1 * kDeg, a2 = alt2 * kDeg, dz = (az1 - az2) * kDeg;
  final double c = math.sin(a1) * math.sin(a2) + math.cos(a1) * math.cos(a2) * math.cos(dz);
  return math.acos(c.clamp(-1.0, 1.0)) / kDeg;
}

void main() {
  final double jd1 = julianDate(DateTime.utc(2026, 11, 16, 21));
  final double jd2 = julianDate(DateTime.utc(2026, 11, 17, 2, 30));

  test('oggetti deep sky: altezza e azimut entro 0,05°', () {
    Horizontal h = altAzJ2000(13.1046, 56.565, jd1, lat, lon); // NGC 281
    expect(separation(h.alt, h.az, 73.8712, 340.0721), lessThan(0.05));
    h = altAzJ2000(83.8221, -5.3911, jd1, lat, lon); // M 42
    expect(separation(h.alt, h.az, 17.4533, 114.4548), lessThan(0.05));
    h = altAzJ2000(13.1046, 56.565, jd2, lat, lon);
    expect(separation(h.alt, h.az, 32.6394, 319.3827), lessThan(0.05));
    h = altAzJ2000(83.8221, -5.3911, jd2, lat, lon);
    expect(separation(h.alt, h.az, 38.6442, 208.5360), lessThan(0.05));
  });

  test('Sole entro 0,05°', () {
    SunState s = sunState(jd1);
    Horizontal h = altAzOfDate(s.eq.ra, s.eq.dec, jd1, lat, lon);
    expect(separation(h.alt, h.az, -56.5013, 304.5598), lessThan(0.05));
    s = sunState(jd2);
    h = altAzOfDate(s.eq.ra, s.eq.dec, jd2, lat, lon);
    expect(separation(h.alt, h.az, -39.2683, 80.2192), lessThan(0.05));
  });

  test('Luna entro 0,5° e fase entro 2 punti percentuali', () {
    Horizontal h = moonAltAz(jd1, lat, lon);
    expect(separation(h.alt, h.az, 6.991, 239.871), lessThan(0.5));
    expect(moonState(jd1).illumination, closeTo(0.4404, 0.02));
    h = moonAltAz(jd2, lat, lon);
    expect(separation(h.alt, h.az, -49.104, 299.169), lessThan(0.5));
    expect(moonState(jd2).illumination, closeTo(0.4624, 0.02));
  });

  test('punti cardinali e settori di azimut', () {
    expect(cardinal(326.1), 'NO');
    expect(cardinal(348.76), 'N');
    expect(cardinalLong(11.24), 'nord');
    expect(cardinal(22.5), 'NNE');
    expect(azInSector(350, 180, 360), isTrue);
    expect(azInSector(10, 180, 360), isFalse);
    expect(azInSector(10, 300, 60), isTrue);
  });

  test('orbite: al perielio la distanza dal Sole è q, anche per parabole e iperboli', () {
    for (final double e in <double>[0.5, 0.999999, 1.0, 1.000001, 1.3]) {
      final CometElements el = CometElements(
        name: 'prova', perihelionJd: 2461000.5, q: 1.2, e: e, argPeri: 30, node: 60, incl: 20, h: 8, g: 4);
      expect(cometPosition(el, 2461000.5).sunDist, closeTo(1.2, 1e-6));
      expect(cometPosition(el, 2461060.5).sunDist, greaterThan(1.2));
    }
  });
}
