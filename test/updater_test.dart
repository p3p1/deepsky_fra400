// Lettura della risposta di GitHub sulle Release, usata per gli aggiornamenti.

import 'package:deepsky_fra400/release_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release con APK e tag build-N', () {
    final Release? r = parseRelease(<String, dynamic>{
      'tag_name': 'build-142',
      'name': 'Versione 1.2.42',
      'body': 'note',
      'assets': <dynamic>[
        <String, dynamic>{'name': 'note.txt', 'browser_download_url': 'https://x/n.txt', 'size': 3},
        <String, dynamic>{'name': 'deepsky_fra400-142.apk', 'browser_download_url': 'https://x/a.apk', 'size': 1234},
      ],
    });
    expect(r, isNotNull);
    expect(r!.build, 142);
    expect(r.name, 'Versione 1.2.42');
    expect(r.apkUrl, 'https://x/a.apk');
    expect(r.apkSize, 1234);
  });

  test('tag non riconosciuto o nessun APK', () {
    expect(parseRelease(<String, dynamic>{'tag_name': 'v1.0', 'assets': <dynamic>[]}), isNull);
    expect(parseRelease(<String, dynamic>{'tag_name': 'build-5', 'assets': <dynamic>[]}), isNull);
  });
}
