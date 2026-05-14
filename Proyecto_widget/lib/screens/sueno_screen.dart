import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import '../providers/dashboard_provider.dart';
import '../models/biomarker.dart';
import '../utils/app_colors.dart';

const Color _bg      = AppColors.bgScreen;
const Color _surface = AppColors.bgCard;
const Color _text    = AppColors.textPrimary;
const Color _muted   = AppColors.textSecondary;
const Color _border  = AppColors.border;

const Color _suenoColor = Color(0xFF3B82F6); 

// Midnight Analysis Palette
const Color _deepSleep  = Color(0xFF312E81); // Indigo Oscuro
const Color _lightSleep = Color(0xFF818CF8); // Lavanda
const Color _awake      = Color(0xFFFDE68A); // Ambar suave

// Posture Palette (Clinical Labels: Sitting, Standing, Left, Right, Top, Bottom, Misc)
const Color _posLeft     = Color(0xFF6366F1); // Indigo 500
const Color _posRight    = Color(0xFF818CF8); // Indigo 400
const Color _posTop      = Color(0xFFA5B4FC); // Indigo 300
const Color _posBottom   = Color(0xFFC7D2FE); // Indigo 200
const Color _posSitting  = Color(0xFF38BDF8); // Sky Blue 400 (Tranquilo)
const Color _posStanding = Color(0xFFF97316); // Orange 500 (Activo)
const Color _posMisc     = Color(0xFFE2E8F0); // Slate 200

class SuenoScreen extends StatefulWidget {
  final String participantId;
  final String username;
  const SuenoScreen({super.key, required this.participantId, required this.username});

  @override
  State<SuenoScreen> createState() => _SuenoScreenState();
}

