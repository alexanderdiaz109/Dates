import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../core/supabase_config.dart';
import '../core/temporada_service.dart';
import '../core/temporada_theme.dart';

class VistaCompartirScreen extends StatefulWidget {
  final String nombrePareja;
  final int diasJuntos;
  final int totalPlanes;
  final String? fotoUrl;

  const VistaCompartirScreen({
    super.key,
    required this.nombrePareja,
    required this.diasJuntos,
    required this.totalPlanes,
    this.fotoUrl,
  });

  @override
  State<VistaCompartirScreen> createState() => _VistaCompartirScreenState();
}

class _VistaCompartirScreenState extends State<VistaCompartirScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _compartiendo = false;
  bool _temporadaActiva = true;

  late final Temporada _temporada;
  late final TemporadaTheme _tema;

  // ── Paleta editorial ────────────────────────────────
  static const _crema = Color(0xFFFDFAF6);
  static const _negro = Color(0xFF1C1917);
  static const _caramelo = Color(0xFF8B7355);
  static const _beige = Color(0xFFB5A898);
  static const _beigeSuave = Color(0xFFC9B89E);
  static const _linea = Color(0xFFE8DDD3);

  @override
  void initState() {
    super.initState();
    _temporada = TemporadaService.detectar();
    _tema = TemporadaTheme(_temporada);
    _cargarTemporada();
  }

  Future<void> _cargarTemporada() async {
    if (SupabaseConfig.parejaId == null) return;
    final data = await SupabaseConfig.client
        .from('parejas')
        .select('temporada_activa')
        .eq('id', SupabaseConfig.parejaId!)
        .maybeSingle();
    if (mounted) {
      setState(() =>
          _temporadaActiva = data?['temporada_activa'] as bool? ?? true);
    }
  }

  Future<void> _compartir() async {
    setState(() => _compartiendo = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nuestra_historia.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.diasJuntos} días juntos 💕',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _temporadaActiva
        ? _tema.accentColor
        : const Color(0xFFFF6A88);

    return Scaffold(
      backgroundColor: _negro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFFB5A898)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Compartir historia',
          style: GoogleFonts.inter(
            color: const Color(0xFFB5A898),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _CardLujo(
                    nombrePareja: widget.nombrePareja,
                    diasJuntos: widget.diasJuntos,
                    totalPlanes: widget.totalPlanes,
                    fotoUrl: widget.fotoUrl,
                    temporada: _temporadaActiva
                        ? _temporada
                        : Temporada.ninguna,
                    tema: _tema,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _caramelo,
                  foregroundColor: _crema,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _compartiendo ? null : _compartir,
                child: _compartiendo
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Color(0xFFFDFAF6), strokeWidth: 1.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.ios_share_rounded, size: 16),
                          const SizedBox(width: 10),
                          Text(
                            'Compartir',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CARD DE LUJO ──────────────────────────────────────────────────
class _CardLujo extends StatelessWidget {
  final String nombrePareja;
  final int diasJuntos;
  final int totalPlanes;
  final String? fotoUrl;
  final Temporada temporada;
  final TemporadaTheme tema;

  static const _crema = Color(0xFFFDFAF6);
  static const _negro = Color(0xFF1C1917);
  static const _caramelo = Color(0xFF8B7355);
  static const _beige = Color(0xFFB5A898);
  static const _beigeSuave = Color(0xFFC9B89E);
  static const _linea = Color(0xFFE8DDD3);

  const _CardLujo({
    required this.nombrePareja,
    required this.diasJuntos,
    required this.totalPlanes,
    required this.fotoUrl,
    required this.temporada,
    required this.tema,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _crema,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SeccionFoto(
              fotoUrl: fotoUrl,
              temporada: temporada,
              tema: tema,
            ),
            _SeccionCuerpo(
              nombrePareja: nombrePareja,
              diasJuntos: diasJuntos,
              totalPlanes: totalPlanes,
            ),
            _SeccionFooter(),
          ],
        ),
      ),
    );
  }
}

// ── SECCIÓN FOTO ──────────────────────────────────────────────────
class _SeccionFoto extends StatelessWidget {
  final String? fotoUrl;
  final Temporada temporada;
  final TemporadaTheme tema;

  static const _crema = Color(0xFFFDFAF6);

  const _SeccionFoto({
    required this.fotoUrl,
    required this.temporada,
    required this.tema,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo con gradiente cálido
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFC9A882),
                  Color(0xFFA0785A),
                  Color(0xFF7A5540),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Foto real si existe
          if (fotoUrl != null)
            Image.network(
              SupabaseConfig.imagenOptimizada(fotoUrl!, width: 800, quality: 85),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),

          // Overlay con degradado hacia crema
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    _crema,
                    _crema.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),

