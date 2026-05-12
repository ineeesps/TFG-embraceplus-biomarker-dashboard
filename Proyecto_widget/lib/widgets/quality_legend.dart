import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QualityLegend extends StatelessWidget {
  const QualityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildItem(Colors.grey.shade500, 'Inactivo/Apagado'),
            _buildItem(const Color(0xFFFACC15), 'Mal colocado'),
            _buildItem(const Color(0xFFEF4444), 'Ruido/Movimiento crítico'),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.black12),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey.shade700, 
            fontSize: 10, 
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
