import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/biomarker.dart';
import '../providers/dashboard_provider.dart';

const Color _bg = Color(0xFF0F172A); 
const Color _surface = Color(0xFF1E293B); 
const Color _border = Color(0xFF334155); 
const Color _textPrimary = Colors.white;
const Color _textMuted = Color(0xFF94A3B8); 
const Color _accent = Color(0xFF38BDF8); 

// Colores de Clasificación (Consistentes con el patrón rose/blue/indigo)
const Color _clsNoData  = Color(0xFF0F172A);
const Color _clsStill   = Color(0xFF334155);
const Color _clsWalk    = Color(0xFF38BDF8); // Cyber Blue
const Color _clsRun     = Color(0xFF818CF8); // Indigo 400
const Color _clsGeneric = Color(0xFF64748B);

// Colores de Intensidad
const Color _intNoData = Color(0xFF0F172A);
const Color _intSed    = Color(0xFF334155);
const Color _intLPA    = Color(0xFF38BDF8); // Cyber Blue
const Color _intMPA    = Color(0xFF818CF8); // Indigo 400
const Color _intVPA    = Color(0xFFA78BFA); // Violet 400

class MovimientoScreen extends StatefulWidget {
  final String participantId;
  final String username;

  const MovimientoScreen({
    super.key,
    required this.participantId,
    required this.username,
  });

  @override
  State<MovimientoScreen> createState() => _MovimientoScreenState();
}

class _MovimientoScreenState extends State<MovimientoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchMovimientoMetrics(
            widget.participantId,
            widget.username,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) => Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: _bg,
          cardColor: _surface,
        ),
        child: Column(
          children: [
            _ControlPanel(
              provider: provider,
              participantId: widget.participantId,
              username: widget.username,
            ),
            Expanded(
              child: Container(
                color: _bg,
                child: provider.isMovimientoLoading
                    ? const Center(child: CircularProgressIndicator(color: _accent))
                    : _buildDashboard(provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(DashboardProvider provider) {
    final metrics = provider.movimientoMetrics;
    if (metrics.isEmpty) return _NoDataPlaceholder();

    final byType = <String, List<Biomarker>>{};
    for (final m in metrics) {
      byType.putIfAbsent(m.sensorType, () => []).add(m);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isLaptop = width > 1100;
        final bool isTablet = width > 700 && width <= 1100;
        final double padding = width > 720 ? 32.0 : 16.0;

        final sections = [
          const _MovementQualityLegend(),
          _ActivitySpectrum(byType: byType),
          _CargaCinetica(byType: byType),
          _EficienciaMarcha(
            stepData: byType['step_count'] ?? [],
            wearingData: byType['wearing_detection'] ?? [],
          ),
          _AnalisisBiomecanico(byType: byType),
        ];

        if (isLaptop) {
          return ListView(
            padding: EdgeInsets.all(padding),
            children: [
              sections[0], // Legend
              sections[1], // Spectrum full width
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: sections[2]),
                  const SizedBox(width: 24),
                  Expanded(child: sections[3]),
                ],
              ),
              sections[4], // Biomechanical full width
            ],
          );
        }

        if (isTablet) {
          return ListView(
            padding: EdgeInsets.all(padding),
            children: [
              sections[0],
              sections[1],
              sections[2],
              sections[3],
            ],
          );
        }

        return ListView(
          padding: EdgeInsets.all(padding),
          children: sections,
        );
      },
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final DashboardProvider provider;
  final String participantId;
  final String username;

  const _ControlPanel({
    required this.provider,
    required this.participantId,
    required this.username,
  });

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year} $h:$mi';
  }

  Future<void> _pickRange(BuildContext context, bool isStart) async {
    final current = (isStart ? provider.movimientoStart : provider.movimientoEnd) ?? DateTime.now();
    final first = provider.dataRangeStart ?? DateTime(2000);
    final last = provider.dataRangeEnd ?? DateTime(2100);

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _accent, surface: _surface),
        ),
        child: child!,
      ),
    );
    if (date == null) return;

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final start = isStart ? selected : (provider.movimientoStart ?? selected);
    final end = isStart ? (provider.movimientoEnd ?? selected) : selected;

    if (end.isBefore(start)) return;
    provider.setMovimientoRango(start, end, participantId, username);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 850;
          
          final header = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.calendar, size: 16, color: _accent),
              ),
              const SizedBox(width: 14),
              Text(
                'Monitorización Temporal',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary, letterSpacing: 0.2),
              ),
            ],
          );

          final selector = _DateRangeSelector(
            start: _formatDateTime(provider.movimientoStart),
            end: _formatDateTime(provider.movimientoEnd),
            onTapStart: () => _pickRange(context, true),
            onTapEnd: () => _pickRange(context, false),
          );

          final resolution = _ResolutionBadge(label: provider.movimientoResolucion);

          if (!isCompact) {
            return Row(
              children: [
                header,
                const SizedBox(width: 40),
                Flexible(child: selector),
                const Spacer(),
                resolution,
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [header, resolution]),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: selector),
              ],
            );
          }
        },
      ),
    );
  }
}

