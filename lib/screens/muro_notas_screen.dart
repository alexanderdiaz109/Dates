import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../core/enviar_notificacion.dart';
import '../core/supabase_config.dart';
import '../core/nota_postit_widget.dart';
import '../core/audio_recorder_service.dart';
import '../core/nota_voz_widget.dart';
import '../core/decoracion_temporada_widget.dart';

class MuroNotasScreen extends StatefulWidget {
  const MuroNotasScreen({super.key});

  @override
  State<MuroNotasScreen> createState() => _MuroNotasScreenState();
}

class _MuroNotasScreenState extends State<MuroNotasScreen> {
  List<Map<String, dynamic>> _notas = [];
  RealtimeChannel? _channel;
  bool _temporadaActiva = true;

  @override
  void initState() {
    super.initState();
    _cargarNotas();
    _cargarTemporada();
    _suscribirRealtime();
  }

  Future<void> _cargarTemporada() async {
    if (SupabaseConfig.parejaId == null) return;
    final data = await Supabase.instance.client
        .from('parejas')
        .select('temporada_activa')
        .eq('id', SupabaseConfig.parejaId!)
        .maybeSingle();
    if (mounted) {
      setState(() => _temporadaActiva = data?['temporada_activa'] as bool? ?? true);
    }
  }

  Future<void> _cargarNotas() async {
    final data = await Supabase.instance.client
        .from('notas')
        .select('*')
        .order('creado_en', ascending: false);
        
    for (final nota in data) {
      print('📝 Nota ${nota['id']}: reaccion = ${nota['reaccion']}');
    }

    if (mounted) setState(() => _notas = List<Map<String, dynamic>>.from(data));
  }

  void _suscribirRealtime() {
    _channel = Supabase.instance.client
        .channel('notas_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notas',
          callback: (payload) => _cargarNotas(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // Paleta extendida de colores pastel y tonos vibrantes suaves
  final List<int> _coloresPastel = [
    0xFFFFF9E6, // Pergamino
    0xFFFFE0E6, // Coral
    0xFFE2F0CB, // Salvia
    0xFFD4E6F1, // Bruma
    0xFFE8DAEF, // Lavanda
    0xFFFCF3CF, // Mantequilla
    0xFFFFCC80, // Naranja suave
    0xFFB2EBF2, // Cian claro
    0xFFF8BBD0, // Rosa pálido
    0xFFC8E6C9, // Verde menta
    0xFFD7CCC8, // Arena
    0xFFCFD8DC, // Gris azulado
  ];

  Future<void> _eliminarNota(String id) async {
    try {
      await Supabase.instance.client.from('notas').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[400]),
        );
      }
    }
  }

