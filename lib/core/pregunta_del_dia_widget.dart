import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class PreguntaDelDiaWidget extends StatefulWidget {
  const PreguntaDelDiaWidget({super.key});

  @override
  State<PreguntaDelDiaWidget> createState() => _PreguntaDelDiaWidgetState();
}

class _PreguntaDelDiaWidgetState extends State<PreguntaDelDiaWidget> {
  final _supabase = Supabase.instance.client;
  final _ctrl = TextEditingController();

  static const _rosa = Color(0xFFFF6A88);
  static const _negro = Color(0xFF1C1917);

  Map<String, dynamic>? _pregunta;
  Map<String, dynamic>? _miRespuesta;
  Map<String, dynamic>? _respuestaPareja;
  bool _cargando = true;
  bool _guardando = false;
  String? _turnoActual;
  bool _bloqueado = false;
  String? _motivoBloqueado;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _turnoAhora() {
    final hora = DateTime.now().hour;
    if (hora >= 6 && hora < 11) return 'manana';
    if (hora >= 15 && hora < 23) return 'tarde';
    return 'ninguno';
  }

  String _motivoBloqueo() {
    final hora = DateTime.now().hour;
    if (hora < 6) return 'La pregunta de la mañana estará disponible a las 6:00 AM ';
    if (hora >= 11 && hora < 17) return 'La pregunta de la mañana terminó. La de la tarde se activa a las 5:00 PM 🌅';
    if (hora >= 23) return 'La pregunta de la tarde cerró. La próxima estará disponible a las 6:00 AM ';
    return '';
  }