class _DateRangeSelector extends StatelessWidget {
  final String start;
  final String end;
  final VoidCallback onTapStart;
  final VoidCallback onTapEnd;

  const _DateRangeSelector({required this.start, required this.end, required this.onTapStart, required this.onTapEnd});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _TimeButton(label: 'Desde', value: start, onTap: onTapStart)),
            Container(width: 1, color: _border),
            Expanded(child: _TimeButton(label: 'Hasta', value: end, onTap: onTapEnd)),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeButton({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _accent)),
          ],
        ),
      ),
    );
  }
}

class _ResolutionBadge extends StatelessWidget {
  final String label;
  const _ResolutionBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _accent.withValues(alpha: 0.2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.gauge, size: 12, color: _accent),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _accent)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 25, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: _accent),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: _textMuted)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ActivitySpectrum extends StatelessWidget {
  final Map<String, List<Biomarker>> byType;
  const _ActivitySpectrum({required this.byType});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: LucideIcons.layers,
      title: 'Espectro de Actividad',
      subtitle: 'Análisis categórico de patrones de movimiento',
      child: Column(
        children: [
          _HeatmapRow(label: 'MOTOR', data: byType['activity_class'] ?? [], colorFn: _getColorCls),
          const SizedBox(height: 20),
          _HeatmapRow(label: 'INTENSIDAD', data: byType['activity_intensity'] ?? [], colorFn: _getColorInt),
          const SizedBox(height: 32),
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            return isNarrow 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SpectrumLegendCls(),
                    const SizedBox(height: 24),
                    _SpectrumLegendInt(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _SpectrumLegendCls()),
                    const SizedBox(width: 40),
                    Expanded(child: _SpectrumLegendInt()),
                  ],
                );
          }),
        ],
      ),
    );
  }

  Color _getColorCls(Biomarker m) => m.value == null ? _clsNoData : [ _clsStill, _clsWalk, _clsRun, _clsGeneric ][m.value!.toInt().clamp(0, 3)];
  Color _getColorInt(Biomarker m) => m.value == null ? _intNoData : [ _intSed, _intLPA, _intMPA, _intVPA ][m.value!.toInt().clamp(0, 3)];
}

class _HeatmapRow extends StatelessWidget {
  final String label;
  final List<Biomarker> data;
  final Color Function(Biomarker) colorFn;

  const _HeatmapRow({required this.label, required this.data, required this.colorFn});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 85, child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _textMuted, letterSpacing: 0.5))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(height: 44, child: CustomPaint(painter: _HeatmapPainter(data: data, colorFn: colorFn))))),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<Biomarker> data;
  final Color Function(Biomarker) colorFn;
  _HeatmapPainter({required this.data, required this.colorFn});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final start = data.first.time.millisecondsSinceEpoch;
    final range = data.last.time.millisecondsSinceEpoch - start;
    if (range <= 0) return;

    for (int i = 0; i < data.length; i++) {
      paint.color = colorFn(data[i]);
      final x = (data[i].time.millisecondsSinceEpoch - start) / range * size.width;
      final nextX = (i < data.length - 1) ? (data[i + 1].time.millisecondsSinceEpoch - start) / range * size.width : size.width;
      canvas.drawRect(Rect.fromLTRB(x, 0, nextX, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SpectrumLegendCls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CLASIFICACIÓN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _textMuted, letterSpacing: 0.5)),
      const SizedBox(height: 16),
      Wrap(spacing: 20, runSpacing: 12, children: [
        _LegendItem('Quieto', _clsStill),
        _LegendItem('Caminata', _clsWalk),
        _LegendItem('Carrera', _clsRun),
        _LegendItem('Genérico', _clsGeneric),
      ]),
    ]);
  }
}

