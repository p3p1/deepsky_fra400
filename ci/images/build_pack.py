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
import os
import pathlib
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
# 'skyview' (NASA SkyView, DSS2 rosso) è l'ultima risorsa, vedi fetch().
TIMEOUT = 40


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


class Health:
    """Tiene il conto degli errori di fila per fonte: se una fonte non risponde
    più, la si salta per un po' invece di aspettare i timeout per ogni oggetto."""

    def __init__(self):
        self.lock = threading.Lock()
        self.fails = {}
        self.paused_until = {}

    def ok(self, key):
        with self.lock:
            return time.time() >= self.paused_until.get(key, 0)

    def report(self, key, good):
        with self.lock:
            if good:
                self.fails[key] = 0
                return
            n = self.fails.get(key, 0) + 1
            self.fails[key] = n
            if n >= 8:
                self.paused_until[key] = time.time() + 300
                self.fails[key] = 0
                print(f'fonte {key}: troppi errori di fila, in pausa per 5 minuti', flush=True)


HEALTH = Health()


def http_get(url, timeout=TIMEOUT):
    req = urllib.request.Request(url, headers={'User-Agent': 'deepsky_fra400-image-pack (github.com/p3p1/deepsky_fra400)'})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read()


def fetch(key, ra, dec, fov):
    if key == 'skyview':
        # NASA SkyView: DSS2 rosso, in bianco e nero; ultima risorsa.
        q = urllib.parse.urlencode({
            'Position': f'{ra:.5f},{dec:.5f}', 'Coordinates': 'J2000', 'Survey': 'DSS2 Red',
            'Pixels': f'{W},{H}', 'Size': f'{fov:.4f},{fov * H / W:.4f}', 'Return': 'JPEG',
            'Scaling': 'Log',
        })
        urls = [f'https://skyview.gsfc.nasa.gov/current/cgi/runquery.pl?{q}']
    else:
        q = urllib.parse.urlencode({
            'hips': SOURCES[key], 'width': W, 'height': H, 'fov': f'{fov:.4f}', 'projection': 'TAN',
            'coordsys': 'icrs', 'ra': f'{ra:.5f}', 'dec': f'{dec:.5f}', 'format': 'jpg',
        })
        urls = [f'https://{h}/hips-image-services/hips2fits?{q}' for h in HOSTS]
    last = None
    for attempt, url in enumerate(urls * 2):
        try:
            status, data = http_get(url)
            if status == 200 and data[:2] == b'\xff\xd8':
                return data
            last = f'HTTP {status}, {len(data)} byte'
        except Exception as e:  # noqa: BLE001 - si riprova sull'altro server
            last = repr(e)
        time.sleep(1 + 2 * attempt)
    raise RuntimeError(last)


def usable(img):
    """Scarta immagini vuote (zone non coperte dalla survey: tutto nero o piatto)."""
    st = ImageStat.Stat(img.convert('L'))
    return st.stddev[0] > 3.0 and st.mean[0] > 2.0


def make(obj):
    fov = fov_deg(obj.get('D') or 0)
    errors = []
    for key in source_order(fov, obj['de']) + ['skyview']:
        if not HEALTH.ok(key):
            errors.append(f'{key}: in pausa')
            continue
        try:
            data = fetch(key, obj['ra'], obj['de'], fov)
            HEALTH.report(key, True)
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
            HEALTH.report(key, False)
            errors.append(f'{key}: {e}')
    return obj['i'], None, fov, None, '; '.join(errors)


def safe(oid):
    return ''.join(c if c.isalnum() or c in '-_' else '_' for c in oid)


def main():
    catalog, out_bin, out_idx = sys.argv[1], sys.argv[2], sys.argv[3]
    limit = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else 0
    # Cartella con le immagini già scaricate nelle esecuzioni precedenti
    # (conservata da actions/cache): si scarica solo quello che manca.
    cache = pathlib.Path(sys.argv[5] if len(sys.argv) > 5 else 'cache')
    budget = float(os.environ.get('TIME_BUDGET_MIN', '200')) * 60
    cache.mkdir(parents=True, exist_ok=True)
    objs = json.load(open(catalog, encoding='utf-8'))['objs']
    if limit:
        objs = objs[:limit]

    meta_path = cache / 'meta.json'
    meta = json.load(open(meta_path)) if meta_path.exists() else {}
    todo = [o for o in objs if not (o['i'] in meta and (cache / f"{safe(o['i'])}.jpg").exists())]
    print(f'{len(objs)} oggetti, {len(objs) - len(todo)} già scaricati, {len(todo)} da scaricare', flush=True)

    t0 = time.time()
    # Prova iniziale, così il log dice subito se le fonti rispondono.
    for key in ('dss2', 'skyview'):
        t = time.time()
        try:
            fetch(key, 83.822, -5.391, 1.0)
            print(f'prova {key}: ok in {time.time() - t:.1f} s', flush=True)
        except Exception as e:  # noqa: BLE001
            print(f'prova {key}: ERRORE {e}', flush=True)

    failures = {}
    done = 0
    stopped = False
    lock = threading.Lock()
    ex = cf.ThreadPoolExecutor(max_workers=6)
    futures = [ex.submit(make, o) for o in todo]
    try:
        for fut in cf.as_completed(futures):
            oid, data, fov, key, err = fut.result()
            with lock:
                done += 1
                if data is None:
                    failures[oid] = err
                else:
                    (cache / f'{safe(oid)}.jpg').write_bytes(data)
                    meta[oid] = [round(fov, 4), key]
                if done % 50 == 0 or done == len(todo):
                    json.dump(meta, open(meta_path, 'w'))
                    print(f'{done}/{len(todo)} scaricati in questa esecuzione, {len(failures)} senza immagine, '
                          f'{time.time() - t0:.0f} s', flush=True)
            if time.time() - t0 > budget and not stopped:
                stopped = True
                print('tempo a disposizione finito: pubblico quello che c\'è, il resto alla prossima esecuzione', flush=True)
                for f in futures:
                    f.cancel()
                break
    finally:
        ex.shutdown(wait=True, cancel_futures=True)
        json.dump(meta, open(meta_path, 'w'))

    items, counts = {}, {}
    with open(out_bin, 'wb') as fb:
        for o in objs:
            m = meta.get(o['i'])
            p = cache / f"{safe(o['i'])}.jpg"
            if not m or not p.exists():
                continue
            data = p.read_bytes()
            items[o['i']] = [fb.tell(), len(data), m[0], m[1]]
            fb.write(data)
            counts[m[1]] = counts.get(m[1], 0) + 1
    size = sum(v[1] for v in items.values())
    missing = [[o['i'], failures.get(o['i'], 'non ancora scaricato')] for o in objs if o['i'] not in items]
    index = {
        'version': 1,
        'created': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'width': W, 'height': H,
        'bytes': size,
        'sources': counts,
        'complete': not missing,
        'items': items,
        'missing': missing,
    }
    json.dump(index, open(out_idx, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print(json.dumps({'immagini': len(items), 'mancanti': len(missing), 'MB': round(size / 1e6, 1), 'fonti': counts}))
    for oid, err in missing[:40]:
        print('manca', oid, '-', err)
    with open(os.environ.get('GITHUB_OUTPUT', os.devnull), 'a') as gh:
        gh.write(f'count={len(items)}\nmissing={len(missing)}\n')
    if not items:
        sys.exit('Nessuna immagine scaricata: le fonti non rispondono.')


if __name__ == '__main__':
    main()
