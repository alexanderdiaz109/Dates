import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class CalendarioVisualWidget extends StatefulWidget {
  const CalendarioVisualWidget({super.key});

  @override
  State<CalendarioVisualWidget> createState() => _CalendarioVisualWidgetState();
}

class _CalendarioVisualWidgetState extends State<CalendarioVisualWidget> {
  CalendarFormat _formatoCalendario = CalendarFormat.month;
  DateTime _diaEnfocado = DateTime.now();
  DateTime? _diaSeleccionado;
  
  // Mapa donde guardaremos los días ocupados. Clave: El día puro, Valor: Lista de títulos
  Map<DateTime, List<String>> _eventosDelMes = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _diaSeleccionado = _diaEnfocado;
    _cargarEventosDeSupabase();
  }

  // Escanea Supabase para buscar qué días tienen planes agendados
  Future<void> _cargarEventosDeSupabase() async {
    try {
      final datos = await Supabase.instance.client
          .from('planes')
          .select('titulo, fecha_exacta')
          .not('fecha_exacta', 'is', null); // Solo los que tienen fecha matemática

      Map<DateTime, List<String>> mapaTemporal = {};

      for (var plan in datos) {
        if (plan['fecha_exacta'] != null) {
          DateTime fechaReal = DateTime.parse(plan['fecha_exacta']).toLocal();
          // Normalizamos la fecha a "año-mes-día" a medianoche para que coincida perfectamente con el calendario
          DateTime diaPuro = DateTime(fechaReal.year, fechaReal.month, fechaReal.day);

          if (mapaTemporal[diaPuro] == null) {
            mapaTemporal[diaPuro] = [];
          }
          mapaTemporal[diaPuro]!.add(plan['titulo'] as String);
        }
      }

      setState(() {
        _eventosDelMes = mapaTemporal;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error cargando eventos al calendario: $e');
      setState(() => _cargando = false);
    }
  }

  // Función que el calendario lee para saber si un día específico tiene eventos
  List<String> _obtenerEventosDelDia(DateTime day) {
    DateTime diaPuro = DateTime(day.year, day.month, day.day);
    return _eventosDelMes[diaPuro] ?? [];
  }

  // Función para abrir el modal y guardar directo en la tabla 'planes'
  void _abrirModalAgendar(DateTime diaSeleccionado) {
    final tituloController = TextEditingController();
    final descripcionController = TextEditingController();
    TimeOfDay horaSeleccionada = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Agendar para el ${diaSeleccionado.day}/${diaSeleccionado.month}/${diaSeleccionado.year}', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))
                ),
                const SizedBox(height: 20),
                
                TextField(
                  controller: tituloController, 
                  decoration: InputDecoration(labelText: '¿Qué se celebra o planea?', prefixIcon: const Icon(Icons.event), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))
                ),
                const SizedBox(height: 16),
                
                // Selector de hora
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  leading: const Icon(Icons.access_time, color: Color(0xFFFF6A88)),
                  title: const Text('Hora del evento'),
                  trailing: Text(horaSeleccionada.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onTap: () async {
                    final TimeOfDay? nuevaHora = await showTimePicker(context: context, initialTime: horaSeleccionada);
                    if (nuevaHora != null) {
                      setModalState(() => horaSeleccionada = nuevaHora);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                TextField(
                  controller: descripcionController, 
                  decoration: InputDecoration(labelText: 'Detalles (Opcional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6A88), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('GUARDAR EN AGENDA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      if (tituloController.text.isEmpty) return;

                      // Combinamos el día del calendario con la hora elegida
                      final fechaExacta = DateTime(diaSeleccionado.year, diaSeleccionado.month, diaSeleccionado.day, horaSeleccionada.hour, horaSeleccionada.minute);
                      
                      // Texto bonito para guardar
                      final minutos = horaSeleccionada.minute.toString().padLeft(2, '0');
                      final ampm = horaSeleccionada.period == DayPeriod.am ? 'AM' : 'PM';
                      int hora12 = horaSeleccionada.hour > 12 ? horaSeleccionada.hour - 12 : horaSeleccionada.hour;
                      if (hora12 == 0) hora12 = 12;

                      // Insertamos en tu tabla planes central
                      final pId = SupabaseConfig.parejaId ?? await SupabaseConfig.obtenerParejaId();
                      await Supabase.instance.client.from('planes').insert({
                        'titulo': tituloController.text.trim(),
                        'fecha_texto': '${diaSeleccionado.day}/${diaSeleccionado.month}/${diaSeleccionado.year} a las $hora12:$minutos $ampm',
                        'fecha_exacta': fechaExacta.toIso8601String(), // Esto hace que el puntito aparezca
                        'descripcion': descripcionController.text.trim(),
                        'estado': 'Planeado',
                        'pareja_id': pId,
                        'usuario_id': SupabaseConfig.currentUserId,
                      });

                      if (context.mounted) Navigator.pop(context); // Cerramos modal
                      _cargarEventosDeSupabase(); // Refrescamos los puntitos del calendario
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Obtenemos los eventos específicos del día que el usuario toque
    final eventosSeleccionados = _obtenerEventosDelDia(_diaSeleccionado!);

    return Column(
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: TableCalendar(
            firstDay: DateTime.utc(2025, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _diaEnfocado,
            calendarFormat: _formatoCalendario,
            selectedDayPredicate: (day) => isSameDay(_diaSeleccionado, day),
            eventLoader: _obtenerEventosDelDia, // Mapea los puntitos debajo del número
            
            // Evento al tocar un día
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _diaSeleccionado = selectedDay;
                _diaEnfocado = focusedDay;
              });
            },
            
            // Cambiar entre vista de Mes / Semana
            onFormatChanged: (format) {
              setState(() {
                _formatoCalendario = format;
              });
            },

            // Estilos estéticos personalizados (Combina con los colores de tu app)
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary, // Círculo coral al seleccionar
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFFE67E22), // Color de los puntitos de evento
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3, // Máximo 3 puntitos por día para no saturar
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // NUEVO: Encabezado con el botón de agregar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Agenda del ${_diaSeleccionado!.day}/${_diaSeleccionado!.month}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50)),
              ),
              IconButton(
                onPressed: () => _abrirModalAgendar(_diaSeleccionado!),
                icon: const Icon(Icons.add_circle_rounded, color: Color(0xFFFF6A88), size: 30),
              )
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Lista desplegable inferior que muestra qué hay agendado el día seleccionado
        if (eventosSeleccionados.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: eventosSeleccionados.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: Color(0xFFE67E22), width: 4)),
                ),
                child: Text(
                  eventosSeleccionados[index],
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
              );
            },
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No hay planes para este día. ✨', style: TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }
}
