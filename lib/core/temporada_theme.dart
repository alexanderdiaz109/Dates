import 'package:flutter/material.dart';
import 'temporada_service.dart';

class TemporadaTheme {
  final Temporada temporada;
  const TemporadaTheme(this.temporada);

  // ── Color del washi tape ──────────────────────────────
  Color get washiTapeColor {
    switch (temporada) {
      case Temporada.sanValentin: return const Color(0xFFFF6B9D).withAlpha(180);
      case Temporada.primavera: return const Color(0xFF7BC67E).withAlpha(180);
      case Temporada.verano: return const Color(0xFFFFD166).withAlpha(180);
      case Temporada.otono: return const Color(0xFFE07A5F).withAlpha(180);
      case Temporada.halloween: return const Color(0xFF8B1A1A).withAlpha(200);
      case Temporada.navidad: return const Color(0xFF2D6A4F).withAlpha(180);
      case Temporada.ninguna: return Colors.white.withAlpha(140);
    }
  }

  // ── Color accent de la temporada ─────────────────────
  Color get accentColor {
    switch (temporada) {
      case Temporada.sanValentin: return const Color(0xFFFF6B9D);
      case Temporada.primavera: return const Color(0xFF7BC67E);
      case Temporada.verano: return const Color(0xFFFFD166);
      case Temporada.otono: return const Color(0xFFE07A5F);
      case Temporada.halloween: return const Color(0xFFBE3144);
      case Temporada.navidad: return const Color(0xFF2D6A4F);
      case Temporada.ninguna: return const Color(0xFFFF6A88);
    }
  }

  // ── Gradiente del card principal del dashboard ───────
  List<Color> get gradienteDashboard {
    switch (temporada) {
      case Temporada.sanValentin: return [const Color(0xFFFF6B9D), const Color(0xFFFF8E9E)];
      case Temporada.primavera: return [const Color(0xFF56AB2F), const Color(0xFFA8E063)];
      case Temporada.verano: return [const Color(0xFFFF8C00), const Color(0xFFFFD700)];
      case Temporada.otono: return [const Color(0xFFE07A5F), const Color(0xFFF4A261)];
      case Temporada.halloween: return [const Color(0xFF1A0A0A), const Color(0xFF6B0F0F)];
      case Temporada.navidad: return [const Color(0xFF1B4332), const Color(0xFF2D6A4F)];
      case Temporada.ninguna: return [const Color(0xFFFF6A88), const Color(0xFFFF8C69)];
    }
  }

  // ── Painter responsivo para el detalle decorativo (ej: Post-it, vista previa)
  CustomPainter? postItPainter(Color color) {
    switch (temporada) {
      case Temporada.sanValentin: return _CorazonPainter(color: color);
      case Temporada.primavera: return _FlorPainter(color: color);
      case Temporada.verano: return _SolPainter(color: color);
      case Temporada.otono: return _HojaPainter(color: color);
      case Temporada.halloween: return _MurcielagoPainter(color: color);
      case Temporada.navidad: return _CopoPainter(color: color);
      case Temporada.ninguna: return null;
    }
  }

  // ── Painter responsivo para los elementos de fondo dispersos
  CustomPainter? backgroundElementPainter() {
    final c = accentColor.withAlpha(40);
    switch (temporada) {
      case Temporada.sanValentin: return _CorazonPainter(color: c, fill: true);
      case Temporada.primavera: return _FlorPainter(color: c, fill: true);
      case Temporada.verano: return _SolPainter(color: c, fill: true);
      case Temporada.otono: return _HojaPainter(color: c, fill: true);
      case Temporada.halloween: return _MurcielagoPainter(color: c, fill: true);
      case Temporada.navidad: return null; // La navidad usa animación
      case Temporada.ninguna: return null;
    }
  }
}

// ── PAINTERS RESPONSIVOS Y CENTRADOS ──────────────────────────────────────────

double _cos(double a) {
  final x = a % (2 * 3.14159265);
  return 1 - x * x / 2 + x * x * x * x / 24 - x * x * x * x * x * x / 720;
}
double _sin(double a) {
  final x = a % (2 * 3.14159265);
  return x - x * x * x / 6 + x * x * x * x * x / 120;
}

