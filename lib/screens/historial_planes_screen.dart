import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class HistorialPlanesScreen extends StatefulWidget {
  const HistorialPlanesScreen({super.key});

  @override
  State<HistorialPlanesScreen> createState() => _HistorialPlanesScreenState();
}

class _HistorialPlanesScreenState extends State<HistorialPlanesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _planes = [];
  bool _cargando = true;

  static const _rosa = Color(0xFFFF6A88);
  static const _negro = Color(0xFF1C1917);
  static const _beige = Color(0xFFB5A898);
  static const _linea = Color(0xFFE8DDD3);

  @override
  void initState() {
    super.initState();
    _cargarPlanes();
  }

  Future<void> _cargarPlanes() async {
    final data = await _supabase
        .from('planes')
        .select('*')
        .eq('estado', 'Completado')
        .order('fecha_exacta', ascending: false);
    if (mounted) {
      setState(() {
        _planes = List<Map<String, dynamic>>.from(data);
        _cargando = false;
      });
    }
  }

  String _formatearMes(String? fechaStr) {
    if (fechaStr == null) return '';
    final fecha = DateTime.tryParse(fechaStr);
    if (fecha == null) return '';
    const meses = ['Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];
    return meses[fecha.month - 1];
  }

  String _formatearDia(String? fechaStr) {
    if (fechaStr == null) return '';
    final fecha = DateTime.tryParse(fechaStr);
    if (fecha == null) return '';
    return '${fecha.day}';
  }

  String _formatearFechaCompleta(String? fechaStr) {
    if (fechaStr == null) return '';
    final fecha = DateTime.tryParse(fechaStr);
    if (fecha == null) return '';
    const meses = ['ene','feb','mar','abr','may','jun',
                   'jul','ago','sep','oct','nov','dic'];
    final hora = fecha.hour;
    final min = fecha.minute.toString().padLeft(2, '0');
    final ampm = hora >= 12 ? 'PM' : 'AM';
    final hora12 = hora > 12 ? hora - 12 : (hora == 0 ? 12 : hora);
    return '${fecha.day} ${meses[fecha.month - 1]} · $hora12:$min $ampm';
  }

  int _anio(Map<String, dynamic> plan) {
    final f = DateTime.tryParse(plan['fecha_exacta'] ?? '');
    return f?.year ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          color: _negro,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nuestra historia',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _negro,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_cargando)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _linea),
              ),
              child: Text(
                '${_planes.length} citas',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _beige,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A88)))
          : _planes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_outline_rounded,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aún no hay citas completadas',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: _planes.length,
                  itemBuilder: (context, i) {
                    final plan = _planes[i];
                    final esUltimo = i == _planes.length - 1;

                    // Separador de año
                    final anioActual = _anio(plan);
                    final anioAnterior = i > 0 ? _anio(_planes[i - 1]) : null;
                    final mostrarAnio = anioAnterior == null || anioAnterior != anioActual;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mostrarAnio)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 44, top: 12, bottom: 10),
                            child: Text(
                              '$anioActual',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                                color: const Color(0xFFBBBBBB),
                              ),
                            ),
                          ),
                        _TimelineItem(
                          plan: plan,
                          esUltimo: esUltimo,
                          mes: _formatearMes(plan['fecha_exacta']),
                          fechaCompleta: _formatearFechaCompleta(plan['fecha_exacta']),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool esUltimo;
  final String mes;
  final String fechaCompleta;

  static const _negro = Color(0xFF1C1917);
  static const _linea = Color(0xFFE8DDD3);
  static const _beige = Color(0xFFB5A898);

  const _TimelineItem({
    required this.plan,
    required this.esUltimo,
    required this.mes,
    required this.fechaCompleta,
  });

  @override
  Widget build(BuildContext context) {
    final calificacion = plan['calificacion'] as int? ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Columna izquierda ─────────────────────
        SizedBox(
          width: 44,
          child: Column(
            children: [
              Text(
                mes.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: const Color(0xFFBBBBBB),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4CAF50),
                ),
              ),
              if (!esUltimo)
                Container(
                  width: 1,
                  height: 60,
                  color: _linea,
                  margin: const EdgeInsets.only(top: 2),
                ),
            ],
          ),
        ),

        // ── Card ─────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEBEBEB), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (plan['icono'] != null && plan['icono'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(plan['icono'],
                            style: const TextStyle(fontSize: 14)),
                      ),
                    Expanded(
                      child: Text(
                        plan['titulo'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _negro,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Completado',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  fechaCompleta,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: _beige,
                  ),
                ),
                if (calificacion > 0) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: List.generate(5, (i) => Text(
                      i < calificacion ? '⭐' : '',
                      style: const TextStyle(fontSize: 10),
                    )),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
