import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/estado_animo_widget.dart';
import '../core/pregunta_del_dia_widget.dart';
import '../core/supabase_config.dart';
import '../core/decoracion_temporada_widget.dart';
import '../core/temporada_service.dart';
import '../core/temporada_theme.dart';
import 'wishlist_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Streams inicializados una sola vez (no dentro de build)
  Stream<List<Map<String, dynamic>>>? _streamConfig;
  late final Stream<List<Map<String, dynamic>>> _streamPlanes;
  bool _temporadaActiva = true;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;

    _streamPlanes = client
        .from('planes')
        .stream(primaryKey: ['id'])
        .eq('estado', 'Planeado')
        .order('fecha_exacta', ascending: true);

    _iniciarStreamConfig();
  }

  void _iniciarStreamConfig() {
    final parejaId = SupabaseConfig.parejaId;
    if (parejaId == null) return;
    setState(() {
      _streamConfig = Supabase.instance.client
          .from('parejas')
          .stream(primaryKey: ['id'])
          .eq('id', parejaId);
    });
  }

  /// Calcula días juntos, días para el próximo aniversario y texto de fecha
  Map<String, dynamic> _calcularAniversario(DateTime fechaAniv) {
    final hoy = DateTime.now();
    final diasJuntos = hoy.difference(fechaAniv).inDays;

    DateTime proximo =
        DateTime(hoy.year, fechaAniv.month, fechaAniv.day);
    final esHoy = proximo.day == hoy.day && proximo.month == hoy.month;
    if (!esHoy && proximo.isBefore(hoy)) {
      proximo =
          DateTime(hoy.year + 1, fechaAniv.month, fechaAniv.day);
    }

    final faltanDias = proximo.difference(hoy).inDays;

    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final textoFecha =
        '${fechaAniv.day} de ${meses[fechaAniv.month - 1]}';

    return {
      'diasJuntos': diasJuntos,
      'faltanDias': faltanDias,
      'esHoy': esHoy,
      'textoFecha': textoFecha,
    };
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _streamConfig ?? const Stream.empty(),
      builder: (context, snapConfig) {
        final config = (snapConfig.hasData && snapConfig.data!.isNotEmpty) ? snapConfig.data!.first : null;
        final temporadaActiva = config?['temporada_activa'] as bool? ?? true;

        int diasJuntos = 0;
        int faltanDias = 0;
        bool esHoy = false;
        bool fechaConfigurada = false;
        String textoFecha = 'Configura en Perfil';

        if (config != null) {
          final raw = config['fecha_aniversario'];
          if (raw != null) {
            try {
              final fecha = DateTime.parse(raw as String);
              final calc = _calcularAniversario(fecha);
              diasJuntos = calc['diasJuntos'] as int;
              faltanDias = calc['faltanDias'] as int;
              esHoy = calc['esHoy'] as bool;
              textoFecha = calc['textoFecha'] as String;
              fechaConfigurada = true;
            } catch (_) {}
          }
        }

        return DecoracionTemporadaWidget(
          activa: temporadaActiva,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen de nuestro día',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // ── TARJETA CENTRAL: CONTADOR ───────────────
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: temporadaActiva
                            ? TemporadaTheme(TemporadaService.detectar()).gradienteDashboard
                            : [const Color(0xFFFF6A88), const Color(0xFFFF8C69)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6A88).withAlpha(102),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -30,
                            top: -20,
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 160,
                                color: Colors.white.withAlpha(38),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(
                              child: Column(
                                children: [
                                  const Text(
                                    'LLEVAMOS JUNTOS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 600),
                                    child: Text(
                                      key: ValueKey(diasJuntos),
                                      // Muestra '?' si la fecha no está configurada aún
                                      fechaConfigurada
                                          ? diasJuntos.toString()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 76,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black12,
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'días',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(230),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const EstadoAnimoWidget(),
                  const SizedBox(height: 24),
                  const PreguntaDelDiaWidget(),
                  const SizedBox(height: 28),
                  Text(
                    'Próximos momentos',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // ── TARJETA ANIVERSARIO ─────────────────
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          icon: Icons.auto_awesome_rounded,
                          title: 'Aniversario',
                          highlight: !fechaConfigurada
                              ? 'Ve a Perfil → ❤️'
                              : esHoy
                                  ? '¡Es hoy! 🎉'
                                  : 'Faltan $faltanDias días',
                          subtitle: textoFecha,
                          highlightColor: primary,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // ── STREAM: PRÓXIMA CITA ────────────────
                      Expanded(
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _streamPlanes,
                          builder: (context, snapPlanes) {
                            String titulo = 'Siguiente Cita';
                            String detalle = 'Sin planes aún';
                            String sub = 'Planea algo pronto 💫';

                            if (snapPlanes.hasData &&
                                snapPlanes.data!.isNotEmpty) {
                              final plan = snapPlanes.data!.first;
                              titulo = plan['titulo'] as String? ??
                                  'Siguiente Cita';
                              
                              if (plan['fecha_exacta'] != null) {
                                final fechaPlan = DateTime.parse(plan['fecha_exacta']).toLocal();
                                final hoy = DateTime.now();
                                final fPlanPura = DateTime(fechaPlan.year, fechaPlan.month, fechaPlan.day);
                                final hoyPura = DateTime(hoy.year, hoy.month, hoy.day);
                                
                                final diasDiferencia = fPlanPura.difference(hoyPura).inDays;
                                
                                if (diasDiferencia == 0) {
                                  detalle = '¡Es hoy!';
                                } else if (diasDiferencia == 1) {
                                  detalle = 'Falta 1 día';
                                } else if (diasDiferencia > 1) {
                                  detalle = 'Faltan $diasDiferencia días';
                                } else if (diasDiferencia == -1) {
                                  detalle = 'Fue ayer';
                                } else {
                                  detalle = 'Hace ${-diasDiferencia} días';
                                }
                                sub = plan['fecha_texto'] as String? ?? '—';
                              } else {
                                detalle = plan['fecha_texto'] as String? ?? '—';
                                sub = '¡Ya casi!';
                              }
                            }

                            return _buildInfoCard(
                              context,
                              icon: Icons.restaurant_rounded,
                              title: titulo,
                              highlight: detalle,
                              subtitle: sub,
                              highlightColor: const Color(0xFFE67E22),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

          const SizedBox(height: 24),

          // ── ACCESO A LA BUCKET LIST ──────────────────────────
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WishlistScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nuestra Bucket List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        SizedBox(height: 4),
                        Text('Lugares y experiencias por conquistar juntos.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 32),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // ── TARJETA DE IDEA ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor.withAlpha(60)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFFF39C12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Idea para hoy',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Déjale una nota rápida en el muro de Post-its antes de que termine el día.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ], // children of Row
            ), // Row
          ), // Container
        ], // children of main Column
      ), // main Column
    ), // SingleChildScrollView
  ); // DecoracionTemporadaWidget
}, // builder
); // StreamBuilder
}

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String highlight,
    required String subtitle,
    required Color highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: highlightColor.withAlpha(25),
            child: Icon(icon, color: highlightColor, size: 18),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            highlight,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: highlightColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(140)),
          ),
        ],
      ),
    );
  }
}
