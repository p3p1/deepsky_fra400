#!/usr/bin/env python3
"""Crea assets/details.json: dettagli scientifici degli oggetti del catalogo.

Per ogni oggetto cerca la voce di Wikidata con la stessa sigla di catalogo
(proprietà P528) e controlla che le coordinate coincidano. Da Wikidata prende
la distanza (P2583, convertita in anni luce), il tipo (P31), di cosa fa parte
(P361) e il redshift (P1090); dalla voce di Wikipedia in italiano, se esiste,
prende il riassunto iniziale. Il file finisce dentro l'app: funziona offline.

Gira su GitHub Actions (ha accesso libero a internet).
"""
import concurrent.futures as cf
import json
import math
import re
import statistics
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

UA = 'deepsky_fra400-details/1.0 (https://github.com/p3p1/deepsky_fra400)'
SPARQL = 'https://query.wikidata.org/sparql'

# Conversione in anni luce delle unità di distanza usate su Wikidata.
LY = {
    'Q531': 1.0,                 # anno luce
    'Q12129': 3.261563777,       # parsec
    'Q11929860': 3261.563777,    # kiloparsec
    'Q3773454': 3.261563777e6,   # megaparsec
    'Q2042279': 3.261563777e9,   # gigaparsec
    'Q1811': 1.581250741e-5,     # unità astronomica
    'Q828224': 1.057000834e-13,  # chilometro
    'Q3042213': 1e6,             # milione di anni luce (megalight-year)
    'Q3042227': 1e9,             # miliardo di anni luce
    'Q3013188': 1e3,             # kilo-anno luce
}
# Tipi Wikidata troppo generici o sbagliati per essere mostrati.
SKIP_TYPES = {'oggetto astronomico', 'corpo celeste', 'oggetto celeste', 'oggetto NGC', 'oggetto IC'}


def get(url, data=None, tries=5, timeout=90):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=data, headers={
                'User-Agent': UA, 'Accept': 'application/sparql-results+json, application/json'})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            last = e
            if e.code == 404:
                return None
            time.sleep(5 * (i + 1) if e.code == 429 else 2 + 2 * i)
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(2 + 2 * i)
    raise RuntimeError(f'{url[:80]}…: {last}')


def variants(code):
    """Le sigle su Wikidata non sono scritte sempre allo stesso modo."""
    code = code.strip()
    out = {code, code.replace(' ', '')}
    m = re.match(r'^([A-Za-z]+)\s*(\d.*)$', code)
    if m:
        out.add(f'{m.group(1)} {m.group(2)}')
        out.add(f'{m.group(1)}{m.group(2)}')
        if m.group(1) == 'B':
            out.add(f'Barnard {m.group(2)}')
        if m.group(1) == 'Sh2':
            out.add(f'Sh 2-{m.group(2)}')
    m = re.match(r'^Sh2-(\d+)$', code)
    if m:
        out |= {f'Sh 2-{m.group(1)}', f'Sharpless {m.group(1)}', f'Sh2 {m.group(1)}'}
    return out


def sep_deg(ra1, de1, ra2, de2):
    r = math.radians
    c = (math.sin(r(de1)) * math.sin(r(de2)) +
         math.cos(r(de1)) * math.cos(r(de2)) * math.cos(r(ra1 - ra2)))
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


QUERY = '''
SELECT ?code ?item ?itemLabel ?ra ?dec ?dist ?unit ?typeLabel ?partLabel ?z ?itwiki WHERE {
  VALUES ?code { %s }
  ?item wdt:P528 ?code .
  OPTIONAL { ?item wdt:P6257 ?ra . ?item wdt:P6258 ?dec . }
  OPTIONAL { ?item p:P2583/psv:P2583 [ wikibase:quantityAmount ?dist ; wikibase:quantityUnit ?unit ] . }
  OPTIONAL { ?item wdt:P31 ?type . }
  OPTIONAL { ?item wdt:P361 ?part . }
  OPTIONAL { ?item wdt:P1090 ?z . }
  OPTIONAL { ?itwiki schema:about ?item ; schema:isPartOf <https://it.wikipedia.org/> . }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "it,en". }
}'''


def wikidata(codes):
    items = {}
    codes = sorted(codes)
    batch = 250
    for i in range(0, len(codes), batch):
        values = ' '.join(json.dumps(c, ensure_ascii=False) for c in codes[i:i + batch])
        body = urllib.parse.urlencode({'query': QUERY % values, 'format': 'json'}).encode()
        res = get(SPARQL, data=body)
        for b in res['results']['bindings']:
            q = b['item']['value'].rsplit('/', 1)[-1]
            it = items.setdefault(q, {'q': q, 'codes': set(), 'label': None, 'ra': None, 'dec': None,
                                      'dist': set(), 'types': set(), 'parts': set(), 'z': None, 'itwiki': None})
            it['codes'].add(b['code']['value'])
            it['label'] = b.get('itemLabel', {}).get('value')
            if 'ra' in b and 'dec' in b:
                it['ra'], it['dec'] = float(b['ra']['value']), float(b['dec']['value'])
            if 'dist' in b and 'unit' in b:
                u = b['unit']['value'].rsplit('/', 1)[-1]
                if u in LY:
                    it['dist'].add(float(b['dist']['value']) * LY[u])
            for k, key in (('typeLabel', 'types'), ('partLabel', 'parts')):
                v = b.get(k, {}).get('value')
                if v and not re.match(r'^Q\d+$', v):
                    it[key].add(v)
            if 'z' in b:
                try:
                    it['z'] = float(b['z']['value'])
                except ValueError:
                    pass
            if 'itwiki' in b:
                it['itwiki'] = b['itwiki']['value']
        print(f'Wikidata: {min(i + batch, len(codes))}/{len(codes)} sigle, {len(items)} voci', flush=True)
        time.sleep(1.5)
    return items


