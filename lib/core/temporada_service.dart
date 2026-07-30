enum Temporada {
  sanValentin,
  primavera,
  verano,
  otono,
  halloween,
  navidad,
  ninguna,
}

class TemporadaService {
  TemporadaService._();

  static Temporada detectar() {
    final ahora = DateTime.now();
    final mes = ahora.month;

    // San Valentín — todo febrero
    if (mes == 2) return Temporada.sanValentin;

    // Halloween — todo octubre
    if (mes == 10) return Temporada.halloween;

    // Navidad/Invierno — diciembre y enero
    if (mes == 12 || mes == 1) return Temporada.navidad;

    // Primavera — marzo, abril, mayo
    if (mes >= 3 && mes <= 5) return Temporada.primavera;

    // Verano — junio, julio, agosto
    if (mes >= 6 && mes <= 8) return Temporada.verano;

    // Otoño — septiembre, noviembre
    if (mes == 9 || mes == 11) return Temporada.otono;

    return Temporada.ninguna;
  }

  static String nombre(Temporada t) {
    switch (t) {
      case Temporada.sanValentin: return 'San Valentín 💝';
      case Temporada.primavera: return 'Primavera 🌸';
      case Temporada.verano: return 'Verano ☀️';
      case Temporada.otono: return 'Otoño 🍂';
      case Temporada.halloween: return 'Halloween 🎃';
      case Temporada.navidad: return 'Navidad ❄️';
      case Temporada.ninguna: return 'Sin temporada';
    }
  }

  /// Elementos estáticos de cada temporada (emojis y posiciones)
  static List<_ElementoDecorativo> elementos(Temporada t) {
    switch (t) {
      case Temporada.sanValentin:
        return [
          _ElementoDecorativo('💝', 0.05, 0.08, 18),
          _ElementoDecorativo('💕', 0.88, 0.05, 14),
          _ElementoDecorativo('🌹', 0.92, 0.88, 16),
          _ElementoDecorativo('💌', 0.03, 0.85, 15),
          _ElementoDecorativo('💗', 0.45, 0.03, 12),
          _ElementoDecorativo('✨', 0.75, 0.15, 11),
          _ElementoDecorativo('💖', 0.15, 0.45, 13),
        ];
      case Temporada.primavera:
        return [
          _ElementoDecorativo('🌸', 0.04, 0.06, 18),
          _ElementoDecorativo('🌺', 0.90, 0.04, 16),
          _ElementoDecorativo('🦋', 0.88, 0.90, 17),
          _ElementoDecorativo('🌿', 0.03, 0.88, 15),
          _ElementoDecorativo('🌼', 0.50, 0.02, 13),
          _ElementoDecorativo('✿', 0.70, 0.20, 12),
          _ElementoDecorativo('🍃', 0.20, 0.50, 11),
        ];
      case Temporada.verano:
        return [
          _ElementoDecorativo('☀️', 0.04, 0.05, 20),
          _ElementoDecorativo('🌊', 0.88, 0.05, 16),
          _ElementoDecorativo('🐚', 0.90, 0.88, 15),
          _ElementoDecorativo('🌴', 0.03, 0.88, 17),
          _ElementoDecorativo('⭐', 0.50, 0.03, 12),
          _ElementoDecorativo('🌻', 0.75, 0.20, 14),
          _ElementoDecorativo('🍦', 0.18, 0.48, 13),
        ];
      case Temporada.otono:
        return [
          _ElementoDecorativo('🍂', 0.04, 0.06, 18),
          _ElementoDecorativo('🍁', 0.90, 0.04, 16),
          _ElementoDecorativo('🌰', 0.88, 0.90, 15),
          _ElementoDecorativo('🍄', 0.03, 0.88, 14),
          _ElementoDecorativo('🦔', 0.50, 0.02, 13),
          _ElementoDecorativo('🌾', 0.72, 0.18, 12),
          _ElementoDecorativo('🍎', 0.18, 0.50, 14),
        ];
      case Temporada.halloween:
        return [
          _ElementoDecorativo('🦇', 0.04, 0.05, 18),
          _ElementoDecorativo('🕷️', 0.90, 0.04, 16),
          _ElementoDecorativo('🌙', 0.88, 0.88, 18),
          _ElementoDecorativo('💀', 0.03, 0.88, 15),
          _ElementoDecorativo('🕸️', 0.50, 0.02, 14),
          _ElementoDecorativo('🔮', 0.72, 0.18, 13),
          _ElementoDecorativo('👁️', 0.18, 0.50, 14),
        ];
      case Temporada.navidad:
      case Temporada.ninguna:
        return [];
    }
  }
}

class _ElementoDecorativo {
  final String emoji;
  final double left; // fracción del ancho (0.0 - 1.0)
  final double top;  // fracción del alto (0.0 - 1.0)
  final double size;

  const _ElementoDecorativo(this.emoji, this.left, this.top, this.size);
}
