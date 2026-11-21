// Impostazioni: le due posizioni, i limiti del cielo visibile, la taratura
// della vista AR e le fonti dei dati.

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../astro.dart';
import '../models.dart';
import '../settings.dart';
import '../theme.dart';
import '../updater.dart';
import 'catalog_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.state.settings.homeName);
  late final TextEditingController _lat = TextEditingController(text: fmt(widget.state.settings.homeLat, 4));
  late final TextEditingController _lon = TextEditingController(text: fmt(widget.state.settings.homeLon, 4));
  String? _homeError;
  String? _gpsMessage;
  bool _gpsBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _saveHome() async {
    final double? lat = _parse(_lat.text), lon = _parse(_lon.text);
    if (lat == null || lon == null || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      setState(() => _homeError = 'Scrivi latitudine tra −90 e 90 e longitudine tra −180 e 180, in gradi decimali.');
      return;
    }
    setState(() => _homeError = null);
    await widget.state.changeSettings((AppSettings s) {
      s.homeName = _name.text.trim().isEmpty ? 'Casa' : _name.text.trim();
      s.homeLat = lat;
      s.homeLon = lon;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posizione di casa salvata')));
    }
  }

  Future<void> _resetHome() async {
    _name.text = kDefaultHomeName;
    _lat.text = fmt(kDefaultHomeLat, 4);
    _lon.text = fmt(kDefaultHomeLon, 4);
    await _saveHome();
  }

  Future<void> _gps() async {
    setState(() {
      _gpsBusy = true;
      _gpsMessage = null;
    });
    final String? err = await widget.state.refreshGps();
    if (!mounted) return;
    setState(() {
      _gpsBusy = false;
      _gpsMessage = err ?? 'Posizione aggiornata.';
    });
  }

  Widget _title(String s) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(s, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      );

  Widget _direction(String label, double value, void Function(double v) onChanged) {
    return DropdownButtonFormField<int>(
      key: ValueKey<String>('$label-${cardinalIndex(value)}'),
      initialValue: cardinalIndex(value),
      decoration: InputDecoration(labelText: label, isDense: true),
      items: <DropdownMenuItem<int>>[
        for (int i = 0; i < 16; i++) DropdownMenuItem<int>(value: i, child: Text('${kCardinal16[i]} · ${(i * 22.5).round()}°')),
      ],
      onChanged: (int? i) {
        if (i != null) onChanged(i * 22.5);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (BuildContext context, Widget? _) {
        final AppState st = widget.state;
        final AppSettings s = st.settings;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            const Text('Impostazioni', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            _title('Sito attivo'),
            Align(alignment: Alignment.centerLeft, child: SiteSwitch(state: st)),
            const SizedBox(height: 6),
            Text(
              'Punteggi, mesi utili e traiettorie sono calcolati per ${s.siteName} '
              '(${fmt(s.lat, 4)}° N, ${fmt(s.lon, 4)}° E).',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),

            _title('Casa'),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome', isDense: true)),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _lat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Latitudine (° N)', isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lon,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Longitudine (° E)', isDense: true),
                  ),
                ),
              ],
            ),
            if (_homeError != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(_homeError!, style: const TextStyle(color: AppColors.q2, fontSize: 13))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                FilledButton(onPressed: _saveHome, child: const Text('Salva posizione')),
                OutlinedButton(onPressed: _resetHome, child: const Text('Ripristina $kDefaultHomeName')),
              ],
            ),
            const SizedBox(height: 14),
            Text('Altezza utile: da ${s.homeAltMin.round()}° a ${s.homeAltMax.round()}°', style: const TextStyle(fontSize: 13.5)),
            RangeSlider(
              values: RangeValues(s.homeAltMin, s.homeAltMax),
              min: 0,
              max: 90,
              divisions: 18,
              labels: RangeLabels('${s.homeAltMin.round()}°', '${s.homeAltMax.round()}°'),
              onChanged: (RangeValues v) => setState(() {
                s.homeAltMin = v.start;
                s.homeAltMax = v.end;
              }),
              onChangeEnd: (_) => st.changeSettings((AppSettings a) {}),
            ),
            const Text('Settore di cielo visibile, girando in senso orario sulla bussola:', style: TextStyle(fontSize: 13.5)),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(child: _direction('Da', s.homeAzFrom, (double v) => st.changeSettings((AppSettings a) => a.homeAzFrom = v))),
                const SizedBox(width: 10),
                Expanded(child: _direction('A', s.homeAzTo, (double v) => st.changeSettings((AppSettings a) => a.homeAzTo = v == 0 ? 360 : v))),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Se "Da" e "A" coincidono vale tutto l\'orizzonte.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cielo urbano'),
              subtitle: const Text('Penalizza galassie, nebulose a riflessione e oscure'),
              value: s.homeUrban,
              onChanged: (bool v) => st.changeSettings((AppSettings a) => a.homeUrban = v),
            ),

            _title('Trasferta'),
            Text(
              s.hasTravelFix
                  ? 'Ultima posizione GPS: ${fmt(s.travelLat!, 4)}° N, ${fmt(s.travelLon!, 4)}° E'
                      '${s.travelFix == null ? '' : ', letta il ${fmtDate(s.travelFix!)} alle ${fmtTime(s.travelFix!)}'}.'
                  : 'Nessuna posizione GPS ancora letta: finché manca, la trasferta usa le coordinate di casa.',
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _gpsBusy ? null : _gps,
                icon: const Icon(Icons.my_location),
                label: Text(_gpsBusy ? 'Leggo il GPS…' : 'Leggi la posizione dal GPS'),
              ),
            ),
            if (_gpsMessage != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(_gpsMessage!, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
            const SizedBox(height: 10),
            Text('Altezza minima: ${s.travelAltMin.round()}°', style: const TextStyle(fontSize: 13.5)),
            Slider(
              value: s.travelAltMin,
              min: 0,
              max: 45,
              divisions: 9,
              label: '${s.travelAltMin.round()}°',
              onChanged: (double v) => setState(() => s.travelAltMin = v),
              onChangeEnd: (_) => st.changeSettings((AppSettings a) {}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cielo urbano'),
              subtitle: const Text('Lascialo spento per un sito buio'),
              value: s.travelUrban,
              onChanged: (bool v) => st.changeSettings((AppSettings a) => a.travelUrban = v),
            ),

            _title('Vista AR'),
            for (final bool open in <bool>[false, true]) ...<Widget>[
              Text(
                'Correzione bussola, telefono ${open ? 'aperto' : 'chiuso'}: ${fmt(s.compassOffsetFor(open: open))}°',
                style: const TextStyle(fontSize: 13.5),
              ),
              Slider(
                value: s.compassOffsetFor(open: open).clamp(-30.0, 30.0),
                min: -30,
                max: 30,
                divisions: 120,
                label: '${fmt(s.compassOffsetFor(open: open))}°',
                onChanged: (double v) => setState(() => s.setCompassOffset(v, open: open)),
                onChangeEnd: (_) => st.changeSettings((AppSettings a) {}, rescore: false),
              ),
            ],
            const Text(
              'Si somma alla lettura della bussola del telefono. Comprende la declinazione magnetica '
              '(a Roma circa 4° verso est, valore indicativo) e l\'errore del sensore. Sui pieghevoli i magneti della cerniera '
              'cambiano la lettura tra telefono chiuso e aperto, per questo le correzioni sono due. Tarale dalla vista AR puntando un astro che riconosci.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text('Campo della fotocamera (lato lungo): ${s.cameraFov.round()}°', style: const TextStyle(fontSize: 13.5)),
            Slider(
              value: s.cameraFov.clamp(35.0, 100.0),
              min: 35,
              max: 100,
              divisions: 65,
              label: '${s.cameraFov.round()}°',
              onChanged: (double v) => setState(() => s.cameraFov = v),
              onChangeEnd: (_) => st.changeSettings((AppSettings a) {}, rescore: false),
            ),

            _title('Aggiornamenti'),
            UpdatePanel(updater: st.updater),

            _title('Dati e fonti'),
            Text(
              '${fmtThousands(st.objects.length)} oggetti dal catalogo DSO di Stellarium 3.23 e da OpenNGC (licenza CC BY-SA 4.0). '
              'Sole, Luna e traiettorie sono calcolati sul telefono, senza internet. '
              'Gli elementi orbitali delle comete vengono dal Minor Planet Center e si aggiornano da soli quando c\'è rete.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              'Strumento: Askar FRA400 con ASI2600MC Pro. Campo 3,36° × 2,25° a 400 mm; 4,80° × 3,21° con il riduttore 0,7×.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        );
      },
    );
  }
}

