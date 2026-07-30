import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/background_location_service.dart';
import '../core/location_service.dart';

class UbicacionVivoScreen extends StatefulWidget {
  const UbicacionVivoScreen({super.key});

  @override
  State<UbicacionVivoScreen> createState() => _UbicacionVivoScreenState();
}

class _UbicacionVivoScreenState extends State<UbicacionVivoScreen> {
  bool _activado = false;
  bool _cargando = false;
  LatLng? _miUbicacion;
  LatLng? _ubicacionPareja;
  DateTime? _ultimaActualizacionPareja;

  static const _centroInicial = LatLng(20.9674, -89.5926);

  @override
  void initState() {
    super.initState();
    _revisarEstadoReal();
  }

  Future<void> _revisarEstadoReal() async {
    final corriendo = await FlutterBackgroundService().isRunning();
    if (mounted) setState(() => _activado = corriendo);
  }

  Future<void> _toggle(bool valor) async {
    if (valor) {
      setState(() => _cargando = true);

      // Android 13+ requiere permiso de notificaciones en tiempo de ejecución
      // antes de que el servicio foreground pueda mostrar su notificación.
      final notifStatus = await Permission.notification.request();
      if (!notifStatus.isGranted) {
        if (mounted) {
          setState(() => _cargando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Necesitas aceptar las notificaciones para activar el rastreo en segundo plano.'),
            ),
          );
        }
        return;
      }

      final ok = await LocationService.iniciar(
        onMiUbicacion: (p) {
          if (mounted) setState(() => _miUbicacion = p);
        },
        onUbicacionPareja: (p) {
          if (mounted) {
            setState(() {
              _ubicacionPareja = p;
              _ultimaActualizacionPareja = DateTime.now();
            });
          }
        },
      );
      if (ok) await BackgroundLocationService.iniciarServicio();

      setState(() {
        _activado = ok;
        _cargando = false;
      });
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo activar. Revisa los permisos de ubicación.')),
        );
      }
    } else {
      LocationService.detener();
      await BackgroundLocationService.detenerServicio();
      setState(() => _activado = false);
    }
  }

  String _formatoUltimaActualizacion() {
    if (_ultimaActualizacionPareja == null) return 'Sin datos aún';
    final diff = DateTime.now().difference(_ultimaActualizacionPareja!);
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    return 'hace ${diff.inHours} h';
  }

  @override
  void dispose() {
    // No detenemos LocationService aquí a propósito:
    // si el usuario activó el rastreo, debe seguir aunque salga de esta pantalla.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Ubicación en Vivo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Activar Ubicación en Vivo',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  _cargando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Switch(value: _activado, onChanged: _toggle, activeThumbColor: primary),
                ],
              ),
            ),
          ),

          if (_activado) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue)),
                      const SizedBox(width: 6),
                      const Text('Yo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF4081))),
                      const SizedBox(width: 6),
                      Text('Mi pareja · ${_formatoUltimaActualizacion()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _miUbicacion ?? _centroInicial,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.dates.app',
                      ),
                      MarkerLayer(markers: [
                        if (_miUbicacion != null)
                          Marker(
                            point: _miUbicacion!,
                            width: 40, height: 40,
                            child: const Icon(Icons.circle, color: Colors.blue, size: 20),
                          ),
                        if (_ubicacionPareja != null)
                          Marker(
                            point: _ubicacionPareja!,
                            width: 40, height: 40,
                            child: const Icon(Icons.circle, color: Color(0xFFFF4081), size: 20),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ] else
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Activa el interruptor para compartir tu ubicación en tiempo real con tu pareja 💛',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
