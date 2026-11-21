#!/usr/bin/env python3
"""Crea il pacchetto offline delle immagini di repertorio.

Per ogni oggetto di assets/catalog.json scarica un ritaglio di una survey
fotografica del cielo dal servizio hips2fits del CDS di Strasburgo, provando
più fonti in ordine, e scrive due file:

  repertorio.bin   tutte le immagini JPEG una dopo l'altra
  repertorio.json  indice: per ogni sigla posizione e lunghezza nel .bin,
                   campo inquadrato in gradi e fonte dell'immagine

L'app scarica questi due file una volta sola e legge le immagini dal .bin.
Gira su GitHub Actions (ha accesso libero a internet).
"""
import concurrent.futures as cf
import io
import json
import math
import sys
import threading
import time
import urllib.parse
import urllib.request

from PIL import Image, ImageStat

W, H = 480, 360
QUALITY = 74
HOSTS = ('alasky.cds.unistra.fr', 'alaskybis.cds.unistra.fr')

# Fonti (HiPS a colori). Le chiavi sono quelle che l'app usa per i crediti.
SOURCES = {
    'dss2': 'CDS/P/DSS2/color',
    'panstarrs': 'CDS/P/PanSTARRS/DR1/color-z-zg-g',
    'mellinger': 'CDS/P/Mellinger/color',
}


def fov_deg(major_arcmin):
    """Campo dell'immagine sul lato lungo, uguale a quello usato nell'app."""
    d = major_arcmin / 60.0 * 1.8 if major_arcmin and major_arcmin > 0 else 0.5
    return min(max(d, 0.15), 6.0)


def source_order(fov, dec):
    # Mellinger ha risoluzione bassa: va bene solo per i campi molto grandi.
    if fov >= 3.0:
        return ['mellinger', 'dss2']
    order = ['dss2']
    if dec > -29:
        order.append('panstarrs')  # Pan-STARRS non copre il cielo australe profondo
    if fov >= 1.5:
        order.append('mellinger')
    return order


def fetch(hips, ra, dec, fov):
    q = urllib.parse.urlencode({
        'hips': hips, 'width': W, 'height': H, 'fov': f'{fov:.4f}', 'projection': 'TAN',
        'coordsys': 'icrs', 'ra': f'{ra:.5f}', 'dec': f'{dec:.5f}', 'format': 'jpg',
    })
    last = None
    for attempt in range(3):
        host = HOSTS[attempt % len(HOSTS)]
        try:
            req = urllib.request.Request(f'https://{host}/hips-image-services/hips2fits?{q}',
                                         headers={'User-Agent': 'deepsky_fra400-image-pack'})
            with urllib.request.urlopen(req, timeout=90) as r:
                data = r.read()
                if r.status == 200 and data[:2] == b'\xff\xd8':
                    return data
                last = f'HTTP {r.status}, {len(data)} byte'
        except Exception as e:  # noqa: BLE001 - si riprova sull'altro server
            last = repr(e)
        time.sleep(2 + 3 * attempt)
    raise RuntimeError(last)


def usable(img):
    """Scarta immagini vuote (zone non coperte dalla survey: tutto nero o piatto)."""
    st = ImageStat.Stat(img.convert('L'))
    return st.stddev[0] > 3.0 and st.mean[0] > 2.0


def make(obj):
    fov = fov_deg(obj.get('D') or 0)
    errors = []
    for key in source_order(fov, obj['de']):
        try:
            data = fetch(SOURCES[key], obj['ra'], obj['de'], fov)
            img = Image.open(io.BytesIO(data)).convert('RGB')
            if img.size != (W, H):
                img = img.resize((W, H), Image.LANCZOS)
            if not usable(img):
                errors.append(f'{key}: immagine vuota')
                continue
            out = io.BytesIO()
            img.save(out, 'JPEG', quality=QUALITY, optimize=True, progressive=True)
            return obj['i'], out.getvalue(), fov, key, None
        except Exception as e:  # noqa: BLE001
            errors.append(f'{key}: {e}')
    return obj['i'], None, fov, None, '; '.join(errors)


def main():
    catalog, out_bin, out_idx = sys.argv[1], sys.argv[2], sys.argv[3]
    limit = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    objs = json.load(open(catalog, encoding='utf-8'))['objs']
    if limit:
        objs = objs[:limit]
    items, failures = {}, []
    counts = {k: 0 for k in SOURCES}
    lock = threading.Lock()
    done = 0
    t0 = time.time()
    with open(out_bin, 'wb') as fb, cf.ThreadPoolExecutor(max_workers=6) as ex:
        for oid, data, fov, key, err in ex.map(make, objs):
            with lock:
                done += 1
                if data is None:
                    failures.append([oid, err])
                else:
                    items[oid] = [fb.tell(), len(data), round(fov, 4), key]
                    fb.write(data)
                    counts[key] += 1
                if done % 100 == 0 or done == len(objs):
                    print(f'{done}/{len(objs)} oggetti, {len(failures)} senza immagine, {time.time() - t0:.0f} s', flush=True)
    size = sum(v[1] for v in items.values())
    index = {
        'version': 1,
        'created': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'width': W, 'height': H,
        'bytes': size,
        'sources': counts,
        'items': items,
        'missing': failures,
    }
    json.dump(index, open(out_idx, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print(json.dumps({'immagini': len(items), 'mancanti': len(failures), 'MB': round(size / 1e6, 1), 'fonti': counts}))
    for oid, err in failures[:40]:
        print('manca', oid, '-', err)
    # Il pacchetto è utile solo se copre quasi tutto il catalogo.
    if len(items) < 0.9 * len(objs):
        sys.exit(f'Troppe immagini mancanti: {len(failures)} su {len(objs)}')


if __name__ == '__main__':
    main()
