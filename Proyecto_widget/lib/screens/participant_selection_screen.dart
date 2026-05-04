import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class ParticipantSelectionScreen extends StatefulWidget {
  const ParticipantSelectionScreen({super.key});

  @override
  State<ParticipantSelectionScreen> createState() => _ParticipantSelectionScreenState();
}

class _ParticipantSelectionScreenState extends State<ParticipantSelectionScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _suggestedParticipants = ['PRUEBA 1', 'PRUEBA 2', 'USUARIO_TEST'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToDashboard(String id) {
    if (id.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(participantId: id.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surface.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 80, color: colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  'EmbracePlus',
                  style: theme.textTheme.headlineMedium,
                ),
                Text(
                  'MONITORING SYSTEM',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 60),
                TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter Participant ID',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.person_pin_rounded, color: colorScheme.primary),
                  ),
                  onSubmitted: _navigateToDashboard,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _navigateToDashboard(_controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.surface,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('VIEW DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
                const Text('SUGGESTIONS', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: _suggestedParticipants.map((id) {
                    return ActionChip(
                      label: Text(id),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () => _navigateToDashboard(id),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