class _SuenoScreenState extends State<SuenoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchSuenoMetrics(widget.participantId, widget.username);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        if (provider.isSuenoLoading) {
          return const Center(child: CircularProgressIndicator(color: _suenoColor));
        }

        final byType = <String, List<Biomarker>>{};
        for (var m in provider.suenoMetrics) {
          final type = m.sensorType.toLowerCase().replaceAll('-', '_');
          byType.putIfAbsent(type, () => []).add(m);
        }

        final sleepDetData = byType['sleep_detection'] ?? [];
        final sleepStgData = byType['sleep_stages'] ?? [];
        final posData      = byType['body_position'] ?? [];

        // Evaluar Higiene Circadiana (Toque de excelencia)
        // Simulamos la evaluación calculando si la eficiencia es alta
        bool hasGoodHygiene = false;
        if (sleepDetData.isNotEmpty) {
          int sleepMins = sleepDetData.where((e) => e.value != null && e.value! > 0).length;
          double efficiency = (sleepMins / sleepDetData.length) * 100;
          if (efficiency > 85) hasGoodHygiene = true;
        }

        final listSections = [
          if (sleepDetData.isEmpty && sleepStgData.isEmpty && posData.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                child: Text('Sin datos fisiológicos en el tramo seleccionado', style: GoogleFonts.inter(color: _muted)),
              ),
            )
          else ...[
            _KPIsLayer(sleepData: sleepDetData, posData: posData),
            const SizedBox(height: 24),
            _HipnogramaLayer(sleepData: sleepDetData, stagesData: sleepStgData),
            const SizedBox(height: 24),
            _GanttPosturalLayer(posData: posData, sleepData: sleepDetData),
          ]
        ];

        return Column(
          children: [
            _ControlPanel(
              provider: provider, 
              participantId: widget.participantId, 
              username: widget.username,
              hasGoodHygiene: hasGoodHygiene,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final isLaptop = constraints.maxWidth > 1100;
                  final padding  = isMobile ? 12.0 : (constraints.maxWidth > 720 ? 24.0 : 16.0);

                  if (isLaptop && listSections.length >= 5) {
                    return ListView(
                      padding: EdgeInsets.all(padding),
                      children: [
                        listSections[0], // KPIs
                        const SizedBox(height: 24),
                        listSections[2], // Hipnograma
                        const SizedBox(height: 24),
                        listSections[4], // Gantt
                      ],
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.all(padding),
                    children: listSections,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final DashboardProvider provider;
  final String participantId;
  final String username;
  final bool hasGoodHygiene;

  const _ControlPanel({
    required this.provider, 
    required this.participantId, 
    required this.username,
    required this.hasGoodHygiene,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 12),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final isSmall = c.maxWidth < 450;
              final headerIcon = Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _suenoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.moon, size: 16, color: _suenoColor),
              );
              final headerTitle = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arquitectura del Sueño e Higiene Postural',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _text),
                  ),
                  Text(
                    'Evaluación de ciclos de descanso, fragmentación del sueño y alineación corporal nocturna.',
                    style: GoogleFonts.inter(fontSize: 11, color: _muted),
                  ),
                ],
              );
              
              final badges = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (hasGoodHygiene)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.award, size: 11, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            'Higiene Circadiana Óptima',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  if (provider.suenoResolucion.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _suenoColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _suenoColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.gauge, size: 11, color: _suenoColor),
                          const SizedBox(width: 6),
                          Text(
                            provider.suenoResolucion,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: _suenoColor),
                          ),
                        ],
                      ),
                    ),
                ],
              );

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        headerIcon,
                        const SizedBox(width: 12),
                        Expanded(child: headerTitle),
                      ],
                    ),
                    const SizedBox(height: 12),
                    badges,
                  ],
                );
              }

              return Row(
                children: [
                  headerIcon,
                  const SizedBox(width: 12),
                  Expanded(child: headerTitle),
                  const SizedBox(width: 12),
                  badges,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _TimeRangeSelector(provider: provider, participantId: participantId, username: username),
        ],
      ),
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  final DashboardProvider provider;
  final String participantId;
  final String username;
  const _TimeRangeSelector({required this.provider, required this.participantId, required this.username});

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final initialDate = isStart ? provider.suenoStart : provider.suenoEnd;
    if (initialDate == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _suenoColor,
              onPrimary: Colors.white,
              onSurface: _text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null && context.mounted) {
      final newDate = DateTime(
        initialDate.year, initialDate.month, initialDate.day,
        time.hour, time.minute,
      );

      DateTime start = provider.suenoStart!;
      DateTime end = provider.suenoEnd!;

      if (isStart) {
        start = newDate;
        if (start.isAfter(end)) end = start.add(const Duration(hours: 1));
      } else {
        end = newDate;
        if (end.isBefore(start)) start = end.subtract(const Duration(hours: 1));
      }

      provider.setSuenoRango(start, end, participantId, username);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (provider.suenoStart == null || provider.suenoEnd == null) return const SizedBox();

    final startStr = DateFormat('HH:mm').format(provider.suenoStart!);
    final endStr = DateFormat('HH:mm').format(provider.suenoEnd!);
    final dateStr = DateFormat('dd MMM yyyy').format(provider.suenoStart!);

    final isMobile = MediaQuery.of(context).size.width < 600;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: isMobile ? 8 : 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendarDays, size: 13, color: _muted),
            const SizedBox(width: 6),
            Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: _text, fontWeight: FontWeight.w600)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.clock, size: 13, color: _muted),
            const SizedBox(width: 6),
            if (!isMobile)
              Text('Tramo:', style: GoogleFonts.inter(fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
            if (!isMobile) const SizedBox(width: 8),
            _TimeButton(time: startStr, onTap: () => _pickTime(context, true)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('-', style: TextStyle(color: _muted))),
            _TimeButton(time: endStr, onTap: () => _pickTime(context, false)),
          ],
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String time;
  final VoidCallback onTap;
  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _suenoColor,
          ),
        ),
      ),
    );
  }
}

class _KPIsLayer extends StatelessWidget {
  final List<Biomarker> sleepData;
  final List<Biomarker> posData;

  const _KPIsLayer({required this.sleepData, required this.posData});