          // Label superior izquierda
          Positioned(
            top: 18, left: 20,
            child: Row(
              children: [
                Container(
                  width: 4, height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x80FFFFFF),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'NUESTRO ESPACIO',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    letterSpacing: 3,
                    color: Colors.white.withAlpha(180),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Año superior derecha
          Positioned(
            top: 18, right: 20,
            child: Text(
              '2026',
              style: GoogleFonts.inter(
                fontSize: 9,
                letterSpacing: 2,
                color: Colors.white.withAlpha(120),
                fontWeight: FontWeight.w300,
              ),
            ),
          ),

          // Corazón inferior derecha
          Positioned(
            bottom: 28, right: 22,
            child: CustomPaint(
              size: const Size(18, 16),
              painter: _CorazonPainter(
                color: Colors.white.withAlpha(150),
                strokeColor: Colors.white.withAlpha(100),
              ),
            ),
          ),

          // Elemento de temporada si aplica
          if (temporada != Temporada.ninguna)
            Positioned(
              bottom: 26, left: 20,
              child: SizedBox(
                width: 32, height: 32,
                child: CustomPaint(
                  painter: _MiniPainterTemporada(
                    color: Colors.white.withAlpha(140),
                    temporada: temporada,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── SECCIÓN CUERPO ────────────────────────────────────────────────
class _SeccionCuerpo extends StatelessWidget {
  final String nombrePareja;
  final int diasJuntos;
  final int totalPlanes;

  static const _negro = Color(0xFF1C1917);
  static const _caramelo = Color(0xFF8B7355);
  static const _beige = Color(0xFFB5A898);
  static const _beigeSuave = Color(0xFFC9B89E);
  static const _linea = Color(0xFFE8DDD3);

  const _SeccionCuerpo({
    required this.nombrePareja,
    required this.diasJuntos,
    required this.totalPlanes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle / nombre de pareja
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              nombrePareja.toLowerCase().replaceAll(' ', ''),
              style: GoogleFonts.inter(
                fontSize: 10,
                letterSpacing: 2.5,
                color: _beige,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Número grande + "días juntos"
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$diasJuntos',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 108,
                  fontWeight: FontWeight.w900,
                  color: _negro,
                  height: 0.82,
                  letterSpacing: -6,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'días\njuntos',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 19,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w300,
                    color: _caramelo,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Ornamento divisor
          Row(
            children: [
              Expanded(child: Container(height: 0.5, color: _linea)),
              const SizedBox(width: 10),
              Container(
                  width: 3, height: 3,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _beigeSuave)),
              const SizedBox(width: 4),
              Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _beige)),
              const SizedBox(width: 4),
              Container(
                  width: 3, height: 3,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _beigeSuave)),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 0.5, color: _linea)),
            ],
          ),

          const SizedBox(height: 20),

          // Stats
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    valor: '$totalPlanes',
                    label: 'CITAS JUNTOS',
                  ),
                ),
                Container(width: 0.5, color: _linea),
                Expanded(
                  child: _Stat(
                    valor: '∞',
                    label: 'POR VIVIR',
                    esInfinito: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── STAT ──────────────────────────────────────────────────────────
class _Stat extends StatelessWidget {
  final String valor;
  final String label;
  final bool esInfinito;

  static const _negro = Color(0xFF1C1917);
  static const _beige = Color(0xFFB5A898);
  static const _caramelo = Color(0xFF8B7355);

  const _Stat({
    required this.valor,
    required this.label,
    this.esInfinito = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor,
            style: GoogleFonts.playfairDisplay(
              fontSize: 40,
              fontWeight: esInfinito ? FontWeight.w400 : FontWeight.w700,
              fontStyle: esInfinito ? FontStyle.italic : FontStyle.normal,
              color: esInfinito ? _caramelo : _negro,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              letterSpacing: 2,
              color: _beige,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── FOOTER ────────────────────────────────────────────────────────
class _SeccionFooter extends StatelessWidget {
  static const _beigeSuave = Color(0xFFC9B89E);
  static const _linea = Color(0xFFE8DDD3);

  const _SeccionFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _linea, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'NUESTRO ESPACIO',
            style: GoogleFonts.inter(
              fontSize: 8,
              letterSpacing: 3,
              color: _beigeSuave,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Container(width: 2, height: 2,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: _beigeSuave)),
              const SizedBox(width: 3),
              Container(width: 2, height: 2,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: _beigeSuave)),
              const SizedBox(width: 3),
              Container(width: 2, height: 2,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: _beigeSuave)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── PAINTERS ─────────────────────────────────────────────────────
class _CorazonPainter extends CustomPainter {
  final Color color;
  final Color strokeColor;

  const _CorazonPainter({required this.color, required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2 + 1;
    final s = size.width / 2.2;

    path.moveTo(cx, cy + s * 0.4);
    path.cubicTo(cx, cy - s * 0.6, cx - s, cy - s * 0.6, cx - s, cy + s * 0.1);
    path.cubicTo(cx - s, cy + s * 0.9, cx, cy + s * 1.3, cx, cy + s * 1.3);
    path.cubicTo(cx, cy + s * 1.3, cx + s, cy + s * 0.9, cx + s, cy + s * 0.1);
    path.cubicTo(cx + s, cy - s * 0.6, cx, cy - s * 0.6, cx, cy + s * 0.4);

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MiniPainterTemporada extends CustomPainter {
  final Color color;
  final Temporada temporada;

  const _MiniPainterTemporada({
    required this.color,
    required this.temporada,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (temporada) {
      case Temporada.sanValentin:
        final path = Path();
        path.moveTo(cx, cy + 7);
        path.cubicTo(cx, cy - 3, cx - 9, cy - 3, cx - 9, cy + 2);
        path.cubicTo(cx - 9, cy + 9, cx, cy + 13, cx, cy + 13);
        path.cubicTo(cx, cy + 13, cx + 9, cy + 9, cx + 9, cy + 2);
        path.cubicTo(cx + 9, cy - 3, cx, cy - 3, cx, cy + 7);
        canvas.drawPath(path, paint);
        break;
      case Temporada.primavera:
        for (int i = 0; i < 5; i++) {
          final a = i * 72 * 3.14159 / 180;
          canvas.drawCircle(
            Offset(cx + 9 * _cos(a), cy + 9 * _sin(a)), 4, paint);
        }
        canvas.drawCircle(Offset(cx, cy), 3, paint..style = PaintingStyle.fill);
        break;
      case Temporada.verano:
        canvas.drawCircle(Offset(cx, cy), 6, paint..style = PaintingStyle.stroke);
        for (int i = 0; i < 8; i++) {
          final a = i * 45 * 3.14159 / 180;
          canvas.drawLine(
            Offset(cx + 9 * _cos(a), cy + 9 * _sin(a)),
            Offset(cx + 13 * _cos(a), cy + 13 * _sin(a)), paint);
        }
        break;
      case Temporada.otono:
        final path = Path();
        path.moveTo(cx, cy + 11);
        path.quadraticBezierTo(cx - 12, cy, cx, cy - 11);
        path.quadraticBezierTo(cx + 12, cy, cx, cy + 11);
        canvas.drawPath(path, paint);
        canvas.drawLine(Offset(cx, cy + 11), Offset(cx, cy - 11), paint);
        break;
      case Temporada.halloween:
        final path = Path();
        path.moveTo(cx, cy);
        path.quadraticBezierTo(cx - 7, cy - 7, cx - 13, cy - 1);
        path.quadraticBezierTo(cx - 8, cy + 3, cx, cy + 3);
        path.moveTo(cx, cy);
        path.quadraticBezierTo(cx + 7, cy - 7, cx + 13, cy - 1);
        path.quadraticBezierTo(cx + 8, cy + 3, cx, cy + 3);
        canvas.drawPath(path, paint);
        canvas.drawCircle(Offset(cx, cy - 2), 2.5, paint);
        break;
      case Temporada.navidad:
        for (int i = 0; i < 6; i++) {
          final a = i * 60 * 3.14159 / 180;
          canvas.drawLine(Offset(cx, cy),
            Offset(cx + 12 * _cos(a), cy + 12 * _sin(a)), paint);
          final mx = cx + 6 * _cos(a);
          final my = cy + 6 * _sin(a);
          final perp = a + 3.14159 / 2;
          canvas.drawLine(Offset(mx, my),
            Offset(mx + 3 * _cos(perp), my + 3 * _sin(perp)), paint);
          canvas.drawLine(Offset(mx, my),
            Offset(mx - 3 * _cos(perp), my - 3 * _sin(perp)), paint);
        }
        break;
      case Temporada.ninguna:
        break;
    }
  }

  double _cos(double a) {
    final x = a % (2 * 3.14159265);
    return 1 - x*x/2 + x*x*x*x/24 - x*x*x*x*x*x/720;
  }

  double _sin(double a) {
    final x = a % (2 * 3.14159265);
    return x - x*x*x/6 + x*x*x*x*x/120;
  }

  @override
  bool shouldRepaint(_) => false;
}