  void _confirmarEliminar(String id, String texto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Borrar nota?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('"$texto"',
            style: const TextStyle(color: Color(0xFF7F8C8D))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eliminarNota(id);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalNuevaNota(BuildContext context) {
    int colorSeleccionado = _coloresPastel[0]; // Empieza en Pergamino
    final textoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Fondo transparente para el diseño flotante
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24, left: 24, right: 24
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E), // Fondo oscuro inmersivo
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nueva Nota', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 24),
                
                // Área de texto simulando el papel elegido
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(colorSeleccionado),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: textoController,
                    maxLines: 4,
                    maxLength: 100,
                    style: GoogleFonts.kalam(fontSize: 22, color: const Color(0xFF2C3E50)), // Usa la misma letra
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Escribe algo bonito...',
                      counterStyle: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Selector de colores con animación (Wrap para soportar más opciones)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: _coloresPastel.map((hex) {
                    bool esElegido = colorSeleccionado == hex;
                    return GestureDetector(
                      onTap: () => setModalState(() => colorSeleccionado = hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: esElegido ? 36 : 28,
                        height: esElegido ? 36 : 28,
                        decoration: BoxDecoration(
                          color: Color(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: esElegido ? Colors.white : Colors.transparent, 
                            width: 3
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // Botón de guardar
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A88),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (textoController.text.trim().isEmpty) return;
                      
                      try {
                        final pId = SupabaseConfig.parejaId ?? await SupabaseConfig.obtenerParejaId();
                        await Supabase.instance.client.from('notas').insert({
                            'texto': textoController.text.trim(),
                            'color_hex': colorSeleccionado.toRadixString(16), // Guardar como string hex para compatibilidad
                            'rotacion': 0.0, // Necesario porque tu tabla en Supabase lo exige (aunque ahora lo calculamos automático)
                            'pareja_id': pId,
                            'usuario_id': SupabaseConfig.currentUserId,
                        });
                        
                        if(context.mounted) {
                          Navigator.pop(context);
                          EnviarNotificacion.enviarAPareja(
                            'Nueva nota 📌',
                            'Te han dejado un Post-it en el muro.',
                          );
                        }
                      } catch(e) {
                         if(context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[400]),
                           );
                         }
                      }
                    },
                    child: const Text('PEGAR EN EL MURO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoracionTemporadaWidget(
      activa: _temporadaActiva,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // EL NUEVO ICONO ARRIBA (Reemplaza el botón amarillo)
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Nuestros Recados', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.mic_rounded, color: Color(0xFFFF6A88), size: 28),
              onPressed: () => _abrirModalNuevaVoz(context),
              tooltip: 'Nota de voz',
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Color(0xFFFF6A88), size: 32),
              onPressed: () => _abrirModalNuevaNota(context),
              tooltip: 'Nota de texto',
            ),
            const SizedBox(width: 8),
          ],
        ),
        // EL MURO DE NOTAS
        body: _notas.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'El muro está vacío.\n¡Deja el primer mensaje!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              )
            : MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _notas.length,
                itemBuilder: (context, index) {
                  final nota = _notas[index];
                  final tipo = nota['tipo'] as String? ?? 'texto';

                  if (tipo == 'voz') {
                    return NotaVozWidget(
                      key: ValueKey('${nota['id']}_${nota['reaccion']}'),
                      notaId: nota['id'].toString(),
                      audioUrl: nota['audio_url'] as String? ?? '',
                      duracionSegundos: nota['duracion_segundos'] as int? ?? 0,
                      index: index,
                      reaccion: nota['reaccion'] as String?,
                      onEliminar: () => _confirmarEliminar(nota['id'].toString(), '🎙️ Nota de voz'),
                    );
                  }

                  int colorNota = _coloresPastel[0];
                  if (nota['color_hex'] != null) {
                    if (nota['color_hex'] is int) {
                      colorNota = nota['color_hex'];
                    } else if (nota['color_hex'] is String) {
                      colorNota = int.tryParse(nota['color_hex'], radix: 16) ?? _coloresPastel[0];
                    }
                  }

                  return NotaPostItWidget(
                    key: ValueKey('${nota['id']}_${nota['reaccion']}'),
                    texto: nota['texto'] ?? '',
                    colorHex: colorNota,
                    index: index,
                    notaId: nota['id'].toString(),
                    reaccion: nota['reaccion'] as String?,
                    onEliminar: () => _confirmarEliminar(nota['id'].toString(), nota['texto']),
                  );
                },
              ),
      ),
    );
  }

  void _abrirModalNuevaVoz(BuildContext context) {
    String? _rutaAudio;
    int _segundos = 0;
    bool _grabando = false;
    bool _grabacionLista = false;
    bool _guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> iniciarGrabacion() async {
            final permiso = await Permission.microphone.request();
            if (!permiso.isGranted) return;

            await AudioRecorderService.iniciarGrabacion();
            setModalState(() { _grabando = true; _segundos = 0; });

            Future.doWhile(() async {
              await Future.delayed(const Duration(seconds: 1));
              if (!_grabando) return false;
              setModalState(() => _segundos++);
              if (_segundos >= 120) {
                final ruta = await AudioRecorderService.detenerGrabacion();
                setModalState(() {
                  _rutaAudio = ruta;
                  _grabando = false;
                  _grabacionLista = true;
                });
                return false;
              }
              return true;
            });
          }

          Future<void> detenerGrabacion() async {
            final ruta = await AudioRecorderService.detenerGrabacion();
            setModalState(() {
              _rutaAudio = ruta;
              _grabando = false;
              _grabacionLista = true;
            });
          }

          Future<void> enviarVoz() async {
            if (_rutaAudio == null) return;
            setModalState(() => _guardando = true);

            try {
              final archivo = File(_rutaAudio!);
              final nombre = 'voz_${DateTime.now().millisecondsSinceEpoch}.m4a';
              await Supabase.instance.client.storage
                  .from('audios')
                  .upload(nombre, archivo,
                      fileOptions: const FileOptions(
                          contentType: 'audio/m4a', upsert: false));

              final url = Supabase.instance.client.storage
                  .from('audios')
                  .getPublicUrl(nombre);

              await Supabase.instance.client.from('notas').insert({
                'tipo': 'voz',
                'audio_url': url,
                'duracion_segundos': _segundos,
                'pareja_id': SupabaseConfig.parejaId,
                'usuario_id': SupabaseConfig.currentUserId,
                'color_hex': 'FF6A88',
              });

              if (ctx.mounted) {
                Navigator.pop(ctx);
                EnviarNotificacion.enviarAPareja(
                  'Nota de voz 🎙️',
                  'Te dejaron un mensaje de voz en el muro.',
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'),
                      backgroundColor: Colors.red[400]),
                );
              }
            } finally {
              setModalState(() => _guardando = false);
            }
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
              top: 24, left: 24, right: 24,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  _grabacionLista ? 'Nota lista' : '¿Qué quieres decirle?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _grabacionLista
                      ? 'Duración: ${_segundos}s'
                      : _grabando
                          ? '$_segundos / 120s'
                          : 'Toca el micrófono para grabar',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 40),
                if (!_grabacionLista)
                  GestureDetector(
                    onTap: _grabando ? detenerGrabacion : iniciarGrabacion,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _grabando ? 80 : 72,
                      height: _grabando ? 80 : 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _grabando
                            ? Colors.red
                            : const Color(0xFFFF6A88),
                        boxShadow: [
                          BoxShadow(
                            color: (_grabando ? Colors.red : const Color(0xFFFF6A88))
                                .withAlpha(100),
                            blurRadius: _grabando ? 24 : 12,
                            spreadRadius: _grabando ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        _grabando ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                if (_grabacionLista) ...[
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFFFF6A88), size: 64),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6A88),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _guardando ? null : enviarVoz,
                      child: _guardando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Enviar al muro 🎙️',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              )),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setModalState(() {
                      _rutaAudio = null;
                      _grabacionLista = false;
                      _segundos = 0;
                    }),
                    child: Text('Grabar de nuevo',
                        style: TextStyle(color: Colors.white.withAlpha(150))),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