  @override
  Widget build(BuildContext context) {
    // Cálculo de métricas
    int totalDataPoints = sleepData.length;
    int asleepPoints = sleepData.where((d) => d.value != null && d.value! > 0).length;
    
    // KPI 1: Eficiencia
    double efficiency = totalDataPoints > 0 ? (asleepPoints / totalDataPoints) * 100 : 0.0;
    
    // KPI 2: TST (Aproximación asumiendo que cada punto es un minuto para simplificar o usando el bucket)
    // Para ser genéricos, TST en horas y minutos asumiendo resolución de 1 min
    int tstMinutes = asleepPoints; // Asume bucket de 1 min. Si es distinto habría que escalar
    int tstHours = tstMinutes ~/ 60;
    int tstRemMins = tstMinutes % 60;
    
    // KPI 3: WASO (Wake After Sleep Onset)
    int awakenings = 0;
    bool hasSlept = false;
    bool isCurrentlyAwake = false;
    for (var d in sleepData) {
      if (d.value == null) continue;
      if (d.value! > 0) {
        hasSlept = true;
        isCurrentlyAwake = false;
      } else if (hasSlept && d.value! == 0) {
        if (!isCurrentlyAwake) {
          awakenings++;
          isCurrentlyAwake = true;
        }
      }
    }

    // KPI 4: Estabilidad Postural
    int postureChanges = 0;
    double? lastPos;
    for (var d in posData) {
      if (d.value == null) continue;
      if (lastPos != null && d.value != lastPos) {
        postureChanges++;
      }
      lastPos = d.value;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
        
        final kpis = [
          _KPICard(
            title: 'Eficiencia del Sueño',
            value: totalDataPoints == 0 ? '--' : '${efficiency.toStringAsFixed(1)} %',
            subtitle: 'Tiempo dormido vs Tiempo en cama',
            icon: LucideIcons.timer,
            color: _suenoColor,
            tooltip: "Porcentaje de tiempo que el paciente estuvo dormido en relación al tiempo total registrado en la cama. Una eficiencia mayor al 85% se considera clínicamente saludable.",
          ),
          _KPICard(
            title: 'Tiempo Total de Sueño (TST)',
            value: totalDataPoints == 0 ? '--' : '${tstHours}h ${tstRemMins}m',
            subtitle: 'Horas reales de descanso',
            icon: LucideIcons.clock,
            color: _lightSleep,
            tooltip: "Tiempo total efectivo de sueño. En adultos, un TST saludable oscila entre 7 y 9 horas. Valores inferiores pueden indicar privación de sueño.",
          ),
          _KPICard(
            title: 'Latencia y Despertares (WASO)',
            value: totalDataPoints == 0 ? '--' : '$awakenings veces',
            subtitle: 'Transiciones a fase de alerta',
            icon: LucideIcons.activity,
            color: _awake,
            tooltip: "Wake After Sleep Onset. Refleja la fragmentación del sueño cuantificando cuántas veces el paciente pasó de estar dormido a estar despierto durante la noche.",
          ),
          _KPICard(
            title: 'Estabilidad Postural',
            value: posData.isEmpty ? '--' : '$postureChanges cambios',
            subtitle: 'Rotaciones significativas',
            icon: LucideIcons.refreshCw,
            color: _posLeft,
            tooltip: "Número total de cambios de postura detectados. Un número excesivamente alto indica inquietud física que puede mermar la calidad de las fases profundas del sueño.",
          ),
        ];

        if (isMobile) {
          return Column(
            children: [
              Row(children: [Expanded(child: kpis[0]), const SizedBox(width: 12), Expanded(child: kpis[1])]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: kpis[2]), const SizedBox(width: 12), Expanded(child: kpis[3])]),
            ],
          );
        } else if (isTablet) {
          return Column(
            children: [
              Row(children: [Expanded(child: kpis[0]), const SizedBox(width: 16), Expanded(child: kpis[1])]),
              const SizedBox(height: 16),
              Row(children: [Expanded(child: kpis[2]), const SizedBox(width: 16), Expanded(child: kpis[3])]),
            ],
          );
        }
        