class _CorazonPainter extends CustomPainter {
  final Color color;
  final bool fill;
  _CorazonPainter({required this.color, this.fill = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = fill ? 0.0 : size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.8;
    final h = size.height * 0.8;

    final path = Path();
    path.moveTo(cx, cy - h * 0.15);
    path.cubicTo(cx - w * 0.5, cy - h * 0.5, cx - w * 0.6, cy + h * 0.1, cx, cy + h * 0.5);
    path.cubicTo(cx + w * 0.6, cy + h * 0.1, cx + w * 0.5, cy - h * 0.5, cx, cy - h * 0.15);

    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(_) => false;
}

class _FlorPainter extends CustomPainter {
  final Color color;
  final bool fill;
  _FlorPainter({required this.color, this.fill = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = fill ? 0.0 : size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.18;

    for (int i = 0; i < 5; i++) {
      final angulo = (i * 72) * (3.14159265 / 180);
      final px = cx + (r * 1.5) * _cos(angulo);
      final py = cy + (r * 1.5) * _sin(angulo);
      canvas.drawCircle(Offset(px, py), r, paint);
    }
    canvas.drawCircle(Offset(cx, cy), r * 0.8, paint..style = PaintingStyle.fill);
  }
  @override bool shouldRepaint(_) => false;
}

class _SolPainter extends CustomPainter {
  final Color color;
  final bool fill;
  _SolPainter({required this.color, this.fill = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = fill ? 0.0 : size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.22;

    canvas.drawCircle(Offset(cx, cy), r, paint);

    final paintRayos = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      final angulo = i * 45 * (3.14159265 / 180);
      final x1 = cx + (r * 1.4) * _cos(angulo);
      final y1 = cy + (r * 1.4) * _sin(angulo);
      final x2 = cx + (r * 2.2) * _cos(angulo);
      final y2 = cy + (r * 2.2) * _sin(angulo);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paintRayos);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _HojaPainter extends CustomPainter {
  final Color color;
  final bool fill;
  _HojaPainter({required this.color, this.fill = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = fill ? 0.0 : size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.4;
    final h = size.height * 0.4;

    final path = Path();
    path.moveTo(cx, cy + h);
    path.quadraticBezierTo(cx - w, cy, cx, cy - h);
    path.quadraticBezierTo(cx + w, cy, cx, cy + h);

    canvas.drawPath(path, paint);

    if (!fill) {
      canvas.drawLine(Offset(cx, cy + h), Offset(cx, cy - h), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _MurcielagoPainter extends CustomPainter {
  final Color color;
  final bool fill;
  _MurcielagoPainter({required this.color, this.fill = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = fill ? 0.0 : size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.45;
    final h = size.height * 0.25;

    final path = Path();
    path.moveTo(cx, cy);
    path.quadraticBezierTo(cx - w * 0.5, cy - h * 1.5, cx - w, cy - h * 0.5);
    path.quadraticBezierTo(cx - w * 0.7, cy + h, cx, cy + h * 1.2);

    path.moveTo(cx, cy);
    path.quadraticBezierTo(cx + w * 0.5, cy - h * 1.5, cx + w, cy - h * 0.5);
    path.quadraticBezierTo(cx + w * 0.7, cy + h, cx, cy + h * 1.2);

    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(cx, cy - h * 0.5), size.width * 0.1, paint..style = PaintingStyle.fill);
  }
  @override bool shouldRepaint(_) => false;
}

class _CopoPainter extends CustomPainter {
  final Color color;
  final bool fill;
  _CopoPainter({required this.color, this.fill = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.4;
    const pi = 3.14159265;

    for (int i = 0; i < 6; i++) {
      final angulo = i * 60 * (pi / 180);
      final x2 = cx + r * _cos(angulo);
      final y2 = cy + r * _sin(angulo);
      canvas.drawLine(Offset(cx, cy), Offset(x2, y2), paint);

      final mx = cx + (r * 0.5) * _cos(angulo);
      final my = cy + (r * 0.5) * _sin(angulo);
      final perp = angulo + pi / 2;
      final rama = r * 0.3;
      canvas.drawLine(Offset(mx, my), Offset(mx + rama * _cos(perp), my + rama * _sin(perp)), paint);
      canvas.drawLine(Offset(mx, my), Offset(mx - rama * _cos(perp), my - rama * _sin(perp)), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}
