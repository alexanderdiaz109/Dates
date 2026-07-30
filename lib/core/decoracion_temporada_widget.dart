import 'dart:math';
import 'package:flutter/material.dart';
import 'temporada_service.dart';
import 'temporada_theme.dart';

class DecoracionTemporadaWidget extends StatefulWidget {
  final Widget child;
  final bool activa;

  const DecoracionTemporadaWidget({
    super.key,
    required this.child,
    required this.activa,
  });

  @override
  State<DecoracionTemporadaWidget> createState() =>
      _DecoracionTemporadaWidgetState();
}

class _DecoracionTemporadaWidgetState
    extends State<DecoracionTemporadaWidget> with TickerProviderStateMixin {
  final Temporada _temporada = TemporadaService.detectar();
  late final List<_Copo> _copos;
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    if (_temporada == Temporada.navidad) {
      _inicializarNieve();
    } else {
      _copos = [];
      _controllers = [];
    }
  }

  void _inicializarNieve() {
    final rand = Random();
    _copos = List.generate(18, (i) => _Copo(
      left: rand.nextDouble(),
      size: 8.0 + rand.nextDouble() * 10.0,
      velocidad: (4 + rand.nextDouble() * 4).round(),
      opacidad: 0.3 + rand.nextDouble() * 0.5,
      delay: rand.nextDouble() * 3,
    ));

    _controllers = _copos.map((c) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(seconds: c.velocidad.round()),
      );
      Future.delayed(Duration(milliseconds: (c.delay * 1000).round()), () {
        if (mounted) ctrl.repeat();
      });
      return ctrl;
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.activa || _temporada == Temporada.ninguna) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            widget.child,

            // ── ELEMENTOS ESTÁTICOS ──────────────────
            if (_temporada != Temporada.navidad && TemporadaTheme(_temporada).backgroundElementPainter() != null)
              ...TemporadaService.elementos(_temporada).map((e) {
                return Positioned(
                  left: e.left * w,
                  top: e.top * h,
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: e.size * 0.2,
                      child: SizedBox(
                        width: e.size * 1.5,
                        height: e.size * 1.5,
                        child: CustomPaint(
                          painter: TemporadaTheme(_temporada).backgroundElementPainter(),
                        ),
                      ),
                    ),
                  ),
                );
              }),

            // ── NIEVE ANIMADA (solo Navidad) ──────────
            if (_temporada == Temporada.navidad)
              ..._copos.asMap().entries.map((entry) {
                final i = entry.key;
                final copo = entry.value;
                return AnimatedBuilder(
                  animation: _controllers[i],
                  builder: (context, child) {
                    final progreso = _controllers[i].value;
                    return Positioned(
                      left: copo.left * w +
                          sin(progreso * 2 * pi) * 12,
                      top: progreso * (h + 20) - 20,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: copo.opacidad *
                              (1 - (progreso > 0.85
                                  ? (progreso - 0.85) / 0.15
                                  : 0)),
                          child: Text(
                            '❄️',
                            style: TextStyle(fontSize: copo.size),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
          ],
        );
      },
    );
  }
}

class _Copo {
  final double left;
  final double size;
  final int velocidad;
  final double opacidad;
  final double delay;

  _Copo({
    required this.left,
    required this.size,
    required this.velocidad,
    required this.opacidad,
    required this.delay,
  });
}
