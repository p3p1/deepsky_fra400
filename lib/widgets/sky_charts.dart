// I due grafici della traiettoria: elevazione/direzione e cupola del cielo.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../astro.dart';
import '../theme.dart';

void _label(
  Canvas canvas,
  String text,
  Offset at, {
  Color color = AppColors.muted,
  double size = 10,
  FontWeight weight = FontWeight.w400,
  Alignment anchor = Alignment.center,
}) {
  final TextPainter tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, at - Offset(tp.width * (anchor.x + 1) / 2, tp.height * (anchor.y + 1) / 2));
}

String _two(int v) => v.toString().padLeft(2, '0');

enum _Seg { twilight, night, window }

_Seg _segOf(TrackPoint a, TrackPoint b, SkyWindow w) {
  if (!a.isNight || !b.isNight) return _Seg.twilight;
  if (w.contains(a.alt, a.az) && w.contains(b.alt, b.az)) return _Seg.window;
  return _Seg.night;
}

Paint _segPaint(_Seg s) {
  switch (s) {
    case _Seg.window:
      return Paint()
        ..color = AppColors.accent
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
    case _Seg.night:
      return Paint()
        ..color = AppColors.ink
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
    case _Seg.twilight:
      return Paint()
        ..color = AppColors.muted
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
  }
}

TrackPoint? _nearest(List<TrackPoint> track, DateTime? now) {
  if (now == null || track.isEmpty) return null;
  if (now.isBefore(track.first.time) || now.isAfter(track.last.time)) return null;
  TrackPoint best = track.first;
  int bestMs = now.difference(best.time).inMilliseconds.abs();
  for (final TrackPoint p in track) {
    final int ms = now.difference(p.time).inMilliseconds.abs();
    if (ms < bestMs) {
      best = p;
      bestMs = ms;
    }
  }
  return best;
}

/// Elevazione (verticale) contro direzione (orizzontale, con i punti cardinali).
class TrackChartPainter extends CustomPainter {
  TrackChartPainter({required this.track, required this.window, required this.now});

  final List<TrackPoint> track;
  final SkyWindow window;
  final DateTime? now;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 34, right = 10, top = 10, bottom = 40;
    final Rect plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (plot.width < 40 || plot.height < 40) return;

    final List<TrackPoint> visible = track.where((TrackPoint p) => p.alt > 0).toList();
    final Paint grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    double yOf(double alt) => plot.bottom - alt / 90.0 * plot.height;

