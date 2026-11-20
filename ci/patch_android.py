#!/usr/bin/env python3
"""Aggiunge nome dell'app e permessi al manifest generato da `flutter create`."""
import pathlib
import sys

path = pathlib.Path('android/app/src/main/AndroidManifest.xml')
text = path.read_text(encoding='utf-8')

permissions = '''    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
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
path.write_text(text, encoding='utf-8')
print('AndroidManifest.xml aggiornato')
