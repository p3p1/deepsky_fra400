// Indicatore e comando dell'ora usata nei calcoli: reale o simulata.

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Chiede data e ora e imposta l'orologio simulato.
Future<void> pickSimulatedTime(BuildContext context, AppState state) async {
  final DateTime cur = state.now();
  final DateTime? d = await showDatePicker(
    context: context,
    initialDate: cur,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100, 12, 31),
    helpText: 'Data da simulare',
  );
  if (d == null || !context.mounted) return;
  final TimeOfDay? t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(cur),
    helpText: 'Ora da simulare',
  );
  if (t == null) return;
  state.simulateTime(DateTime(d.year, d.month, d.day, t.hour, t.minute));
}

class ClockChip extends StatelessWidget {
  const ClockChip({super.key, required this.state, this.compact = false});

  final AppState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final bool sim = state.simulatingTime;
        final DateTime t = state.now();
        final String label = sim ? 'Ora simulata: ${fmtTime(t)} · ${t.day} ${kMonthsShort[t.month - 1]} ${t.year}' : 'Ora reale';
        return Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ActionChip(
              avatar: Icon(sim ? Icons.history_toggle_off : Icons.schedule, size: 18, color: sim ? AppColors.amber : AppColors.muted),
              label: Text(compact && !sim ? 'Simula orario' : (sim ? label : 'Ora reale · simula orario'),
                  style: TextStyle(color: sim ? AppColors.amber : AppColors.ink, fontSize: 12.5)),
              tooltip: 'Scegli data e ora da simulare',
              onPressed: () => pickSimulatedTime(context, state),
            ),
            if (sim)
              IconButton(
                tooltip: 'Torna all\'ora reale',
                visualDensity: VisualDensity.compact,
                onPressed: state.useRealTime,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        );
      },
    );
  }
}