class _SpectrumLegendInt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('INTENSIDAD', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _textMuted, letterSpacing: 0.5)),
      const SizedBox(height: 16),
      Wrap(spacing: 20, runSpacing: 12, children: [
        _LegendItem('Sedentario', _intSed),
        _LegendItem('LPA', _intLPA),
        _LegendItem('MPA', _intMPA),
        _LegendItem('VPA', _intVPA),
      ]),
    ]);
  }
}

class _CargaCinetica extends StatelessWidget {
  final Map<String, List<Biomarker>> byType;
  const _CargaCinetica({required this.byType});

  @override
  Widget build(BuildContext context) {
    final vec = byType['actigraphy_vector'] ?? byType['acticounts_total'] ?? [];
    final std = byType['accelerometer_std'] ?? [];

    return _SectionCard(
      icon: LucideIcons.activity,
      title: 'Carga Cinética',
      subtitle: 'Volumen y estabilidad de movimiento',
      child: Column(
        children: [
          SizedBox(height: 240, child: LineChart(_buildChartData(vec, std))),
          const SizedBox(height: 32),
          Wrap(spacing: 32, runSpacing: 16, children: [
            _LegendItem('Magnitud Vectorial', _accent),
            _LegendItem('Estabilidad (STD)', const Color(0xFFFBBF24)), // Amber 400
          ]),
        ],
      ),
    );
  }

  LineChartData _buildChartData(List<Biomarker> vec, List<Biomarker> std) {
    if (vec.isEmpty) return LineChartData();
    final start = vec.first.time.millisecondsSinceEpoch;
    final range = vec.last.time.millisecondsSinceEpoch - start;
    final maxVec = vec.map((e) => e.value ?? 0).reduce((a, b) => a > b ? a : b);
    final maxStd = std.isNotEmpty ? std.map((e) => e.value ?? 0).reduce((a, b) => a > b ? a : b) : 1.0;

    final vecSpots = vec.map((m) => FlSpot((m.time.millisecondsSinceEpoch - start) / range * 100, m.value ?? 0)).toList();
    final stdSpots = std.map((m) => FlSpot((m.time.millisecondsSinceEpoch - start) / range * 100, (m.value ?? 0) * (maxVec / (maxStd > 0 ? maxStd : 1.0)))).toList();

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: vecSpots,
          isCurved: true,
          color: _accent,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_accent.withValues(alpha: 0.2), _accent.withValues(alpha: 0.01)])),
        ),
        if (stdSpots.isNotEmpty)
          LineChartBarData(
            spots: stdSpots,
            isCurved: true,
            color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
          ),
      ],
      titlesData: const FlTitlesData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: _border.withValues(alpha: 0.3), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _surface,
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.barIndex == 0 ? "MAG" : "STD"}: ${s.y.toStringAsFixed(1)}', GoogleFonts.inter(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.bold))).toList(),
        ),
      ),
    );
  }
}

class _EficienciaMarcha extends StatelessWidget {
  final List<Biomarker> stepData;
  final List<Biomarker> wearingData;
  const _EficienciaMarcha({required this.stepData, required this.wearingData});

