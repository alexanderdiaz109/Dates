import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/enviar_notificacion.dart';
import '../core/location_service.dart';
import '../core/supabase_config.dart';
import 'visor_imagen_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  late final Stream<List<Map<String, dynamic>>> _wishlistStream;

  // Ubicaciones
  LatLng? _miUbicacion;
  LatLng? _ubicacionPareja;
  bool _mapaAjustadoInicial = false;

  void _ajustarMapaAmbos() {
    if (_miUbicacion != null && _ubicacionPareja != null) {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([_miUbicacion!, _ubicacionPareja!]),
        padding: const EdgeInsets.all(60.0),
      ));
    }
  }

  // Filtro oscuro para mapas claros (invierte colores, el texto negro se vuelve blanco)
  static const ColorFilter _mapDarkFilter = ColorFilter.matrix([
    -1.0,  0.0,  0.0, 0.0, 255.0,
     0.0, -1.0,  0.0, 0.0, 255.0,
     0.0,  0.0, -1.0, 0.0, 255.0,
     0.0,  0.0,  0.0, 1.0,   0.0,
  ]);

  // Animación del pulso
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Preferencia del mapa
  bool _isDarkMode = true;

  // Centro inicial: Mérida, Yucatán
  static const _centroInicial = LatLng(20.9674, -89.5926);

  @override
  void initState() {
    super.initState();
    _wishlistStream = _supabase
        .from('destinos_wishlist')
        .stream(primaryKey: ['id']).order('creado_en', ascending: false);

    _escucharMapaOscuro();

    // Animación pulsante para los puntos de ubicación
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _iniciarRastreo();
  }

  Future<void> _escucharMapaOscuro() async {
    final parejaId = SupabaseConfig.parejaId;
    if (parejaId == null || !mounted) return;

    _supabase
        .from('parejas')
        .stream(primaryKey: ['id'])
        .eq('id', parejaId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            setState(() {
              _isDarkMode = data.first['mapa_oscuro'] as bool? ?? true;
            });
          }
        });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    LocationService.detener();
    super.dispose();
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

  // ── GPS & Rastreo ──────────────────────────────────────────────────────────
  Future<void> _iniciarRastreo() async {
    await LocationService.iniciar(
      onMiUbicacion: (p) {
        if (!mounted) return;
        setState(() {
          _miUbicacion = p;
          if (!_mapaAjustadoInicial && _ubicacionPareja != null) {
            _mapaAjustadoInicial = true;
            Future.delayed(const Duration(milliseconds: 500), _ajustarMapaAmbos);
          }
        });
      },
      onUbicacionPareja: (p) {
        if (!mounted) return;
        setState(() {
          _ubicacionPareja = p;
          if (!_mapaAjustadoInicial && _miUbicacion != null) {
            _mapaAjustadoInicial = true;
            Future.delayed(const Duration(milliseconds: 500), _ajustarMapaAmbos);
          }
        });
      },
    );
  }

  Future<void> _eliminarDestino(String id) async {
    try {
      await _supabase.from('destinos_wishlist').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[400]),
        );
      }
    }
  }

  void _confirmarEliminar(String id, String titulo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar deseo?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que quieres borrar "$titulo" de la lista?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eliminarDestino(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _marcarComoConquistado(String id, String titulo) async {
    PermissionStatus status;
    if (await Permission.photos.isGranted) {
      status = PermissionStatus.granted;
    } else {
      status = await Permission.photos.request();
      if (status.isDenied) status = await Permission.storage.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso denegado. Ve a Ajustes → Permisos → Galería.')),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final fotos = await picker.pickMultiImage(
      imageQuality: 70,
      requestFullMetadata: false,
    );

    if (fotos.isEmpty) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      List<String> urlsPublicas = [];
      for (var foto in fotos) {
        final archivo = File(foto.path);
        final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}_${urlsPublicas.length}.jpg';

        await _supabase.storage.from('recuerdos').upload(
          nombreArchivo,
          archivo,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        final urlPublica = _supabase.storage.from('recuerdos').getPublicUrl(nombreArchivo);
        urlsPublicas.add(urlPublica);
      }

      final imagenUrlFinal = urlsPublicas.length == 1 ? urlsPublicas.first : jsonEncode(urlsPublicas);

      await _supabase.from('destinos_wishlist').update({
        'estado': 'Conquistado',
        'imagen_url': imagenUrlFinal,
      }).eq('id', id);

      EnviarNotificacion.enviarAPareja(
        '¡Un deseo cumplido! ✈️',
        'Acabamos de conquistar: $titulo',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Sello de Conquistado agregado! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e')),
        );
      }
    }
  }

  // ── Abre el bottom sheet de detalle de un destino ──────────────────────────
  void _mostrarDetalleDestino(Map<String, dynamic> destino) {
    final bool conquistado = destino['estado'] == 'Conquistado';
    final List<String> imagenes = _parseImages(destino['imagen_url']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.6))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle flotante estilizado
                Center(
                  child: Container(
                    width: 48, height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[400]?.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Galería
                if (conquistado && imagenes.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imagenes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, idx) {
                        final imgUrl = imagenes[idx];
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => VisorImagenScreen(urlImagen: imgUrl, titulo: destino['titulo'] ?? ''),
                          )),
                          child: Hero(
                            tag: imgUrl,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: imagenes.length > 1 ? MediaQuery.of(context).size.width * 0.75 : MediaQuery.of(context).size.width - 48,
                                decoration: const BoxDecoration(
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                                ),
                                child: CachedNetworkImage(imageUrl: SupabaseConfig.imagenOptimizada(imgUrl, width: 600, quality: 80), fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (conquistado && imagenes.isNotEmpty) const SizedBox(height: 24),

                // Título y estado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        destino['titulo'] ?? '',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.5, height: 1.1),
                      ),
                    ),
                    if (conquistado)
                      Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Conquistado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                  ],
                ),

                if ((destino['descripcion'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded, color: Colors.grey[400], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            destino['descripcion'],
                            style: const TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Botones de acción
                if (!conquistado)
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [Color(0xFFFF4081), Color(0xFFFF79A1)]),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF4081).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded, size: 22),
                      label: const Text('¡Lo Conquistamos!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _marcarComoConquistado(destino['id'].toString(), destino['titulo']);
                      },
                    ),
                  ),

                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const Text('Eliminar deseo', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmarEliminar(destino['id'].toString(), destino['titulo']);
                    },
                  ),
                ),
                const SafeArea(child: SizedBox(height: 8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Modal para agregar nuevo destino ───────────────────────────────────────
  void _abrirModalNuevoDestino() {
    final tituloController = TextEditingController();
    final descripcionController = TextEditingController();
    final miniMapController = MapController();
    final searchController = TextEditingController();
    List<dynamic> searchResults = [];
    bool isSearching = false;
    LatLng? ubicacionSeleccionada;
    bool guardando = false;

    Future<void> buscarLugarModal(String query, void Function(void Function()) setModalState) async {
      if (query.isEmpty) {
        setModalState(() => searchResults = []);
        return;
      }
      setModalState(() => isSearching = true);
      try {
        final searchQuery = query.toLowerCase().contains('merida') || query.toLowerCase().contains('yucatan')
            ? query : '$query, Mérida';
        final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(searchQuery)}&format=json&limit=5');
        final response = await http.get(url, headers: {'User-Agent': 'com.dates.app'});
        if (response.statusCode == 200) {
          setModalState(() {
            searchResults = jsonDecode(response.body);
            isSearching = false;
          });
        } else {
          setModalState(() => isSearching = false);
        }
      } catch (_) {
        setModalState(() => isSearching = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.90,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Nuevo Deseo 🗺️', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Toca el mapa o busca un lugar', style: TextStyle(fontSize: 13, color: Color(0xFF95A5A6))),
                ),
                const SizedBox(height: 12),

                // Buscador
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar un lugar o parque...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: isSearching 
                          ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2)))
                          : IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                searchController.clear();
                                setModalState(() => searchResults = []);
                                FocusScope.of(context).unfocus();
                              },
                            ),
                    ),
                    onSubmitted: (v) => buscarLugarModal(v, setModalState),
                  ),
                ),
                if (searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final res = searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Color(0xFFFF4081)),
                          title: Text(res['display_name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            final lat = double.parse(res['lat'].toString());
                            final lon = double.parse(res['lon'].toString());
                            final p = LatLng(lat, lon);
                            miniMapController.move(p, 16);
                            setModalState(() {
                              ubicacionSeleccionada = p;
                              searchResults = [];
                            });
                            searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),

                // Mini-mapa para seleccionar ubicación
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: miniMapController,
                        options: MapOptions(
                          initialCenter: _centroInicial,
                          initialZoom: 12,
                          onTap: (tapPosition, point) {
                            setModalState(() {
                              ubicacionSeleccionada = point;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.dates.app',
                            tileBuilder: (context, tileWidget, tile) => _isDarkMode 
                              ? ColorFiltered(colorFilter: _mapDarkFilter, child: tileWidget)
                              : tileWidget,
                          ),
                          if (ubicacionSeleccionada != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: ubicacionSeleccionada!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.favorite, color: Color(0xFFFF6A88), size: 36),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (ubicacionSeleccionada == null)
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.touch_app_rounded, size: 40, color: Colors.white),
                                  SizedBox(height: 8),
                                  Text(
                                    'Toca el mapa para\nmarcar el lugar',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),


                // Formulario
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24, right: 24, top: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                    children: [
                      TextField(
                        controller: tituloController,
                        decoration: InputDecoration(
                          labelText: 'Nombre del lugar o experiencia',
                          prefixIcon: const Icon(Icons.flight_takeoff_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descripcionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Detalles (opcional)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Indicador de ubicación seleccionada
                      if (ubicacionSeleccionada != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F8F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2ECC71)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: Color(0xFF27AE60), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ubicación marcada ✓  ${ubicacionSeleccionada!.latitude.toStringAsFixed(4)}, ${ubicacionSeleccionada!.longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF27AE60), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (guardando || tituloController.text.trim().isEmpty) ? null : () async {
                            setModalState(() => guardando = true);
                            try {
                              final pId = SupabaseConfig.parejaId ?? await SupabaseConfig.obtenerParejaId();
                              await _supabase.from('destinos_wishlist').insert({
                                'titulo': tituloController.text.trim(),
                                'descripcion': descripcionController.text.trim(),
                                'estado': 'Deseo',
                                'latitud': ubicacionSeleccionada?.latitude,
                                'longitud': ubicacionSeleccionada?.longitude,
                                'pareja_id': pId,
                                'usuario_id': SupabaseConfig.currentUserId,
                              });
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            } finally {
                              if (mounted) setModalState(() => guardando = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: guardando
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('GUARDAR EN LA LISTA', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    ),
                  ),
                ),

              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cardGradient(bool conquistado, int index) {
    final List<List<Color>> palettes = [
      [const Color(0xFFFF6A88), const Color(0xFFFF99AC)],
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      [const Color(0xFFf7971e), const Color(0xFFffd200)],
      [const Color(0xFFcb2d3e), const Color(0xFFef473a)],
      [const Color(0xFF4776E6), const Color(0xFF8E54E9)],
    ];
    final colors = conquistado
        ? [const Color(0xFFf7971e), const Color(0xFFffd200)]
        : palettes[index % palettes.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }

  // ── Panel inferior con la lista horizontal de destinos ─────────────────────
  Widget _buildPanelDestinos(List<Map<String, dynamic>> destinos) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.85),
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle drag
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 4, top: 2),
                  itemCount: destinos.length,
                  itemBuilder: (context, index) {
                    final d = destinos[index];
                    final bool conquistado = d['estado'] == 'Conquistado';
                    final bool tieneMapa = d['latitud'] != null && d['longitud'] != null;
                    final List<String> imgs = _parseImages(d['imagen_url']);
                    final String? firstImg = imgs.isNotEmpty ? imgs.first : null;

                    return GestureDetector(
                      onTap: () {
                        if (tieneMapa) {
                          _mapController.move(
                            LatLng((d['latitud'] as num).toDouble(), (d['longitud'] as num).toDouble()),
                            16,
                          );
                        }
                        _mostrarDetalleDestino(d);
                      },
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: conquistado
                                  ? const Color(0xFFFFD700).withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Fondo: foto si existe o gradiente bonito
                              if (firstImg != null)
                                CachedNetworkImage(
                                  imageUrl: SupabaseConfig.imagenOptimizada(firstImg, width: 200, quality: 70),
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 200),
                                  placeholder: (_, __) => _cardGradient(conquistado, index),
                                  errorWidget: (_, __, ___) => _cardGradient(conquistado, index),
                                )
                              else
                                _cardGradient(conquistado, index),

                              // Overlay oscuro para legibilidad
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.75),
                                    ],
                                    stops: const [0.3, 1.0],
                                  ),
                                ),
                              ),

                              // Número de posición (top-left)
                              Positioned(
                                top: 8,
                                left: 10,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                                  ),
                                ),
                              ),

                              // Badge conquistado (top-right)
                              if (conquistado)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '⭐ ¡Listo!',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50)),
                                    ),
                                  ),
                                ),

                              // Nombre del lugar (bottom)
                              Positioned(
                                bottom: 10,
                                left: 10,
                                right: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      d['titulo'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Colors.white,
                                        height: 1.2,
                                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                      ),
                                    ),
                                    if (tieneMapa)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.location_on_rounded, color: Colors.white70, size: 10),
                                            const SizedBox(width: 2),
                                            Text(
                                              'En el mapa',
                                              style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.75)),
                                            ),
                                          ],
                                        ),
                                      ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _wishlistStream,
      builder: (context, snapshot) {
        final destinos = snapshot.data ?? [];

          // Separar los que tienen coordenadas
          final destinosConMapa = destinos
              .where((d) => d['latitud'] != null && d['longitud'] != null)
              .toList();

          // Construir marcadores para el mapa
          final marcadores = destinosConMapa.map((d) {
            final bool conquistado = d['estado'] == 'Conquistado';
            final Color glowColor = conquistado ? const Color(0xFFFFD700) : const Color(0xFFFF4B72);

            return Marker(
              point: LatLng(
                (d['latitud'] as num).toDouble(),
                (d['longitud'] as num).toDouble(),
              ),
              width: 64,
              height: 64,
              child: GestureDetector(
                onTap: () => _mostrarDetalleDestino(d),
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  // El pin y el ícono interior no dependen del valor animado:
                  // se construyen una sola vez y se reutilizan en cada frame del pulso.
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // El pin
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: conquistado
                              ? [const Color(0xFFFFE566), const Color(0xFFFFA500)]
                              : [const Color(0xFFFF8FAE), const Color(0xFFFF1744)],
                        ).createShader(bounds),
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 56,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: glowColor.withValues(alpha: 0.9),
                              blurRadius: 18,
                              offset: Offset.zero,
                            ),
                            Shadow(
                              color: glowColor.withValues(alpha: 0.6),
                              blurRadius: 30,
                              offset: Offset.zero,
                            ),
                          ],
                        ),
                      ),
                      // Ícono interior
                      Positioned(
                        top: 6,
                        child: Icon(
                          conquistado ? Icons.star_rounded : Icons.favorite_rounded,
                          size: 20,
                          color: Colors.white,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
                        ),
                      ),
                    ],
                  ),
                  builder: (_, pin) {
                    final glow = _pulseAnim.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Halo de brillo exterior pulsante
                        Container(
                          width: 48 * glow,
                          height: 48 * glow,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.55 * glow),
                                blurRadius: 20,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        pin!,
                      ],
                    );
                  },
                ),
              ),
            );
          }).toList();

          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _abrirModalNuevoDestino,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Agregar Deseo', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            bottomSheet: destinos.isNotEmpty ? _buildPanelDestinos(destinos) : null,
            body: Stack(
            children: [
              // ── EL MAPA OCUPA TODA LA PANTALLA ──────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _miUbicacion ?? _centroInicial,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.dates.app',
                    tileBuilder: (context, tileWidget, tile) => _isDarkMode 
                      ? ColorFiltered(colorFilter: _mapDarkFilter, child: tileWidget)
                      : tileWidget,
                  ),
                  MarkerLayer(markers: marcadores),
                  // Marcadores de ubicación
                  MarkerLayer(
                    markers: [
                      if (_ubicacionPareja != null)
                        Marker(
                          point: _ubicacionPareja!,
                          width: 60,
                          height: 60,
                          child: AnimatedBuilder(
                            animation: _pulseAnim,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFF4081),
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                              ),
                            ),
                            builder: (_, dot) => Stack(
                              alignment: Alignment.center,
                              children: [
                                // Anillo pulsante
                                Container(
                                  width: 50 * _pulseAnim.value,
                                  height: 50 * _pulseAnim.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFF4081).withValues(alpha: 0.3 * (1 - _pulseAnim.value + 0.3)),
                                  ),
                                ),
                                dot!,
                              ],
                            ),
                          ),
                        ),
                      if (_miUbicacion != null)
                        Marker(
                          point: _miUbicacion!,
                          width: 60,
                          height: 60,
                          child: AnimatedBuilder(
                            animation: _pulseAnim,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF2196F3),
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                              ),
                            ),
                            builder: (_, dot) => Stack(
                              alignment: Alignment.center,
                              children: [
                                // Anillo pulsante azul
                                Container(
                                  width: 50 * _pulseAnim.value,
                                  height: 50 * _pulseAnim.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF2196F3).withValues(alpha: 0.3 * (1 - _pulseAnim.value + 0.3)),
                                  ),
                                ),
                                dot!,
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // ── APPBAR FLOTANTE ENCIMA DEL MAPA ─────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón atrás y Título
                        Row(
                          children: [
                            // Botón atrás
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C3E50)),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Título flotante
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                                    ),
                                    child: const Text(
                                      'Nuestra Bucket List 🗺️',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2C3E50)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── LEYENDA DE UBICACIONES (derecha) ────────────────────────
              if (_miUbicacion != null || _ubicacionPareja != null)
                Positioned(
                  right: 16,
                  top: MediaQuery.of(context).padding.top + 70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_miUbicacion != null)
                              GestureDetector(
                                onTap: () => _mapController.move(_miUbicacion!, 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 12, height: 12,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2196F3)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Yo', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            if (_miUbicacion != null && _ubicacionPareja != null) const SizedBox(height: 8),
                            if (_ubicacionPareja != null)
                              GestureDetector(
                                onTap: () => _mapController.move(_ubicacionPareja!, 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 12, height: 12,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF4081)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Mi amor', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            if (_miUbicacion != null && _ubicacionPareja != null) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _ajustarMapaAmbos,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 12, height: 12,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amber),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Ambos', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),


              // Loading overlay
              if (snapshot.connectionState == ConnectionState.waiting && destinos.isEmpty)
                Container(
                  color: Colors.white.withValues(alpha: 0.8),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}