        return Row(
          children: [
            Expanded(child: kpis[0]), const SizedBox(width: 16),
            Expanded(child: kpis[1]), const SizedBox(width: 16),
            Expanded(child: kpis[2]), const SizedBox(width: 16),
            Expanded(child: kpis[3]),
          ],
        );
      },
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String tooltip;

  const _KPICard({
    required this.title, 
    required this.value, 
    required this.subtitle, 
    required this.icon, 
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(isMobile ? 8 : 10)),
                child: Icon(icon, size: isMobile ? 16 : 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(title, style: GoogleFonts.inter(fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.bold, color: _muted)),
                        Tooltip(
                          message: tooltip,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: _text.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)
                            ],
                          ),
                          textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11, height: 1.4),
                          child: Icon(LucideIcons.info, size: 12, color: _muted.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.inter(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: _text, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: _muted), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _HipnogramaLayer extends StatelessWidget {
  final List<Biomarker> sleepData;
  final List<Biomarker> stagesData;

  const _HipnogramaLayer({required this.sleepData, required this.stagesData});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _deepSleep.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.activity, size: 16, color: _deepSleep),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Hipnograma de Ciclos de Descanso',
                          style: GoogleFonts.outfit(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _text),
                        ),
                      ],
                    ),
                    Tooltip(
                      message: "Representa la profundidad del sueño. Los ciclos deberían durar aprox. 90 minutos. Demasiados picos hacia 'Despierto' indican una alta fragmentación del sueño (WASO).",
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _text.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                      child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Distribución temporal de las etapas de sueño detectadas.', style: GoogleFonts.inter(color: _muted, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 250,
              child: (sleepData.isEmpty && stagesData.isEmpty)
                  ? Center(child: Text('Sin datos de sueño para graficar', style: GoogleFonts.inter(color: _muted)))
                  : LineChart(_buildChartData(context)),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    // Si no tenemos stages, intentamos mapear sleep_detection
    List<Biomarker> targetData = stagesData.isNotEmpty ? stagesData : sleepData;
    
    List<FlSpot> spots = [];
    for (var d in targetData) {
      if (d.value != null) {
        // Mapeo asumido si es sleep_detection: 0 = Awake, >0 = Sleep
        // Queremos que "Awake" quede arriba (y=3) y "Deep" abajo (y=1)
        double yVal = 3; // Por defecto despierto
        if (stagesData.isNotEmpty) {
           // Asumiendo stages: 0=Awake, 1=Light, 2=Deep
           if (d.value! == 0) {
             yVal = 3;
           } else if (d.value! == 1) {
             yVal = 2;
           } else if (d.value! >= 2) {
             yVal = 1;
           }
        } else {
           // Sleep detection genérico
           if (d.value! > 0) {
             yVal = 2; // Simulamos Light Sleep
           } else {
             yVal = 3; // Awake
           }
        }
        spots.add(FlSpot(d.time.toUtc().millisecondsSinceEpoch.toDouble(), yVal));
      }
    }

    double minX = 0, maxX = 0;
    if (spots.isNotEmpty) {
      minX = spots.map((s) => s.x).reduce(math.min);
      maxX = spots.map((s) => s.x).reduce(math.max);
    }
    double xInterval = (maxX - minX) / 5;
    if (xInterval <= 0) xInterval = 3600000;

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: 0,
      maxY: 4,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          isStepLineChart: true,
          color: _deepSleep,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: const LinearGradient(
              colors: [_deepSleep, _lightSleep],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        )
      ],
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (v) => FlLine(color: _border.withValues(alpha: 0.3), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: xInterval,
            reservedSize: 30,
            getTitlesWidget: (v, meta) {
              if (v < minX || v > maxX - (xInterval/2)) return const SizedBox();
              final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8,
                child: Text(DateFormat('HH:mm').format(dt), style: GoogleFonts.inter(color: _muted, fontSize: isMobile ? 8 : 10))
              );
            }
          )
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: isMobile ? 50 : 60,
            getTitlesWidget: (v, meta) {
              String text = '';
              Color color = _muted;
              if (v == 1) { text = 'Profundo'; color = _deepSleep; }
              else if (v == 2) { text = 'Ligero'; color = _lightSleep; }
              else if (v == 3) { text = 'Despierto'; color = _awake; }
              
              if (text.isEmpty) return const SizedBox();
              
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(text, style: GoogleFonts.inter(color: color, fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.bold)),
              );
            },
          )
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false), // Desactivado para vista macro
    );
  }
}

class _GanttPosturalLayer extends StatelessWidget {
  final List<Biomarker> posData;
  final List<Biomarker> sleepData;

