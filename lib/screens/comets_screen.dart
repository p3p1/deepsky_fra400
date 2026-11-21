// Comete: elenco ordinato per luminosità stimata, dagli elementi orbitali
// del Minor Planet Center scaricati quando c'è internet.

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../astro.dart';
import '../comets.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/clock_chip.dart';
import 'trajectory_view.dart';

class _CometNow {
  const _CometNow(this.comet, this.pos);
  final Comet comet;
  final CometPosition pos;
}

class CometsScreen extends StatelessWidget {
  const CometsScreen({super.key, required this.state});

  final AppState state;

  List<_CometNow> _visible() {
    final double jd = julianDate(state.now());
    final List<_CometNow> out = <_CometNow>[];
    for (final Comet c in state.comets) {
      // Solo comete entro circa 4 anni dal perielio: le altre sono lontane e deboli.
      if ((jd - c.elements.perihelionJd).abs() > 1500) continue;
      final CometPosition p = cometPosition(c.elements, jd);
      final double? m = p.magnitude;
      if (m == null || m > 15 || m.isNaN) continue;
      out.add(_CometNow(c, p));
    }
    out.sort((_CometNow a, _CometNow b) => a.pos.magnitude!.compareTo(b.pos.magnitude!));
    return out.length > 80 ? out.sublist(0, 80) : out;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final List<_CometNow> list = _visible();
        final DateTime? upd = state.cometsUpdated;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            const Text('Comete', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              upd == null
                  ? 'Nessun dato sul dispositivo. Serve internet per scaricare gli elementi orbitali la prima volta.'
                  : 'Elementi orbitali del Minor Planet Center, aggiornati il ${fmtDate(upd)}. Funzionano anche senza internet.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: ClockChip(state: state, compact: true)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: state.cometsBusy ? null : () => state.updateComets(),
                icon: const Icon(Icons.download),
                label: Text(state.cometsBusy ? 'Scarico…' : 'Aggiorna adesso'),
              ),
            ),
            if (state.cometsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(state.cometsError!, style: const TextStyle(color: AppColors.q2, fontSize: 13)),
              ),
            const SizedBox(height: 12),
            if (list.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'La magnitudine è una stima dalla formula standard: le comete spesso si discostano anche di alcune magnitudini. '
                  'La posizione trascura le perturbazioni planetarie.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            for (final _CometNow c in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: AppColors.surface,
                  shape: const RoundedRectangleBorder(
                    side: BorderSide(color: AppColors.line),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (BuildContext context) => _CometPage(state: state, comet: c.comet),
                    )),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 62,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(fmt(c.pos.magnitude!), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.amber)),
                                const Text('mag stimata', style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(c.comet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                Text('AR ${fmtRa(c.pos.eq.ra)} · Dec ${fmtDec(c.pos.eq.dec)}', style: kMono.copyWith(fontSize: 12, color: AppColors.muted)),
                                Text('dal Sole ${fmt(c.pos.sunDist, 2)} UA · dalla Terra ${fmt(c.pos.earthDist, 2)} UA',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (list.isEmpty && upd != null)
              const Text('Nessuna cometa con magnitudine stimata fino a 15 in questo momento.', style: TextStyle(color: AppColors.muted)),
          ],
        );
      },
    );
  }
}

class _CometPage extends StatelessWidget {
  const _CometPage({required this.state, required this.comet});

  final AppState state;
  final Comet comet;

  @override
  Widget build(BuildContext context) {
    final SkyTarget target = SkyTarget(
      title: comet.name,
      subtitle: 'Cometa',
      position: (double jd) => cometPosition(comet.elements, jd).eq,
    );
    return Scaffold(
      appBar: AppBar(title: Text(comet.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: TrajectoryView(state: state, target: target),
        ),
      ),
    );
  }
}