def summary(url):
    title = urllib.parse.unquote(url.rsplit('/wiki/', 1)[-1])
    api = 'https://it.wikipedia.org/api/rest_v1/page/summary/' + urllib.parse.quote(title, safe='')
    j = get(api, tries=4, timeout=40)
    if not j or j.get('type') == 'disambiguation':
        return None
    text = (j.get('extract') or '').strip()
    if len(text) < 60:
        return None
    return {'t': text, 'title': j.get('title') or title}


def main():
    catalog, out = sys.argv[1], sys.argv[2]
    objs = json.load(open(catalog, encoding='utf-8'))['objs']
    by_code = {}
    for o in objs:
        for rank, code in enumerate([o['i']] + (o.get('a') or [])):
            for v in variants(code):
                by_code.setdefault(v, []).append((o['i'], rank))
    print(f'{len(objs)} oggetti, {len(by_code)} sigle da cercare', flush=True)
    items = wikidata(by_code.keys())

    # Per ogni oggetto la voce migliore: sigla principale prima degli alias,
    # coordinate entro una tolleranza che dipende dalle dimensioni.
    pos = {o['i']: o for o in objs}
    best = {}
    for it in items.values():
        for code in it['codes']:
            for oid, rank in by_code.get(code, []):
                o = pos[oid]
                tol = max(0.25, (o.get('D') or 0) / 60.0)
                if it['ra'] is not None:
                    if sep_deg(o['ra'], o['de'], it['ra'], it['dec']) > tol:
                        continue
                    score = rank
                elif rank == 0 and re.match(r'^(M|NGC|IC) ', oid):
                    score = 0.5  # senza coordinate: si accetta solo la sigla principale
                else:
                    continue
                # A parità, meglio la voce con più informazioni.
                score -= 0.01 * (bool(it['itwiki']) + bool(it['dist']))
                if oid not in best or score < best[oid][0]:
                    best[oid] = (score, it)
    print(f'{len(best)} oggetti trovati su Wikidata', flush=True)

    # Più oggetti possono puntare alla stessa voce (es. nebulosa e ammasso):
    # il riassunto si scarica una volta sola.
    wiki_urls = sorted({it['itwiki'] for _, it in best.values() if it['itwiki']})
    summaries = {}
    with cf.ThreadPoolExecutor(max_workers=4) as ex:
        futs = {ex.submit(summary, u): u for u in wiki_urls}
        for n, f in enumerate(cf.as_completed(futs), 1):
            try:
                summaries[futs[f]] = f.result()
            except Exception as e:  # noqa: BLE001
                print('riassunto non scaricato:', futs[f], e)
            if n % 100 == 0:
                print(f'Wikipedia: {n}/{len(wiki_urls)}', flush=True)

    details = {}
    for oid, (_, it) in sorted(best.items()):
        d = {'wd': it['q']}
        dist = sorted(v for v in it['dist'] if v > 0)
        if dist:
            d['ly'] = round(statistics.median(dist), 3 if dist[0] < 1 else 0)
            if len(dist) > 1 and dist[-1] / dist[0] > 1.5:
                d['lyr'] = [round(dist[0]), round(dist[-1])]  # stime molto diverse tra loro
        types = sorted(t for t in it['types'] if t not in SKIP_TYPES)
        if types:
            d['ty'] = types[:3]
        if it['parts']:
            d['pt'] = sorted(it['parts'])[:4]
        if it['z'] is not None:
            d['z'] = it['z']
        s = summaries.get(it['itwiki']) if it['itwiki'] else None
        if s:
            d['wk'] = s['t']
            d['wt'] = s['title']
        details[oid] = d

    with open(out, 'w', encoding='utf-8') as f:
        json.dump({'created': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                   'source': 'Wikidata (CC0) e Wikipedia in italiano (CC BY-SA 4.0)',
                   'items': details}, f, ensure_ascii=False, separators=(',', ':'))
    n_ly = sum(1 for d in details.values() if 'ly' in d)
    n_wk = sum(1 for d in details.values() if 'wk' in d)
    print(json.dumps({'oggetti': len(details), 'con distanza': n_ly, 'con testo Wikipedia': n_wk}))
    if len(details) < 300:
        sys.exit('Troppi pochi oggetti trovati: qualcosa non va.')


if __name__ == '__main__':
    main()