    for (int a = 0; a <= 90; a += 15) {
      final double y = yOf(a.toDouble());
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), a == 0 ? (Paint()..color = AppColors.muted) : grid);
      _label(canvas, '$a°', Offset(plot.left - 5, y), anchor: Alignment.centerRight);
    }
    if (visible.isEmpty) {
      _label(canvas, 'In questa notte resta sotto l\'orizzonte', plot.center, color: AppColors.ink, size: 13);
      return;
    }

    // L'asse orizzontale è centrato su nord o su sud, secondo dove culmina.
    TrackPoint highest = visible.first;
    for (final TrackPoint p in visible) {
      if (p.alt > highest.alt) highest = p;
    }
    final double center = angDiff(highest.az, 0).abs() <= 90 ? 0 : 180;
    double lo = 180, hi = -180;
    for (final TrackPoint p in visible) {
      final double r = angDiff(p.az, center);
      lo = math.min(lo, r);
      hi = math.max(hi, r);
    }
    lo = ((lo - 8) / 22.5).floorToDouble() * 22.5;
    hi = ((hi + 8) / 22.5).ceilToDouble() * 22.5;
    while (hi - lo < 90) {
      lo -= 22.5;
      hi += 22.5;
    }
    lo = math.max(lo, -180);
    hi = math.min(hi, 180);
    final double span = hi - lo;
    double xOf(double az) => plot.left + (angDiff(az, center) - lo) / span * plot.width;

    // Fascia utile del sito (altezza e settore di azimut).
    final Paint band = Paint()..color = AppColors.accent.withValues(alpha: 0.13);
    final double bandTop = yOf(math.min(window.altMax, 90));
    final double bandBottom = yOf(math.max(window.altMin, 0));
    for (double x = plot.left; x < plot.right; x += 2) {
      final double az = norm360(center + lo + (x - plot.left) / plot.width * span);
      if (azInSector(az, window.azFrom, window.azTo)) {
        canvas.drawRect(Rect.fromLTRB(x, bandTop, math.min(x + 2, plot.right), bandBottom), band);
      }
    }

    // Etichette dei punti cardinali: tutte e 16 se c'è spazio, altrimenti le 8 principali.
    final double stepDeg = span <= 202.5 && plot.width / (span / 22.5) >= 26 ? 22.5 : 45;
    for (double r = lo; r <= hi + 0.01; r += 22.5) {
      final double az = norm360(center + r);
      final int idx = cardinalIndex(az);
      final bool main = idx % 2 == 0;
      final double x = plot.left + (r - lo) / span * plot.width;
      if (main) {
        canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      }
      if (!main && stepDeg > 22.5) continue;
      _label(canvas, kCardinal16[idx], Offset(x, plot.bottom + 11),
          color: main ? AppColors.ink : AppColors.muted, size: main ? 11 : 9.5, weight: main ? FontWeight.w600 : FontWeight.w400);
      if (main) _label(canvas, '${az.round() % 360}°', Offset(x, plot.bottom + 26), size: 9.5);
    }

    canvas.save();
    canvas.clipRect(plot.inflate(2));
    for (int i = 0; i + 1 < track.length; i++) {
      final TrackPoint a = track[i], b = track[i + 1];
      if (a.alt < -1 || b.alt < -1) continue;
      if (angDiff(a.az, b.az).abs() > 60) continue;
      final _Seg s = _segOf(a, b, window);
      if (s == _Seg.twilight && i.isOdd) continue; // tratteggio
      canvas.drawLine(Offset(xOf(a.az), yOf(a.alt)), Offset(xOf(b.az), yOf(b.alt)), _segPaint(s));
    }
    Offset? lastLabel;
    for (final TrackPoint p in track) {
      if (p.time.minute != 0 || p.alt <= 0 || p.sunAlt > -6) continue;
      final Offset c = Offset(xOf(p.az), yOf(p.alt));
      final bool inWin = p.isNight && window.contains(p.alt, p.az);
      canvas.drawCircle(c, 3, Paint()..color = AppColors.bg);
      canvas.drawCircle(
          c,
          3,
          Paint()
            ..color = inWin ? AppColors.accent : AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      if (lastLabel == null || (c - lastLabel).distance > 17) {
        _label(canvas, _two(p.time.hour), c + const Offset(6, -8),
            color: inWin ? AppColors.accentSoft : AppColors.ink, anchor: Alignment.centerLeft);
        lastLabel = c;
      }
    }
    final TrackPoint? cur = _nearest(track, now);
    if (cur != null && cur.alt > 0) {
      final Offset c = Offset(xOf(cur.az), yOf(cur.alt));
      canvas.drawCircle(c, 7, Paint()..color = AppColors.amber.withValues(alpha: 0.25));
      canvas.drawCircle(c, 3.5, Paint()..color = AppColors.amber);
      _label(canvas, 'Adesso', c + const Offset(0, 14), color: AppColors.amber, size: 10.5, weight: FontWeight.w600);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TrackChartPainter old) => old.track != track || old.window != window || old.now != now;
}

/// Il cielo visto dall'alto: zenit al centro, orizzonte sul bordo, nord in
/// alto ed est a destra come su una bussola.
class DomePainter extends CustomPainter {
  DomePainter({required this.track, required this.window, required this.now});

