#!/usr/bin/env python3
"""Aggiunge nome dell'app e permessi al manifest generato da `flutter create`."""
import pathlib
import os
import sys

path = pathlib.Path('android/app/src/main/AndroidManifest.xml')
text = path.read_text(encoding='utf-8')

permissions = '''    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="false"/>
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
    <uses-feature android:name="android.hardware.location.gps" android:required="false"/>
    <uses-feature android:name="android.hardware.sensor.compass" android:required="false"/>
'''

if '<application' not in text:
    sys.exit('AndroidManifest.xml: tag <application> non trovato')
if 'android.permission.CAMERA' not in text:
    text = text.replace('    <application', permissions + '    <application', 1)
if 'android:label="deepsky_fra400"' in text:
    text = text.replace('android:label="deepsky_fra400"', 'android:label="Deep Sky FRA400"', 1)
else:
    print('Attenzione: etichetta dell\'app non trovata, resta il nome predefinito')
# Android 11+: per aprire i link (Wikipedia, SIMBAD...) nel browser.
view_https = '''        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
'''
if 'android.intent.action.VIEW' not in text:
    if '<queries>' in text:
        text = text.replace('<queries>', '<queries>\n' + view_https, 1)
    else:
        text = text.replace('</manifest>', '    <queries>\n' + view_https + '    </queries>\n</manifest>', 1)
path.write_text(text, encoding='utf-8')
print('AndroidManifest.xml aggiornato')

# permission_handler_android richiede di compilare contro Android SDK 37.
# Cambia solo l'SDK di compilazione: targetSdk e minSdk restano quelli di Flutter.
COMPILE_SDK = 37
gradle = pathlib.Path('android/app/build.gradle.kts')
if not gradle.exists():
    gradle = pathlib.Path('android/app/build.gradle')
g = gradle.read_text(encoding='utf-8')
for old in ('compileSdk = flutter.compileSdkVersion', 'compileSdkVersion flutter.compileSdkVersion', 'compileSdk flutter.compileSdkVersion'):
    if old in g:
        g = g.replace(old, f'compileSdk = {COMPILE_SDK}' if '=' in old else f'compileSdk {COMPILE_SDK}', 1)
        break
else:
    sys.exit(f'{gradle}: riga compileSdk non trovata')

# Firma sempre con la stessa chiave, qualunque sia la macchina di build:
# Android installa un aggiornamento solo se la firma è la stessa.
# Con le variabili SIGN_* (impostate dal workflow quando il segreto
# RELEASE_KEY_PASSWORD c'è) usa la chiave personale ci/release.keystore,
# altrimenti la chiave di prova ci/debug.keystore. La password non viene
# scritta nei file: Gradle la legge dall'ambiente.
store = os.environ.get('SIGN_STORE', '../ci/debug.keystore')
alias = os.environ.get('SIGN_ALIAS', 'androiddebugkey')
if 'SIGN_PASS' not in os.environ:
    os.environ['SIGN_PASS'] = 'android'
if gradle.suffix == '.kts':
    signing = '''    signingConfigs {
        create("fixed") {
            storeFile = rootProject.file("STORE")
            storePassword = System.getenv("SIGN_PASS") ?: "android"
            keyAlias = "ALIAS"
            keyPassword = System.getenv("SIGN_PASS") ?: "android"
        }
    }

    buildTypes {'''
    use_old, use_new = 'signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("fixed")'
else:
    signing = '''    signingConfigs {
        fixed {
            storeFile rootProject.file("STORE")
            storePassword System.getenv("SIGN_PASS") ?: "android"
            keyAlias "ALIAS"
            keyPassword System.getenv("SIGN_PASS") ?: "android"
        }
    }

    buildTypes {'''
    use_old, use_new = 'signingConfig signingConfigs.debug', 'signingConfig signingConfigs.fixed'
if use_old not in g or '    buildTypes {' not in g:
    sys.exit(f'{gradle}: configurazione di firma non trovata')
signing = signing.replace('STORE', store).replace('ALIAS', alias)
g = g.replace('    buildTypes {', signing, 1).replace(use_old, use_new, 1)
gradle.write_text(g, encoding='utf-8')
print(f'{gradle}: compileSdk = {COMPILE_SDK}, firma con {store} ({alias})')