  @override
  Widget build(BuildContext context) {
    final grouped = <int, int>{};
    for (var m in stepData) {
      if (m.value == null) continue;
      grouped[m.time.hour] = (grouped[m.time.hour] ?? 0) + m.value!.toInt();
    }
    final hours = grouped.keys.toList()..sort();
    
    return _SectionCard(
      icon: LucideIcons.footprints,
      title: 'Eficiencia de Marcha',
      subtitle: 'Cadencia horaria acumulada',
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            barGroups: hours.map((h) => BarChartGroupData(x: h, barRods: [
              BarChartRodData(
                toY: grouped[h]!.toDouble(), 
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_accent, Color(0xFF0EA5E9)]),
                width: 20, 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: grouped.values.isEmpty ? 100 : grouped.values.reduce((a, b) => a > b ? a : b).toDouble(), color: _bg),
              )
            ])).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 10), child: Text('${v.toInt()}h', style: GoogleFonts.inter(fontSize: 11, color: _textMuted, fontWeight: FontWeight.bold))))),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => _surface,
                getTooltipItem: (group, _, rod, __) => BarTooltipItem('${rod.toY.toInt()} pasos', GoogleFonts.inter(color: _accent, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalisisBiomecanico extends StatefulWidget {
  final Map<String, List<Biomarker>> byType;
  const _AnalisisBiomecanico({required this.byType});
  @override
  State<_AnalisisBiomecanico> createState() => _AnalisisBiomecanicoState();
}

class _AnalisisBiomecanicoState extends State<_AnalisisBiomecanico> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final x = widget.byType['acticounts_x'] ?? [];
    final y = widget.byType['acticounts_y'] ?? [];
    final z = widget.byType['acticounts_z'] ?? [];

    return _SectionCard(
      icon: LucideIcons.box,
      title: 'Análisis Biomecánico',
      subtitle: 'Dinámica tridimensional del movimiento',
      trailing: TextButton.icon(
        onPressed: () => setState(() => _expanded = !_expanded),
        icon: Icon(_expanded ? LucideIcons.eyeOff : LucideIcons.eye, size: 16, color: _accent),
        label: Text(_expanded ? 'OCULTAR' : 'VER EJES', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _accent)),
      ),
      child: AnimatedCrossFade(
        firstChild: const SizedBox(width: double.infinity),
        secondChild: Column(
          children: [
            SizedBox(height: 240, child: LineChart(_buildChartData(x, y, z))),
            const SizedBox(height: 32),
            Wrap(spacing: 24, runSpacing: 16, children: [
              _LegendItem('Eje X (Mediolateral)', const Color(0xFFFB7185)), // Rose 400
              _LegendItem('Eje Y (Longitudinal)', const Color(0xFF34D399)), // Emerald 400
              _LegendItem('Eje Z (Anteroposterior)', const Color(0xFF818CF8)), // Indigo 400
            ]),
          ],
        ),
        crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 400),
      ),
    );
  }

  LineChartData _buildChartData(List<Biomarker> x, List<Biomarker> y, List<Biomarker> z) {
    if (x.isEmpty) return LineChartData();
    final start = x.first.time.millisecondsSinceEpoch;
    final range = x.last.time.millisecondsSinceEpoch - start;
    return LineChartData(
      lineBarsData: [
        _buildBar(x, const Color(0xFFFB7185), start, range),
        _buildBar(y, const Color(0xFF34D399), start, range),
        _buildBar(z, const Color(0xFF818CF8), start, range),
      ],
      titlesData: const FlTitlesData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: _border.withValues(alpha: 0.3), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => _surface, getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(s.y.toStringAsFixed(1), GoogleFonts.inter(color: s.barIndex == 0 ? const Color(0xFFFB7185) : s.barIndex == 1 ? const Color(0xFF34D399) : const Color(0xFF818CF8), fontWeight: FontWeight.bold))).toList()),
      ),
    );
  }

  LineChartBarData _buildBar(List<Biomarker> data, Color color, int start, int range) => LineChartBarData(
    spots: data.map((m) => FlSpot((m.time.millisecondsSinceEpoch - start) / range * 100, m.value ?? 0)).toList(), 
    isCurved: true, 
    color: color, 
    barWidth: 2.5, 
    dotData: const FlDotData(show: false), 
    belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.0)]))
  );
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)])),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textMuted)),
    ]);
  }
}

class _NoDataPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.database, size: 80, color: _textMuted.withValues(alpha: 0.1)),
      const SizedBox(height: 24),
      Text('Sin registros en este periodo', style: GoogleFonts.outfit(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Selecciona un intervalo con actividad para el análisis.', style: GoogleFonts.inter(color: _textMuted, fontSize: 14)),
    ]));
  }
}

class _MovementQualityLegend extends StatelessWidget {
  const _MovementQualityLegend();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _buildItem(const Color(0xFF34D399), LucideIcons.checkCircle, 'Registro Óptimo'),
            _buildItem(_textMuted, LucideIcons.minusCircle, 'Gap/Desconexión'),
            _buildItem(const Color(0xFFFB7185), LucideIcons.alertTriangle, 'Calidad Baja'),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Color color, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: _textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