  final List<TrackPoint> track;
  final SkyWindow window;
  final DateTime? now;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2 - 22;
    if (radius < 40) return;
    Offset at(double alt, double az) {
      final double r = radius * (90 - alt) / 90;
      final double a = az * kDeg;
      return c + Offset(r * math.sin(a), -r * math.cos(a));
    }

    // Settore utile: corona tra altezza minima e massima, sull'arco di azimut.
    final double from = norm360(window.azFrom);
    double sweep = norm360(window.azTo - window.azFrom);
    if (sweep == 0) sweep = 360;
    final Path band = Path();
    const int steps = 90;
    for (int i = 0; i <= steps; i++) {
      final Offset p = at(math.max(window.altMin, 0), from + sweep * i / steps);
      if (i == 0) {
        band.moveTo(p.dx, p.dy);
      } else {
        band.lineTo(p.dx, p.dy);
      }
    }
    for (int i = steps; i >= 0; i--) {
      final Offset p = at(math.min(window.altMax, 90), from + sweep * i / steps);
      band.lineTo(p.dx, p.dy);
    }
    band.close();
    canvas.drawPath(band, Paint()..color = AppColors.accent.withValues(alpha: 0.13));

    final Paint grid = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = AppColors.muted
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    for (int alt = 15; alt < 90; alt += 15) {
      canvas.drawCircle(c, radius * (90 - alt) / 90, grid);
    }
    for (int i = 0; i < 16; i++) {
      final double az = i * 22.5;
      final bool main = i % 2 == 0;
      if (main) canvas.drawLine(c, at(0, az), grid);
      final double a = az * kDeg;
      final Offset p = c + Offset((radius + 12) * math.sin(a), -(radius + 12) * math.cos(a));
      if (main || radius >= 110) {
        _label(canvas, kCardinal16[i], p,
            color: main ? AppColors.ink : AppColors.muted, size: main ? 12 : 9, weight: main ? FontWeight.w600 : FontWeight.w400);
      }
    }
    for (int alt = 0; alt < 75; alt += 15) {
      _label(canvas, '$alt°', at(alt.toDouble(), 180) + const Offset(4, -7), size: 9, anchor: Alignment.centerLeft);
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: radius + 1)));
    for (int i = 0; i + 1 < track.length; i++) {
      final TrackPoint a = track[i], b = track[i + 1];
      if (a.alt < 0 || b.alt < 0) continue;
      final _Seg s = _segOf(a, b, window);
      if (s == _Seg.twilight && i.isOdd) continue;
      canvas.drawLine(at(a.alt, a.az), at(b.alt, b.az), _segPaint(s));
    }
    canvas.restore();
    Offset? lastLabel;
    for (final TrackPoint p in track) {
      if (p.time.minute != 0 || p.alt <= 0 || p.sunAlt > -6) continue;
      final Offset o = at(p.alt, p.az);
      final bool inWin = p.isNight && window.contains(p.alt, p.az);
      canvas.drawCircle(o, 3, Paint()..color = AppColors.bg);
      canvas.drawCircle(
          o,
          3,
          Paint()
            ..color = inWin ? AppColors.accent : AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      if (lastLabel == null || (o - lastLabel).distance > 20) {
        _label(canvas, _two(p.time.hour), o + const Offset(0, 11), color: inWin ? AppColors.accentSoft : AppColors.ink);
        lastLabel = o;
      }
    }
    final TrackPoint? cur = _nearest(track, now);
    if (cur != null && cur.alt > 0) {
      final Offset o = at(cur.alt, cur.az);
      canvas.drawCircle(o, 7, Paint()..color = AppColors.amber.withValues(alpha: 0.25));
      canvas.drawCircle(o, 3.5, Paint()..color = AppColors.amber);
      _label(canvas, 'Adesso', o + const Offset(0, -13), color: AppColors.amber, size: 10.5, weight: FontWeight.w600);
    }
  }

  @override
  bool shouldRepaint(DomePainter old) => old.track != track || old.window != window || old.now != now;
}