  Future<void> _inicializar() async {
    setState(() => _cargando = true);

    final turno = _turnoAhora();
    debugPrint('🕐 Turno actual: $turno');
    debugPrint('🕐 Hora actual: ${DateTime.now().hour}');

    if (turno == 'ninguno') {
      debugPrint('⛔ Bloqueado por horario');
      setState(() {
        _bloqueado = true;
        _motivoBloqueado = _motivoBloqueo();
        _cargando = false;
      });
      return;
    }

    try {
      setState(() => _turnoActual = turno);

      // Calcular qué pregunta toca hoy
      final hoy = DateTime.now();
      final epoch = DateTime(2026, 1, 1);
      final diasDesdeEpoch = hoy.difference(epoch).inDays;

      // Contar preguntas disponibles de este turno
      final countRes = await _supabase
          .from('preguntas')
          .select('id')
          .eq('turno', turno);
      debugPrint('📊 Preguntas encontradas: ${(countRes as List).length}');
      final totalPreguntas = countRes.length;
      if (totalPreguntas == 0) {
        setState(() => _cargando = false);
        return;
      }

      // Obtener los ids ordenados para calcular cuál toca
      final preguntasRes = await _supabase
          .from('preguntas')
          .select('id, texto')
          .eq('turno', turno)
          .order('id', ascending: true);

      final preguntas = preguntasRes as List;
      final indexHoy = diasDesdeEpoch % totalPreguntas;
      final preguntaHoy = preguntas[indexHoy];

      // Buscar si ya respondí hoy
      final fecha = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

      final misRespuestas = await _supabase
          .from('respuestas_diarias')
          .select('*')
          .eq('pregunta_id', preguntaHoy['id'])
          .eq('usuario_id', SupabaseConfig.currentUserId!)
          .eq('fecha', fecha)
          .eq('turno', turno)
          .maybeSingle();

      // Buscar si mi pareja ya respondió
      final todasRespuestas = await _supabase
          .from('respuestas_diarias')
          .select('*')
          .eq('pregunta_id', preguntaHoy['id'])
          .eq('pareja_id', SupabaseConfig.parejaId!)
          .eq('fecha', fecha)
          .eq('turno', turno);

      final lista = todasRespuestas as List;
      final respuestaParejaIndex = lista.indexWhere(
        (r) => r['usuario_id'] != SupabaseConfig.currentUserId,
      );
      final respuestaPareja = respuestaParejaIndex >= 0
          ? lista[respuestaParejaIndex]
          : null;

      if (mounted) {
        setState(() {
          _pregunta = Map<String, dynamic>.from(preguntaHoy);
          _miRespuesta = misRespuestas != null
              ? Map<String, dynamic>.from(misRespuestas)
              : null;
          _respuestaPareja = respuestaPareja != null
              ? Map<String, dynamic>.from(respuestaPareja)
              : null;
          _cargando = false;
        });
      }

      // Escuchar en tiempo real si mi pareja responde
      _supabase
          .from('respuestas_diarias')
          .stream(primaryKey: ['id'])
          .eq('pareja_id', SupabaseConfig.parejaId!)
          .listen((data) {
        final hoyStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
        final resp = data.where((r) =>
          r['usuario_id'] != SupabaseConfig.currentUserId &&
          r['pregunta_id'] == _pregunta?['id'] &&
          r['fecha'] == hoyStr &&
          r['turno'] == _turnoActual,
        ).toList();

        if (resp.isNotEmpty && mounted) {
          setState(() => _respuestaPareja = resp.first);
        }
      });
    } catch (e) {
      debugPrint('Error inicializando PreguntaDelDia: $e');
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarRespuesta() async {
    if (_ctrl.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _guardando = true);

    final hoy = DateTime.now();
    final fecha = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

    await _supabase.from('respuestas_diarias').insert({
      'pareja_id': SupabaseConfig.parejaId,
      'pregunta_id': _pregunta!['id'],
      'usuario_id': SupabaseConfig.currentUserId,
      'respuesta': _ctrl.text.trim(),
      'turno': _turnoActual,
      'fecha': fecha,
    });

    final data = await _supabase
        .from('respuestas_diarias')
        .select('*')
        .eq('pregunta_id', _pregunta!['id'])
        .eq('usuario_id', SupabaseConfig.currentUserId!)
        .eq('fecha', fecha)
        .eq('turno', _turnoActual!)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _miRespuesta = data != null ? Map<String, dynamic>.from(data) : null;
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6A88),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_bloqueado) return _CardBloqueada(motivo: _motivoBloqueado ?? '');
    if (_pregunta == null) return const SizedBox();

    final amboRespondieron =
        _miRespuesta != null && _respuestaPareja != null;
    final yoRespondio = _miRespuesta != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withAlpha(60),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            decoration: BoxDecoration(
              color: _rosa.withAlpha(12),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: _rosa.withAlpha(30),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _rosa.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _turnoActual == 'manana'
                        ? Icons.wb_sunny_rounded
                        : Icons.nights_stay_rounded,
                    size: 16,
                    color: _rosa,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _turnoActual == 'manana'
                            ? 'Pregunta de la mañana'
                            : 'Pregunta de la tarde',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _rosa,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        amboRespondieron
                            ? '¡Los dos respondieron! '
                            : yoRespondio
                                ? 'Esperando a tu pareja...'
                                : 'Responde antes de que cierre',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(120),
                        ),
                      ),
                    ],
                  ),
                ),
                // Indicadores de quién respondió
                Row(
                  children: [
                    _IndicadorRespuesta(respondio: yoRespondio, esMio: true),
                    const SizedBox(width: 4),
                    _IndicadorRespuesta(
                        respondio: _respuestaPareja != null, esMio: false),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Pregunta ────────────────────────────
                Text(
                  _pregunta!['texto'] as String,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _negro,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Si ambos respondieron: mostrar ambas ─
                if (amboRespondieron) ...[
                  _BurbujaRespuesta(
                    respuesta: _miRespuesta!['respuesta'] as String,
                    esMio: true,
                    label: 'Yo',
                  ),
                  const SizedBox(height: 8),
                  _BurbujaRespuesta(
                    respuesta: _respuestaPareja!['respuesta'] as String,
                    esMio: false,
                    label: 'Mi pareja',
                  ),
                ]

                // ── Si yo ya respondí, esperar al otro ──
                else if (yoRespondio) ...[
                  _BurbujaRespuesta(
                    respuesta: _miRespuesta!['respuesta'] as String,
                    esMio: true,
                    label: 'Tu respuesta',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withAlpha(40),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(80),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Esperando que tu pareja responda...',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(100),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]

                // ── Si nadie ha respondido: campo de texto ─
                else ...[
                  TextField(
                    controller: _ctrl,
                    maxLines: 3,
                    maxLength: 300,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu respuesta...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(80),
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counterStyle: GoogleFonts.inter(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(80),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardarRespuesta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _rosa,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Responder',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── CARD BLOQUEADA ────────────────────────────────────────────────
class _CardBloqueada extends StatelessWidget {
  final String motivo;
  
  const _CardBloqueada({super.key, required this.motivo});

  static const _rosa = Color(0xFFFF6A88);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _rosa.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.lock_clock_rounded,
                color: _rosa.withAlpha(150), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pregunta del día',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  motivo,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(120),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── BURBUJA DE RESPUESTA ──────────────────────────────────────────
class _BurbujaRespuesta extends StatelessWidget {
  final String respuesta;
  final bool esMio;
  final String label;

  static const _rosa = Color(0xFFFF6A88);
  static const _azul = Color(0xFF7B9EFF);

  const _BurbujaRespuesta({
    required this.respuesta,
    required this.esMio,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = esMio ? _rosa : _azul;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(40), width: 0.5),
          ),
          child: Text(
            respuesta,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ── INDICADOR DE RESPUESTA ────────────────────────────────────────
class _IndicadorRespuesta extends StatelessWidget {
  final bool respondio;
  final bool esMio;

  static const _rosa = Color(0xFFFF6A88);
  static const _azul = Color(0xFF7B9EFF);

  const _IndicadorRespuesta({
    required this.respondio,
    required this.esMio,
  });

  @override
  Widget build(BuildContext context) {
    final color = esMio ? _rosa : _azul;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: respondio ? color : color.withAlpha(40),
        border: Border.all(
          color: respondio ? color : color.withAlpha(80),
          width: 1,
        ),
      ),
    );
  }
}
