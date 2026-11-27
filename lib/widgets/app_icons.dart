// Icone disegnate per l'app (stesse della tavola «Icone dentro l'app» del
// mockup): tratto 1,8 su griglia 24 × 24, come le icone Material.
//
// Le icone di sezione e dei comandi usano il colore corrente (quello del
// tema o passato a [AppIcon]); quelle dei tipi di oggetto hanno il colore
// del loro tipo.

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

const String _s = 'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"';

String _svg(String body, {String attrs = _s}) => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" $attrs>$body</svg>';

const String _cloud =
    'M6 17.5c-2.2 0-3.5-1.6-3.5-3.3 0-1.8 1.4-3.2 3.2-3.3.4-2.7 2.6-4.6 5.3-4.6 2.5 0 4.6 1.6 5.2 3.9 2.4.1 4.3 1.9 4.3 4 0 2-1.6 3.3-3.7 3.3';
const String _spiral1 = 'M12 12c-.3-1.8 2-2.6 3.2-1.3 1.6 1.7.2 4.6-2.6 4.9-3.3.4-5.6-2.6-4.8-5.6C8.6 6.4 12.6 4.4 16.4 5.7';
const String _spiral2 = 'M12 12c.3 1.8-2 2.6-3.2 1.3-1.6-1.7-.2-4.6 2.6-4.9 3.3-.4 5.6 2.6 4.8 5.6-.8 3.6-4.8 5.6-8.6 4.3';

/// Icone di sezioni e comandi (monocromatiche).
final Map<String, String> kAppIcons = <String, String>{
  'catalog': _svg('<path d="M10 6h10M10 12h10M10 18h10"/>'
      '<path d="M5 4.3l.8 1.7 1.7.4-1.3 1.2.3 1.8L5 8.5l-1.5.9.3-1.8-1.3-1.2 1.7-.4z" fill="currentColor" stroke-width="0.8"/>'
      '<circle cx="5" cy="12" r="1" fill="currentColor"/><circle cx="5" cy="18" r="1" fill="currentColor"/>'),
  'tonight': _svg('<path d="M15.5 13.5A6 6 0 0 1 9.5 4a6.5 6.5 0 1 0 6 9.5z"/><path d="M3 20h18"/><path d="M18 5.5v3M16.5 7h3"/>'),
  'lists': _svg('<path d="M8 3h10a1 1 0 0 1 1 1v16l-6-3.5L7 20V4a1 1 0 0 1 1-1z"/>'
      '<path d="M13 7l.9 1.9 2 .3-1.5 1.4.4 2-1.8-1-1.8 1 .4-2-1.5-1.4 2-.3z"/>'),
  'comets': _svg('<circle cx="17" cy="7" r="3"/><path d="M14.8 9.2L4 20M14.2 6.3L6 12.5M17.7 9.8L12 18"/>'),
  'settings': _svg('<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>'
      '<path d="M4 12h3M11 12h9"/><circle cx="9" cy="12" r="2"/>'),
  'deepsky': _svg('<path d="$_spiral1"/><path d="$_spiral2"/>'),
  'flatpanel': _svg('<circle cx="12" cy="12" r="5.5"/><circle cx="12" cy="12" r="2.5" fill="currentColor" fill-opacity="0.35" stroke="none"/>'
      '<path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>'),
  'ar': _svg('<rect x="6" y="2.5" width="12" height="19" rx="2.5"/><circle cx="12" cy="11" r="3"/><path d="M12 6.5v1.5M12 14v1.5M7.5 11H9M15 11h1.5"/>'),
  'dome': _svg('<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5" stroke-opacity="0.5"/><path d="M7 16c1-4 4-7.5 9-8"/>'
      '<circle cx="10.5" cy="11" r="1.4" fill="#FFB95C" stroke="none"/>'),
  'chart': _svg('<path d="M3 19h18"/><path d="M4 19C6 8 18 8 20 19"/><circle cx="12" cy="10.8" r="1.4" fill="#FFB95C" stroke="none"/>'),
  'framing': _svg('<path d="M4 7V4h3M17 4h3v3M20 17v3h-3M7 20H4v-3"/><ellipse cx="12" cy="12" rx="4.5" ry="3" stroke="#FF8FA3"/>'),
  'filter': _svg('<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4.5" fill="#FF8FA3" fill-opacity="0.35" stroke="#FF8FA3"/>'
      '<path d="M12 4v-1.5M12 21.5V20"/>'),
  'clock': _svg('<circle cx="13" cy="12" r="8"/><path d="M13 7.5V12l3 2"/><path d="M2.5 9.5L5 12l2.5-2.5"/>'),
  'urban': _svg('<path d="M3 21h18"/><path d="M5 21V10h5v11M10 21V5h6v16M16 21v-8h4v8"/><path d="M12.5 8h1M12.5 11h1M12.5 14h1"/>'),
  'rural': _svg('<path d="M2 20l6-9 4 5 3-4 7 8z"/><circle cx="14" cy="4" r="0.8" fill="currentColor" stroke="none"/>'
      '<circle cx="19.5" cy="7" r="0.8" fill="currentColor" stroke="none"/><circle cx="10" cy="7.5" r="0.6" fill="currentColor" stroke="none"/>'
      '<path d="M5 4.5l.5 1.2 1.2.5-1.2.5-.5 1.2-.5-1.2-1.2-.5 1.2-.5z" fill="#FFB95C" stroke="none"/>'),
  'reducer': _svg('<path d="M7 4c-2 2.2-3 5-3 8s1 5.8 3 8M17 4c2 2.2 3 5 3 8s-1 5.8-3 8"/><path d="M7 12h10"/><path d="M14 9l3 3-3 3"/>'),
};

