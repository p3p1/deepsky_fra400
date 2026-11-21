// Lettura delle Release pubblicate su GitHub (senza dipendenze da Flutter,
// così si può verificare anche fuori dall'app).

const String kReleaseRepo = 'p3p1/deepsky_fra400';

class Release {
  const Release({required this.build, required this.name, required this.apkUrl, required this.apkSize, required this.notes});

  final int build; // numero di versione Android (versionCode)
  final String name;
  final String apkUrl;
  final int apkSize;
  final String notes;
}

/// Ricava l'ultima release dalla risposta dell'API di GitHub. Il tag deve
/// essere nella forma "build-<numero>" e la release deve contenere un .apk.
Release? parseRelease(Map<String, dynamic> j) {
  final Object? tag = j['tag_name'];
  if (tag is! String) return null;
  final RegExpMatch? m = RegExp(r'^build-(\d+)$').firstMatch(tag);
  if (m == null) return null;
  final Object? assets = j['assets'];
  if (assets is! List) return null;
  for (final Object? a in assets) {
    if (a is! Map<String, dynamic>) continue;
    final Object? name = a['name'];
    final Object? url = a['browser_download_url'];
    if (name is String && url is String && name.toLowerCase().endsWith('.apk')) {
      return Release(
        build: int.parse(m.group(1)!),
        name: (j['name'] as String?)?.trim().isNotEmpty == true ? (j['name'] as String).trim() : tag,
        apkUrl: url,
        apkSize: a['size'] is int ? a['size'] as int : 0,
        notes: (j['body'] as String?) ?? '',
      );
    }
  }
  return null;
}