  const _GanttPosturalLayer({required this.posData, required this.sleepData});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _posLeft.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.refreshCw, size: 16, color: _posLeft),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Análisis de Posición Corporal',
                          style: GoogleFonts.outfit(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _text),
                        ),
                      ],
                    ),
                    Tooltip(
                      message: "Registra los 7 estados de posición cualitativa: Sitting, Standing, Left, Right, Top, Bottom y Miscellaneous, capturados por el acelerómetro del dispositivo.",
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _text.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                      child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mantenimiento de la posición física durante el periodo de estudio (vigilia y reposo).',
                        style: GoogleFonts.inter(fontSize: 11, color: _muted),
                      ),
                      const SizedBox(height: 16),
                      _buildDistributionSummary(posData),
                      const SizedBox(height: 16),
                      _buildLegend(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Mantenimiento de la posición física durante el periodo de estudio (vigilia y reposo).',
                          style: GoogleFonts.inter(color: _muted, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: _buildDistributionSummary(posData),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                if (!isMobile) _buildLegend(),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 40,
              child: posData.isEmpty
                  ? Center(child: Text('Sin datos posturales', style: GoogleFonts.inter(color: _muted)))
                  : _buildGanttData(context),
            ),
          ),
          if (posData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              child: _buildGanttAxis(context),
            ),
        ],
      ),
    );
  }

  Widget _buildDistributionSummary(List<Biomarker> data) {
    if (data.isEmpty) return const SizedBox();
    
    final counts = <int, int>{};
    for (var d in data) {
      if (d.value != null) {
        int val = d.value!.toInt();
        counts[val] = (counts[val] ?? 0) + 1;
      }
    }
    
    final total = data.length;
    
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: counts.entries.map((e) {
        String label = '';
        Color color = _posMisc;
        switch (e.key) {
          case 0: label = 'Sentado'; color = _posSitting; break;
          case 1: label = 'De pie';  color = _posStanding; break;
          case 2: label = 'Izquierda'; color = _posLeft; break;
          case 3: label = 'Derecha'; color = _posRight; break;
          case 4: label = 'Arriba';  color = _posTop; break;
          case 5: label = 'Abajo';   color = _posBottom; break;
          default: label = 'Transición'; color = _posMisc;
        }
        
        final pct = (e.value / total * 100).toStringAsFixed(0);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(
            '$label: $pct%',
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(label: 'Sentado', color: _posSitting),
        const SizedBox(width: 12),
        _LegendItem(label: 'De pie', color: _posStanding),
        const SizedBox(width: 12),
        _LegendItem(label: 'Izquierda', color: _posLeft),
        const SizedBox(width: 12),
        _LegendItem(label: 'Derecha', color: _posRight),
        const SizedBox(width: 12),
        _LegendItem(label: 'Arriba', color: _posTop),
        const SizedBox(width: 12),
        _LegendItem(label: 'Abajo', color: _posBottom),
        const SizedBox(width: 12),
        _LegendItem(label: 'Transición', color: _posMisc),
      ],
    );
  }

  Widget _buildGanttData(BuildContext context) {
    // Tomamos todos los tiempos para alinear con el Hipnograma
    final allT = [...sleepData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble()), ...posData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble())];
    double minX = 0, maxX = 0;
    if (allT.isNotEmpty) {
      minX = allT.reduce(math.min);
      maxX = allT.reduce(math.max);
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CustomPaint(
        size: Size.infinite,
        painter: _PosturalGanttPainter(
          data: posData,
          minX: minX,
          maxX: maxX,
        ),
      ),
    );
  }

  Widget _buildGanttAxis(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final allT = [...sleepData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble()), ...posData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble())];
    double minX = 0, maxX = 0;
    if (allT.isNotEmpty) {
      minX = allT.reduce(math.min);
      maxX = allT.reduce(math.max);
    }
    if (minX == maxX) return const SizedBox();

    double xInterval = (maxX - minX) / 5;
    if (xInterval <= 0) xInterval = 3600000;

    List<Widget> labels = [];
    for (double v = minX; v <= maxX; v += xInterval) {
      final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
      labels.add(
        Text(DateFormat('HH:mm').format(dt), style: GoogleFonts.inter(color: _muted, fontSize: isMobile ? 8 : 10))
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels,
    );
  }
}

class _PosturalGanttPainter extends CustomPainter {
  final List<Biomarker> data;
  final double minX;
  final double maxX;
  
  _PosturalGanttPainter({required this.data, required this.minX, required this.maxX});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final range = maxX - minX;
    if (range <= 0) return;
    
    for (int i = 0; i < data.length; i++) {
      Color barColor = _posLeft;
      final val = data[i].value?.toInt();
      if (val != null) {
        switch (val) {
          case 0: barColor = _posSitting;  break;
          case 1: barColor = _posStanding; break;
          case 2: barColor = _posLeft;     break;
          case 3: barColor = _posRight;    break;
          case 4: barColor = _posTop;      break;
          case 5: barColor = _posBottom;   break;
          default: barColor = _posMisc;
        }
      }
      
      paint.color = barColor;
      final x = (data[i].time.toUtc().millisecondsSinceEpoch.toDouble() - minX) / range * size.width;
      final nextX = i < data.length - 1
          ? (data[i + 1].time.toUtc().millisecondsSinceEpoch.toDouble() - minX) / range * size.width
          : size.width;
          
      // Evitar dibujar rectángulos invertidos si hay desorden leve
      if (nextX >= x) {
        canvas.drawRect(Rect.fromLTRB(x, 0, nextX, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(color: _text, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
