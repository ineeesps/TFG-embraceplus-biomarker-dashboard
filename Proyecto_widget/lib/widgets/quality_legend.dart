import 'package:flutter/material.dart';

class QualityLegend extends StatelessWidget {
  const QualityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 10,
        children: [
          _buildItem(theme.colorScheme.primary, 'Óptima', isDashed: false),
          _buildItem(const Color(0xFFF59E0B), 'Movimiento', isDashed: false),
          _buildItem(const Color(0xFFEF4444), 'Señal Baja', isDashed: false),
          _buildItem(const Color(0xFF94A3B8).withValues(alpha: 0.6), 'Gap (Interpolado)', isDashed: true),
        ],
      ),
    );
  }

  Widget _buildItem(Color color, String label, {required bool isDashed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed 
            ? Row(
                children: List.generate(3, (index) => Expanded(
                  child: Container(color: index % 2 == 0 ? color : Colors.transparent),
                )),
              )
            : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ],
    );
  }
}
