import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/enviar_notificacion.dart';
import 'visor_imagen_screen.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'detalle_recuerdo_screen.dart';

class CitasScreen extends StatefulWidget {
  const CitasScreen({super.key});

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  int _estrellasSeleccionadas = 5; // Variable para calificación interactiva

  // Streams en tiempo real para ambas tablas
  late final Stream<List<Map<String, dynamic>>> _planesStream;
  late final Stream<List<Map<String, dynamic>>> _recuerdosStream;

  // Controladores para el formulario de Planes
  final _tituloPlanController = TextEditingController();
  final _fechaPlanController = TextEditingController();
  final _descPlanController = TextEditingController();

  // Controladores para el formulario de Recuerdos
  final _tituloRecuerdoController = TextEditingController();
  final _comentarioRecuerdoController = TextEditingController();

  List<File> _imagenesSeleccionadas = [];
  bool _estaGuardando = false;
  DateTime? _fechaExactaPlan; // Fecha matemática para calcular días restantes

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    // Streams apuntando a las tablas de Supabase
    _planesStream = _supabase
        .from('planes')
        .stream(primaryKey: ['id'])
        .eq('estado', 'Planeado')
        .order('fecha_exacta', ascending: true);

    _recuerdosStream = _supabase
        .from('recuerdos')
        .stream(primaryKey: ['id']).order('creado_en', ascending: false);
  }

  List<String> _parseImages(String? urlField) {
    if (urlField == null || urlField.isEmpty) return [];
    if (urlField.startsWith('[') && urlField.endsWith(']')) {
      try {
        final List<dynamic> decoded = jsonDecode(urlField);
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return [urlField];
      }
    }
    return [urlField];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tituloPlanController.dispose();
    _fechaPlanController.dispose();
    _descPlanController.dispose();
    _tituloRecuerdoController.dispose();
    _comentarioRecuerdoController.dispose();
    super.dispose();
  }

  // ---- Seleccionar foto de la galería del celular ----
  Future<void> _seleccionarFoto(StateSetter setModalState) async {
    // Solicitar permiso explícitamente (obligatorio en MIUI/Xiaomi)
    PermissionStatus status;
    if (await Permission.photos.isGranted) {
      status = PermissionStatus.granted;
    } else {
      // En Android 13+ se usa photos; en versiones anteriores storage
      status = await Permission.photos.request();
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        _mostrarError('Permiso denegado. Ve a Ajustes → Permisos → Galería y actívalo.');
        await openAppSettings();
      }
      return;
    }

    if (status.isDenied) {
      _mostrarError('Se necesita permiso de galería para elegir una foto.');
      return;
    }

    final picker = ImagePicker();
    final fotos = await picker.pickMultiImage(
      imageQuality: 70,
      requestFullMetadata: false, // Evita el error en MIUI
    );
    if (fotos.isNotEmpty) {
      setModalState(() {
        _imagenesSeleccionadas = fotos.map((f) => File(f.path)).toList();
      });
    }
  }

  // ==========================================
  // GUARDAR PLAN EN SUPABASE
  // ==========================================
  Future<void> _guardarPlan() async {
    if (_tituloPlanController.text.trim().isEmpty ||
        _fechaPlanController.text.trim().isEmpty) {
      _mostrarError('Por favor llena el título y la fecha.');
      return;
    }

    setState(() => _estaGuardando = true);

    try {
      final pId = SupabaseConfig.parejaId ?? await SupabaseConfig.obtenerParejaId();
      await _supabase.from('planes').insert({
        'titulo': _tituloPlanController.text.trim(),
        'fecha_texto': _fechaPlanController.text.trim(),
        'fecha_exacta': _fechaExactaPlan?.toIso8601String(),
        'descripcion': _descPlanController.text.trim(),
        'estado': 'Planeado',
        'pareja_id': pId,
        'usuario_id': SupabaseConfig.currentUserId,
      });

      _tituloPlanController.clear();
      _fechaPlanController.clear();
      _descPlanController.clear();
      _fechaExactaPlan = null;

      // Notificar a todos los dispositivos
      EnviarNotificacion.enviarAPareja(
        'Nuevo plan creado 🗓️',
        'Revisa la app, hay una nueva cita esperándote.',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Plan creado! 📅'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al guardar plan: $e');
    } finally {
      if (mounted) setState(() => _estaGuardando = false);
    }
  }

  // ==========================================
  // SUBIR FOTO Y GUARDAR RECUERDO EN SUPABASE
  // ==========================================
  Future<void> _guardarRecuerdo() async {
    if (_tituloRecuerdoController.text.trim().isEmpty) {
      _mostrarError('Por favor escribe un título para el recuerdo.');
      return;
    }
    if (_imagenesSeleccionadas.isEmpty) {
      _mostrarError('Por favor elige al menos una foto de la galería.');
      return;
    }

    setState(() => _estaGuardando = true);

    try {
      List<String> urlsPublicas = [];
      for (var img in _imagenesSeleccionadas) {
        final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}_${urlsPublicas.length}.jpg';

        await _supabase.storage.from('recuerdos').upload(
              nombreArchivo,
              img,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );

        urlsPublicas.add(_supabase.storage.from('recuerdos').getPublicUrl(nombreArchivo));
      }

      final imagenUrlFinal = urlsPublicas.length == 1 ? urlsPublicas.first : jsonEncode(urlsPublicas);

      // 3. Guardar el registro en la tabla recuerdos
      final pId = SupabaseConfig.parejaId ?? await SupabaseConfig.obtenerParejaId();
      await _supabase.from('recuerdos').insert({
        'titulo': _tituloRecuerdoController.text.trim(),
        'comentario': _comentarioRecuerdoController.text.trim(),
        'imagen_url': imagenUrlFinal,
        'calificacion': _estrellasSeleccionadas,
        'pareja_id': pId,
        'usuario_id': SupabaseConfig.currentUserId,
      });

      _tituloRecuerdoController.clear();
      _comentarioRecuerdoController.clear();
      _imagenesSeleccionadas.clear();

      // Notificar a todos los dispositivos
      EnviarNotificacion.enviarAPareja(
        'Nuevo recuerdo agregado 📸',
        'Revisa la app, han añadido un momento especial.',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Recuerdo guardado! 💕'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al guardar recuerdo: $e');
    } finally {
      if (mounted) setState(() => _estaGuardando = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red[400],
      ),
    );
  }

  // ==========================================
  // MODAL: NUEVO PLAN
  // ==========================================
  void _abrirModalNuevoPlan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {

          // Selector nativo de fecha y hora
          Future<void> seleccionarFechaHora() async {
            final fecha = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2035),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: child!,
              ),
            );
            if (fecha == null || !context.mounted) return;

            final hora = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (hora == null) return;

            setModalState(() {
              _fechaExactaPlan = DateTime(
                fecha.year, fecha.month, fecha.day,
                hora.hour, hora.minute,
              );
              final min = hora.minute.toString().padLeft(2, '0');
              final h12 = hora.hourOfPeriod == 0 ? 12 : hora.hourOfPeriod;
              final ampm = hora.period == DayPeriod.am ? 'AM' : 'PM';
              _fechaPlanController.text =
                  '${fecha.day}/${fecha.month}/${fecha.year} a las $h12:$min $ampm';
            });
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24, left: 24, right: 24,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planear nueva cita',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _tituloPlanController,
                  decoration: InputDecoration(
                    labelText: 'Título del plan',
                    prefixIcon: const Icon(Icons.title_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                // Campo de fecha — solo lectura, abre calendario al tocar
                TextField(
                  controller: _fechaPlanController,
                  readOnly: true,
                  onTap: seleccionarFechaHora,
                  decoration: InputDecoration(
                    labelText: 'Toca para elegir fecha y hora',
                    prefixIcon: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFFE67E22),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descPlanController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Detalles o ideas',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _estaGuardando ? null : _guardarPlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _estaGuardando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'GUARDAR PLAN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // MODAL: SUBIR RECUERDO (con galería real)
  // ==========================================
  void _abrirModalSubirRecuerdo() {
    _imagenesSeleccionadas.clear(); // Resetear imagen al abrir
    _estrellasSeleccionadas = 5; // Resetear calificación al abrir

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inmortalizar recuerdo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 20),

                // ----- Selector de foto -----
                GestureDetector(
                  onTap: () => _seleccionarFoto(setModalState),
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFBDC3C7)),
                    ),
                    child: _imagenesSeleccionadas.isNotEmpty
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imagenesSeleccionadas.length,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.file(
                                  _imagenesSeleccionadas[i],
                                  fit: BoxFit.cover,
                                  width: 140,
                                ),
                              ),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_rounded,
                                size: 40,
                                color: Color(0xFF95A5A6),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tocar para elegir foto',
                                style: TextStyle(
                                    color: Color(0xFF95A5A6),
                                    fontWeight:
                                        FontWeight.w500),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: _tituloRecuerdoController,
                  decoration: InputDecoration(
                    labelText: '¿Qué evento fue?',
                    prefixIcon:
                        const Icon(Icons.title_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _comentarioRecuerdoController,
                  decoration: InputDecoration(
                    labelText: 'Un breve comentario...',
                    prefixIcon: const Icon(
                        Icons.favorite_border_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 20),
                const Text(
                  'Calificación del recuerdo', 
                  style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 13, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setModalState(() {
                          _estrellasSeleccionadas = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(
                          index < _estrellasSeleccionadas 
                              ? Icons.star_rounded // Estrella llena
                              : Icons.star_border_rounded, // Estrella vacía
                          color: const Color(0xFFFF6A88), // Color coral
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        _estaGuardando ? null : _guardarRecuerdo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                    ),
                    child: _estaGuardando
                        ? const CircularProgressIndicator(
                            color: Colors.white)
                        : const Text(
                            'GUARDAR RECUERDO',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esPestanaPlanes = _tabController.index == 0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        toolbarHeight: 10,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: const Color(0xFF95A5A6),
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
          tabs: const [
            Tab(
                text: 'PRÓXIMOS PLANES',
                icon: Icon(Icons.event_note_rounded)),
            Tab(
                text: 'NUESTROS RECUERDOS',
                icon: Icon(Icons.photo_library_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PestanaPlanes(stream: _planesStream),
          _PestanaRecuerdos(stream: _recuerdosStream),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0, right: 8.0),
        child: FloatingActionButton.extended(
          onPressed: esPestanaPlanes
              ? _abrirModalNuevoPlan
              : _abrirModalSubirRecuerdo,
          backgroundColor: esPestanaPlanes
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFF2C3E50),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: Icon(esPestanaPlanes
              ? Icons.add_task_rounded
              : Icons.add_a_photo_rounded),
          label: Text(
            esPestanaPlanes ? 'Nuevo Plan' : 'Subir Recuerdo',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PESTAÑA: PLANES (Stream en tiempo real)
// ==========================================
class _PestanaPlanes extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  const _PestanaPlanes({required this.stream});

  Future<void> _marcarCompletado(BuildContext context, Map<String, dynamic> plan) async {
    try {
      await Supabase.instance.client
          .from('planes')
          .update({'estado': 'Completado'})
          .eq('id', plan['id']);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cita completada! Revisen su historia 🍷')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A88)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final _planesFuturos = snapshot.data ?? [];

        if (_planesFuturos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No hay planes próximos',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.grey[400])),
                const SizedBox(height: 8),
                Text('¡Crea una nueva cita!',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[300])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: _planesFuturos.length,
          itemBuilder: (context, index) {
            final plan = _planesFuturos[index];
            final esElPrimero = index == 0;

            if (esElPrimero) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SeccionLabel(texto: 'La más próxima'),
                  _HeroCard(
                    plan: plan, 
                    onCompletado: () => _marcarCompletado(context, plan)
                  ),
                  const SizedBox(height: 8),
                  if (_planesFuturos.length > 1)
                    const _SeccionLabel(texto: 'Siguientes'),
                ],
              );
            }

            return _PlanCard(
              plan: plan,
              onCompletado: () => _marcarCompletado(context, plan),
            );
          },
        );
      },
    );
  }
}

// Widget separado con estado para el botón de completar
class _BotonCompletado extends StatefulWidget {
  final String planId;
  final String estadoActual;
  const _BotonCompletado({required this.planId, required this.estadoActual});

  @override
  State<_BotonCompletado> createState() => _BotonCompletadoState();
}

class _BotonCompletadoState extends State<_BotonCompletado> {
  bool _actualizando = false;

  Future<void> _marcarCompletado() async {
    if (widget.estadoActual == 'Completado' || _actualizando) return;
    setState(() => _actualizando = true);
    try {
      await Supabase.instance.client
          .from('planes')
          .update({'estado': 'Completado'})
          .eq('id', widget.planId);
      // El stream actualizará la UI automáticamente
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estaCompletado = widget.estadoActual == 'Completado';

    if (estaCompletado) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2ECC71)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF27AE60), size: 20),
            SizedBox(width: 8),
            Text(
              '¡Cita completada! 🎉',
              style: TextStyle(
                  color: Color(0xFF27AE60),
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _actualizando ? null : _marcarCompletado,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: _actualizando
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Text(
                'Marcar como Completado',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary),
              ),
      ),
    );
  }
}

// ==========================================
// PESTAÑA: RECUERDOS (Stream en tiempo real)
// ==========================================
class _PestanaRecuerdos extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  const _PestanaRecuerdos({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final recuerdos = snapshot.data ?? [];

        if (recuerdos.isEmpty) {
          return const Center(
            child: Text(
              'No hay recuerdos aún.\n¡Crea uno para guardar momentos! 💕',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return _construirMuroCollage(recuerdos);
      },
    );
  }

  List<String> _parseImages(String? urlField) {
    if (urlField == null || urlField.isEmpty) return [];
    if (urlField.startsWith('[') && urlField.endsWith(']')) {
      try {
        final List<dynamic> decoded = jsonDecode(urlField);
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return [urlField];
      }
    }
    return [urlField];
  }

  Widget _construirMuroCollage(List<Map<String, dynamic>> listaRecuerdos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: MasonryGridView.count(
        crossAxisCount: 2, // Dos columnas tipo Pinterest
        mainAxisSpacing: 12, // Espacio vertical entre fotos
        crossAxisSpacing: 12, // Espacio horizontal
        itemCount: listaRecuerdos.length,
        itemBuilder: (context, index) {
          final recuerdo = listaRecuerdos[index];
          
          return GestureDetector(
            onTap: () {
              // Al tocar, abrimos la pantalla de detalle con una transición fluida
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PantallaDetalleRecuerdo(recuerdo: recuerdo),
                ),
              );
            },
            // Hero es lo que hace que la foto "vuele" hacia la siguiente pantalla
            child: Hero(
              tag: 'foto_${recuerdo['id']}', 
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 1. La Imagen (Toma su tamaño natural, creando el efecto asimétrico)
                    CachedNetworkImage(
                      imageUrl: _parseImages(recuerdo['imagen_url']).isNotEmpty
                          ? SupabaseConfig.imagenOptimizada(_parseImages(recuerdo['imagen_url']).first, width: 600, quality: 80)
                          : '',
                      fit: BoxFit.cover,
                      // Un pequeño placeholder mientras carga el internet
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A88))),
                      ),
                    ),
                    
                    // 2. El Degradado Oscuro (Para que las letras blancas siempre se lean)
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        ),
                      ),
                    ),

                    // 3. Título minimalista encima de la foto
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              recuerdo['titulo'] ?? 'Sin título',
                              style: const TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 14,
                                decoration: TextDecoration.none, // Quitamos la raya amarilla de Hero
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Estrellita discreta
                          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
                          const SizedBox(width: 2),
                          Text(
                            '${recuerdo['calificacion'] ?? 5}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, decoration: TextDecoration.none),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SeccionLabel extends StatelessWidget {
  final String texto;
  const _SeccionLabel({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        texto.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: const Color(0xFFBBBBBB),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onCompletado;

  static const _rosa = Color(0xFFFF6A88);
  static const _negro = Color(0xFF1C1917);

  const _HeroCard({required this.plan, required this.onCompletado});

  String _diasRestantes() {
    final fechaStr = plan['fecha_exacta'] as String?;
    if (fechaStr == null) return '';
    final fecha = DateTime.tryParse(fechaStr);
    if (fecha == null) return '';
    final diff = fecha.difference(DateTime.now()).inDays;
    if (diff == 0) return '¡Hoy!';
    if (diff == 1) return 'Mañana';
    if (diff < 30) return 'En $diff días';
    final meses = (diff / 30).round();
    return 'En $meses ${meses == 1 ? 'mes' : 'meses'}';
  }

  String _formatearFecha() {
    final fechaStr = plan['fecha_texto'] as String?;
    return fechaStr ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _negro,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          // Glow decorativo
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _rosa.withAlpha(30),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    plan['icono'] ?? '📅',
                    style: const TextStyle(fontSize: 32),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _rosa.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _rosa.withAlpha(80), width: 0.5),
                    ),
                    child: Text(
                      _diasRestantes(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _rosa,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                plan['titulo'] ?? '',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              if (plan['descripcion'] != null &&
                  plan['descripcion'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  plan['descripcion'],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withAlpha(100),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatearFecha(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white.withAlpha(100),
                      letterSpacing: 0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: onCompletado,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _rosa,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '✓  Completado',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onCompletado;

  static const _negro = Color(0xFF1C1917);
  static const _linea = Color(0xFFE8E8E8);

  const _PlanCard({required this.plan, required this.onCompletado});

  String _diasRestantes() {
    final fechaStr = plan['fecha_exacta'] as String?;
    if (fechaStr == null) return '';
    final fecha = DateTime.tryParse(fechaStr);
    if (fecha == null) return '';
    final diff = fecha.difference(DateTime.now()).inDays;
    if (diff == 0) return '¡Hoy!';
    if (diff == 1) return 'Mañana';
    if (diff < 30) return 'En $diff días';
    final meses = (diff / 30).round();
    return 'En $meses ${meses == 1 ? 'mes' : 'meses'}';
  }

  String _dia() {
    final fechaStr = plan['fecha_exacta'] as String?;
    if (fechaStr == null) return '';
    return '${DateTime.tryParse(fechaStr)?.day ?? ''}';
  }

  String _mes() {
    final fechaStr = plan['fecha_exacta'] as String?;
    if (fechaStr == null) return '';
    final fecha = DateTime.tryParse(fechaStr);
    if (fecha == null) return '';
    const m = ['Ene','Feb','Mar','Abr','May','Jun',
                'Jul','Ago','Sep','Oct','Nov','Dic'];
    return m[fecha.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEB), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna de fecha
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Text(
                  _dia(),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _negro,
                    height: 1,
                  ),
                ),
                Text(
                  _mes().toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: const Color(0xFFBBBBBB),
                  ),
                ),
              ],
            ),
          ),

          // Divisor
          Container(
            width: 0.5,
            height: 60,
            color: _linea,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),

          // Contenido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan['titulo'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _negro,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _diasRestantes(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: const Color(0xFFAAAAAA),
                        ),
                      ),
                    ),
                  ],
                ),
                if (plan['descripcion'] != null &&
                    plan['descripcion'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    plan['descripcion'],
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFFAAAAAA),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onCompletado,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFE8E8E8), width: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Marcar como completado',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFBBBBBB),
                      ),
                    ),
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