/// Colore di ogni tipo di oggetto.
const Map<String, Color> kTypeColors = <String, Color>{
  'EN': Color(0xFFFF8FA3),
  'PN': Color(0xFF5FE3D3),
  'SNR': Color(0xFFFF9F80),
  'MIX': Color(0xFFC9A0FF),
  'RN': Color(0xFF6FA8FF),
  'DN': Color(0xFFB4B4B4),
  'NEB': Color(0xFFE8B4C0),
  'GAL': Color(0xFFFFE4B5),
  'GC': Color(0xFFFFD48A),
  'OC': Color(0xFFCFE0FF),
  'AST': Color(0xFFB4C8FF),
  'OTH': Color(0xFFB4B4B4),
};

/// Icone dei tipi di oggetto (a colori).
final Map<String, String> kTypeIcons = <String, String>{
  'EN': _svg('<path d="$_cloud"/><path d="M9 20c1-1.2 2.3-1.8 3.8-1.8s2.6.5 3.4 1.3"/><circle cx="11" cy="12.5" r="1" fill="#FF8FA3"/>',
      attrs: _s.replaceAll('currentColor', '#FF8FA3')),
  'PN': _svg('<ellipse cx="12" cy="12" rx="8" ry="6.5"/><ellipse cx="12" cy="12" rx="4.5" ry="3.5" stroke-opacity="0.55"/>'
      '<circle cx="12" cy="12" r="1.2" fill="#5FE3D3"/>', attrs: _s.replaceAll('currentColor', '#5FE3D3')),
  'SNR': _svg('<path d="M4.5 9.5A8 8 0 0 1 10 4.3"/><path d="M14 4.4a8 8 0 0 1 5.3 5"/><path d="M19.6 14a8 8 0 0 1-5 5.6"/>'
      '<path d="M10 19.7a8 8 0 0 1-5.6-5.2"/><path d="M8 8.5l1.5 1.5M16 8l-1.4 1.6M16 16l-1.5-1.4M8 15.6l1.5-1.4"/>',
      attrs: _s.replaceAll('currentColor', '#FF9F80')),
  'MIX': _svg('<path d="M6 17.5c-2.2 0-3.5-1.6-3.5-3.3 0-1.8 1.4-3.2 3.2-3.3.4-2.7 2.6-4.6 5.3-4.6 2.5 0 4.6 1.6 5.2 3.9" stroke="#FF8FA3"/>'
      '<path d="M16 11c2.4.1 4.5 1.8 4.5 3.7 0 2-1.6 2.8-3.7 2.8H11" stroke="#6FA8FF"/><path d="M16.5 3.5v3M15 5h3" stroke="#6FA8FF"/>',
      attrs: 'fill="none" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"'),
  'RN': _svg('<circle cx="12" cy="12" r="7.5" stroke-dasharray="2 3"/>'
      '<path d="M12 8.5l1 2.5 2.5 1-2.5 1-1 2.5-1-2.5-2.5-1 2.5-1z" fill="#6FA8FF"/>', attrs: _s.replaceAll('currentColor', '#6FA8FF')),
  'DN': _svg('<path d="M7 8c2-2.5 6-2.8 8.5-1 2.4 1.7 2.5 5 .8 7.2-1.6 2.1-4.8 3-7.3 1.8C6.3 14.7 5.4 10.2 7 8z" fill="#000000"/>'
      '<circle cx="3.5" cy="5" r="0.9" fill="#B4B4B4"/><circle cx="20" cy="4.5" r="0.9" fill="#B4B4B4"/>'
      '<circle cx="20.5" cy="18" r="0.9" fill="#B4B4B4"/><circle cx="4" cy="19" r="0.9" fill="#B4B4B4"/><circle cx="12" cy="21" r="0.9" fill="#B4B4B4"/>',
      attrs: _s.replaceAll('currentColor', '#B4B4B4')),
  'NEB': _svg('<path d="${_cloud}H6z"/><path d="M10.5 11a1.6 1.6 0 1 1 2.3 1.4c-.5.3-.8.7-.8 1.3"/><circle cx="12" cy="15.6" r="0.6" fill="#E8B4C0"/>',
      attrs: _s.replaceAll('currentColor', '#E8B4C0')),
  'GAL': _svg('<path d="$_spiral1"/><path d="$_spiral2" stroke-opacity="0.6"/>', attrs: _s.replaceAll('currentColor', '#FFE4B5')),
  'GC': _svg('<circle cx="12" cy="12" r="2.2"/><circle cx="12" cy="7.5" r="1.1"/><circle cx="16" cy="9.5" r="1.1"/>'
      '<circle cx="16.3" cy="14" r="1.1"/><circle cx="12" cy="16.5" r="1.1"/><circle cx="7.8" cy="14.3" r="1.1"/><circle cx="7.6" cy="9.6" r="1.1"/>'
      '<circle cx="12" cy="3.5" r="0.8"/><circle cx="19.5" cy="7" r="0.8"/><circle cx="20" cy="15.5" r="0.8"/><circle cx="12.5" cy="20.5" r="0.8"/>'
      '<circle cx="4.3" cy="16.5" r="0.8"/><circle cx="4.2" cy="7.5" r="0.8"/>', attrs: 'fill="#FFD48A"'),
  'OC': _svg('<circle cx="7" cy="7" r="1.8"/><circle cx="15.5" cy="5.5" r="1.1"/><circle cx="18" cy="12" r="1.6"/><circle cx="11" cy="12.5" r="1.1"/>'
      '<circle cx="5.5" cy="15.5" r="1"/><circle cx="13.5" cy="18.5" r="1.9"/><circle cx="19.5" cy="19" r="0.8"/><circle cx="4" cy="10.5" r="0.7"/>',
      attrs: 'fill="#CFE0FF"'),
  'AST': _svg('<path d="M4.5 16.5L9 9.5l6 2 4.5-6M15 11.5l2 7" fill="none" stroke="#B4C8FF" stroke-width="1.2" stroke-linecap="round" stroke-opacity="0.55"/>'
      '<circle cx="4.5" cy="16.5" r="1.5"/><circle cx="9" cy="9.5" r="1.3"/><circle cx="15" cy="11.5" r="1.6"/>'
      '<circle cx="19.5" cy="5.5" r="1.2"/><circle cx="17" cy="18.5" r="1.2"/>', attrs: 'fill="#B4C8FF"'),
  'OTH': _svg('<path d="M12 4l2 6 6 2-6 2-2 6-2-6-6-2 6-2z"/>', attrs: 'fill="#B4B4B4"'),
};

/// Icona di sezione o comando. Senza [color] prende quello del tema
/// (per esempio il colore selezionato/non selezionato della barra in basso).
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size, this.color});

  final String name;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final IconThemeData theme = IconTheme.of(context);
    final double s = size ?? theme.size ?? 24;
    final Color c = color ?? theme.color ?? Colors.white;
    return SizedBox(
      width: s,
      height: s,
      child: SvgPicture.string(kAppIcons[name] ?? kAppIcons['catalog']!, width: s, height: s, theme: SvgTheme(currentColor: c)),
    );
  }
}

/// Icona del tipo di oggetto; con [tonal] dentro un cerchio del suo colore.
class TypeIcon extends StatelessWidget {
  const TypeIcon(this.code, {super.key, this.size = 20, this.tonal = false});

  final String code;
  final double size;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final String svg = kTypeIcons[code] ?? kTypeIcons['OTH']!;
    final Widget icon = SvgPicture.string(svg, width: size, height: size);
    if (!tonal) return SizedBox(width: size, height: size, child: icon);
    final Color c = kTypeColors[code] ?? const Color(0xFFB4B4B4);
    return Container(
      width: size * 1.75,
      height: size * 1.75,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), shape: BoxShape.circle),
      child: icon,
    );
  }
}