/// Versione installata, controllo e installazione degli aggiornamenti.
class UpdatePanel extends StatelessWidget {
  const UpdatePanel({super.key, required this.updater});

  final UpdateService updater;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updater,
      builder: (BuildContext context, Widget? _) {
        final UpdateService u = updater;
        final Release? rel = u.latest;
        final String installed = u.installedBuild > 0 ? 'Versione installata: ${u.installedVersion} (build ${u.installedBuild})' : 'Versione installata: non ancora letta';
        String state;
        switch (u.status) {
          case UpdateStatus.checking:
            state = 'Controllo in corso…';
          case UpdateStatus.downloading:
            state = 'Scarico l\'aggiornamento… ${(u.progress * 100).round()}%';
          case UpdateStatus.installing:
            state = 'Apro l\'installazione di Android…';
          case UpdateStatus.available:
            state = 'Disponibile: ${rel?.name ?? ''} (build ${rel?.build ?? ''})';
          case UpdateStatus.upToDate:
            state = rel == null ? 'Nessuna versione pubblicata.' : 'L\'app è aggiornata.';
          case UpdateStatus.error:
          case UpdateStatus.idle:
            state = '';
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(installed, style: const TextStyle(fontSize: 13.5)),
            if (state.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(state, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
            if (u.status == UpdateStatus.downloading)
              Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: u.progress > 0 ? u.progress : null)),
            if (u.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(u.message!, style: TextStyle(color: u.status == UpdateStatus.error ? AppColors.q2 : AppColors.muted, fontSize: 13)),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: u.busy ? null : () => u.check(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Controlla aggiornamenti'),
                ),
                if (u.updateAvailable)
                  FilledButton.icon(
                    onPressed: u.busy ? null : u.downloadAndInstall,
                    icon: const Icon(Icons.system_update),
                    label: const Text('Scarica e installa'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Le versioni nuove vengono pubblicate sul repository GitHub a ogni modifica e si installano sopra quella '
              'presente, senza perdere impostazioni e collegamenti. L\'app controlla da sola all\'avvio quando c\'è internet.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}
