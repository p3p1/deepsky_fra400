// Impostazioni dell'app: le due posizioni (casa e trasferta), i limiti del
// cielo visibile e le correzioni per la vista AR. Salvate sul dispositivo.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'astro.dart';

enum SiteMode { home, travel }

/// Valori predefiniti della posizione "Casa". Si cambiano dall'app
/// (Impostazioni) senza toccare il codice.
const String kDefaultHomeName = 'Roma';
const double kDefaultHomeLat = 41.9028;
const double kDefaultHomeLon = 12.4964;

class AppSettings {
  AppSettings();

  SiteMode mode = SiteMode.home;

  // Casa: posizione fissa con i limiti del balcone.
  String homeName = kDefaultHomeName;
  double homeLat = kDefaultHomeLat;
  double homeLon = kDefaultHomeLon;
  double homeAltMin = 15;
  double homeAltMax = 45;
  double homeAzFrom = 180; // da sud...
  double homeAzTo = 360; // ...a nord, passando per ovest
  bool homeUrban = true;

  // Trasferta: posizione presa dal GPS, cielo libero.
  double? travelLat;
  double? travelLon;
  DateTime? travelFix;
  double travelAltMin = 15;
  bool travelUrban = false;

  // Vista AR.
  double compassOffset = 4.0; // gradi da sommare alla bussola (declinazione magnetica + taratura)
  double cameraFov = 62.0; // campo verticale della fotocamera, gradi

  bool get hasTravelFix => travelLat != null && travelLon != null;
  bool get isHome => mode == SiteMode.home;

  /// Se la trasferta non ha ancora una posizione GPS si usano le coordinate di casa.
  double get lat => isHome || !hasTravelFix ? homeLat : travelLat!;
  double get lon => isHome || !hasTravelFix ? homeLon : travelLon!;
  bool get urban => isHome ? homeUrban : travelUrban;
  String get siteName => isHome ? homeName : 'Trasferta';

  SkyWindow get window => isHome
      ? SkyWindow(altMin: homeAltMin, altMax: homeAltMax, azFrom: homeAzFrom, azTo: homeAzTo)
      : SkyWindow(altMin: travelAltMin, altMax: 90, azFrom: 0, azTo: 360);

  /// Ore minime per notte perché un mese conti come "utile".
  double get monthThreshold => isHome ? 1.5 : 2.0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.name,
        'homeName': homeName,
        'homeLat': homeLat,
        'homeLon': homeLon,
        'homeAltMin': homeAltMin,
        'homeAltMax': homeAltMax,
        'homeAzFrom': homeAzFrom,
        'homeAzTo': homeAzTo,
        'homeUrban': homeUrban,
        'travelLat': travelLat,
        'travelLon': travelLon,
        'travelFix': travelFix?.toIso8601String(),
        'travelAltMin': travelAltMin,
        'travelUrban': travelUrban,
        'compassOffset': compassOffset,
        'cameraFov': cameraFov,
      };

  void applyJson(Map<String, dynamic> j) {
    double d(String k, double fallback) => j[k] is num ? (j[k] as num).toDouble() : fallback;
    mode = j['mode'] == 'travel' ? SiteMode.travel : SiteMode.home;
    homeName = j['homeName'] is String ? j['homeName'] as String : homeName;
    homeLat = d('homeLat', homeLat);
    homeLon = d('homeLon', homeLon);
    homeAltMin = d('homeAltMin', homeAltMin);
    homeAltMax = d('homeAltMax', homeAltMax);
    homeAzFrom = d('homeAzFrom', homeAzFrom);
    homeAzTo = d('homeAzTo', homeAzTo);
    homeUrban = j['homeUrban'] is bool ? j['homeUrban'] as bool : homeUrban;
    travelLat = j['travelLat'] is num ? (j['travelLat'] as num).toDouble() : null;
    travelLon = j['travelLon'] is num ? (j['travelLon'] as num).toDouble() : null;
    travelFix = j['travelFix'] is String ? DateTime.tryParse(j['travelFix'] as String) : null;
    travelAltMin = d('travelAltMin', travelAltMin);
    travelUrban = j['travelUrban'] is bool ? j['travelUrban'] as bool : travelUrban;
    compassOffset = d('compassOffset', compassOffset);
    cameraFov = d('cameraFov', cameraFov);
  }

  static const String _key = 'settings_v1';

  static Future<AppSettings> load() async {
    final AppSettings s = AppSettings();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw != null) {
        final Object? j = jsonDecode(raw);
        if (j is Map<String, dynamic>) s.applyJson(j);
      }
    } catch (_) {
      // Impostazioni illeggibili: si riparte dai valori predefiniti.
    }
    return s;
  }

  Future<void> save() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {
      // Il salvataggio è una comodità: l'app funziona anche senza.
    }
  }
}
