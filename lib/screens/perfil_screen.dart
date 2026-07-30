import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/calendario_visual_widget.dart';
import 'vista_previa_compartir.dart';
import 'historial_planes_screen.dart';
import 'ubicacion_vivo_screen.dart';
import '../core/supabase_config.dart';
import '../core/temporada_service.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _supabase = Supabase.instance.client;
  bool _alertasActivadas = true;
  bool _subiendoFoto = false;

  Stream<List<Map<String, dynamic>>>? _configStream;

  @override
  void initState() {
    super.initState();
    final parejaId = SupabaseConfig.parejaId;
    _configStream = parejaId == null
        ? const Stream.empty()
        : _supabase.from('parejas').stream(primaryKey: ['id']).eq('id', parejaId);
  }

  // ── CAMBIAR FOTO ──────────────────────────────────────────────
  Future<void> _cambiarFoto() async {
    // Solicitar permiso (necesario en MIUI)
    PermissionStatus status = await Permission.photos.request();
    if (status.isDenied) status = await Permission.storage.request();
    if (status.isPermanentlyDenied) {
      if (mounted) await openAppSettings();
      return;
    }
    if (status.isDenied) return;

    final picker = ImagePicker();
    final foto = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      requestFullMetadata: false,
    );
    if (foto == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final archivo = File(foto.path);
      final nombre =
          'perfil/pareja_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('recuerdos').upload(
            nombre,
            archivo,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final url =
          _supabase.storage.from('recuerdos').getPublicUrl(nombre);

      if (SupabaseConfig.parejaId == null) return;
      await _supabase
          .from('parejas')
          .update({'foto_url': url}).eq('id', SupabaseConfig.parejaId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Foto actualizada! 📸')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir foto: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  // ── EDITAR NOMBRES ────────────────────────────────────────────
  void _editarNombres(String nombresActuales) {
    final ctrl = TextEditingController(text: nombresActuales);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalEdicion(
        titulo: 'Nombres de la pareja',
        icono: Icons.people_rounded,
        child: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Ej. Los nombres de nosotros',
            prefixIcon: const Icon(Icons.people_rounded),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        onGuardar: () async {
          if (ctrl.text.trim().isEmpty) return;
          if (SupabaseConfig.parejaId == null) return;
          await _supabase.from('parejas').update({
            'nombres_pareja': ctrl.text.trim(),
          }).eq('id', SupabaseConfig.parejaId!);
        },
      ),
    );
  }

  // ── SELECCIONAR FECHA DE INICIO / ANIVERSARIO ─────────────────
  Future<void> _seleccionarFechaInicio(BuildContext context) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      helpText: 'FECHA DE INICIO DE RELACIÓN',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
              primary: Theme.of(ctx).colorScheme.primary),
        ),
        child: child!,
      ),
    );

    if (fecha != null && mounted) {
      try {
        if (SupabaseConfig.parejaId == null) return;
        await _supabase.from('parejas').update({
          'fecha_aniversario': fecha.toIso8601String().split('T')[0],
        }).eq('id', SupabaseConfig.parejaId!);

        if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('¡Fecha guardada! El contador se actualizó ☁️')),
          );
        }
      } catch (e) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red[400]),
          );
        }
      }
    }
  }

  // ── MODAL NOTIFICACIONES ──────────────────────────────────────
  void _mostrarNotificaciones() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notificaciones',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50))),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Alertas de "Te Extraño"'),
                subtitle: const Text(
                    'Si se apaga, solo verás los avisos al abrir la app.'),
                value: _alertasActivadas,
                activeThumbColor: Theme.of(ctx).colorScheme.primary,
                onChanged: (v) {
                  setModalState(() => _alertasActivadas = v);
                  setState(() => _alertasActivadas = v);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('LISTO',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_configStream == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _configStream,
      builder: (context, snap) {
        final config =
            (snap.hasData && snap.data!.isNotEmpty) ? snap.data!.first : null;

        final nombres =
            config?['nombres_pareja'] as String? ?? '....';
        final fotoUrl = config?['foto_url'] as String? ??
            'https://images.unsplash.com/photo-1518199266791-5375a83190b7?q=80&w=400&auto=format&fit=crop';
        final String tema = config?['tema'] as String? ?? 'classic';
        final String nextTema = tema == 'classic' ? 'dark' : tema == 'dark' ? 'oled' : 'classic';
        final String temaLabel = tema == 'classic' ? ' Clásico ' : tema == 'dark' ? ' Oscuro ' : ' Oled';

        // Formatear fecha para mostrar en el menú
        String textoFecha = 'Toca para configurar';
        if (config?['fecha_aniversario'] != null) {
          try {
            final partes =
                (config!['fecha_aniversario'] as String).split('-');
            final dia = partes[2];
            final mes = partes[1];
            final anio = partes[0];
            const nombreMes = [
              '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo',
              'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre',
              'Noviembre', 'Diciembre'
            ];
            textoFecha =
                '$dia de ${nombreMes[int.parse(mes)]} de $anio';
          } catch (_) {}
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // ── FOTO (tap para cambiar) ───────────────────
                GestureDetector(
                  onTap: _cambiarFoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 24,
                                offset: const Offset(0, 12)),
                            BoxShadow(
                                color: primary.withAlpha(40),
                                blurRadius: 32,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 64,
                          backgroundColor: const Color(0xFFBDC3C7),
                          backgroundImage: CachedNetworkImageProvider(
                            SupabaseConfig.imagenOptimizada(fotoUrl, width: 200, quality: 70),
                          ),
                        ),
                      ),
                      if (_subiendoFoto)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black38,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      // Botón de cámara
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── NOMBRES (tap para editar) ─────────────────
                GestureDetector(
                  onTap: () => _editarNombres(nombres),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nombres,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit_rounded,
                          size: 18, color: Colors.grey[400]),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ── PÍLDORA Y BOTÓN COMPARTIR ───────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 16, color: primary),
                          const SizedBox(width: 8),
                          Text(
                            'Espacio Privado Compartido',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6A88).withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.ios_share_rounded, size: 16, color: Color(0xFFFF6A88)),
                        onPressed: () async {
                          // 1. Calcular días juntos
                          int diasJuntosCalc = 0;
                          final fechaAnivString = config?['fecha_aniversario'] as String?;
                          if (fechaAnivString != null && fechaAnivString.isNotEmpty) {
                            try {
                              final parts = fechaAnivString.split('-');
                              final fecha = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                              diasJuntosCalc = DateTime.now().difference(fecha).inDays;
                            } catch (_) {}
                          }

                          // 2. Contar citas completadas en Supabase (estado == 'Completado')
                          int citasCompletadasCalc = 0;
                          try {
                            final res = await Supabase.instance.client
                                .from('planes')
                                .select('id')
                                .eq('estado', 'Completado');
                            citasCompletadasCalc = (res as List).length;
                          } catch (_) {}

                          if (!context.mounted) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VistaCompartirScreen(
                                nombrePareja: nombres,
                                diasJuntos: diasJuntosCalc,
                                totalPlanes: citasCompletadasCalc,
                                fotoUrl: fotoUrl,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Nuestra Agenda Visual', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: CalendarioVisualWidget(),
                ),

                const SizedBox(height: 40),

                // ── MENÚ (solo 3 opciones funcionales) ────────
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).dividerColor.withAlpha(80)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildMenuOption(
                        context,
                        icon: Icons.notifications_active_rounded,
                        title: 'Notificaciones',
                        subtitle: 'Ajustar alertas en ambos equipos',
                        isFirst: true,
                        onTap: _mostrarNotificaciones,
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        context,
                        icon: Icons.people_rounded,
                        title: 'Nombres de la pareja',
                        subtitle: nombres,
                        onTap: () => _editarNombres(nombres),
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        context,
                        icon: Icons.favorite_rounded,
                        title: 'Fecha de inicio / Aniversario',
                        subtitle: textoFecha,
                        onTap: () => _seleccionarFechaInicio(context),
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        context,
                        icon: Icons.palette_rounded,
                        title: 'Apariencia de la App',
                        subtitle: temaLabel,
                        onTap: () async {
                          try {
                            if (SupabaseConfig.parejaId == null) return;
                            await _supabase.from('parejas').update({'tema': nextTema}).eq('id', SupabaseConfig.parejaId!);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al cambiar el tema: $e. ¿Agregaste la columna "tema" tipo text en Supabase?'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        context,
                        icon: Icons.location_on_rounded,
                        title: 'Ubicación en Vivo',
                        subtitle: 'Ver dónde está tu pareja en tiempo real',
                        isLast: false,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const UbicacionVivoScreen()));
                        },
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        context,
                        icon: Icons.auto_awesome_rounded,
                        title: 'Decoración de temporada',
                        subtitle: config?['temporada_activa'] == true
                            ? '${TemporadaService.nombre(TemporadaService.detectar())} · Activa'
                            : 'Desactivada',
                        isLast: true,
                        onTap: () async {
                          final actual = config?['temporada_activa'] as bool? ?? true;
                          if (SupabaseConfig.parejaId == null) return;
                          await _supabase
                              .from('parejas')
                              .update({'temporada_activa': !actual})
                              .eq('id', SupabaseConfig.parejaId!);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Botón de Historial de Planes
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HistorialPlanesScreen()));
                    },
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Ver Historial de Planes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2C3E50),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFEAEDED), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.logout_rounded,
                      color: Color(0xFF95A5A6)),
                  label: const Text(
                    'Desvincular este dispositivo',
                    style: TextStyle(
                        color: Color(0xFF95A5A6),
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool isFirst = false,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isFirst ? 24 : 0),
        bottom: Radius.circular(isLast ? 24 : 0),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: Theme.of(context).colorScheme.onSurface, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withAlpha(140)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).dividerColor.withAlpha(50),
        indent: 70,
        endIndent: 20);
  }
}

// ── WIDGET MODAL REUTILIZABLE ─────────────────────────────────────
class _ModalEdicion extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final Widget child;
  final Future<void> Function() onGuardar;

  const _ModalEdicion({
    required this.titulo,
    required this.icono,
    required this.child,
    required this.onGuardar,
  });

  @override
  State<_ModalEdicion> createState() => _ModalEdicionState();
}

class _ModalEdicionState extends State<_ModalEdicion> {
  bool _guardando = false;

  @override
  Widget build(BuildContext context) {
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
          // Indicador de arrastre
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE1E7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(widget.titulo,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 20),
          widget.child,
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _guardando
                  ? null
                  : () async {
                      setState(() => _guardando = true);
                      try {
                        await widget.onGuardar();
                        // ignore: use_build_context_synchronously
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'),
                                backgroundColor: Colors.red[400]),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _guardando = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _guardando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('GUARDAR',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
