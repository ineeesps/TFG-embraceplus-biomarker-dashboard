import 'package:flutter/material.dart';
import '../models/biomarker.dart';
import '../services/api_service.dart';

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Biomarker> _metrics = [];
  bool _isLoading = false;
  String? _error;

  List<Biomarker> get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchMetrics(String participantId, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _metrics = await _apiService.getMetrics(participantId, username);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, List<Biomarker>> get metricsBySensor {
    final Map<String, List<Biomarker>> map = {};
    for (var m in _metrics) {
      map.putIfAbsent(m.sensorType, () => []).add(m);
    }
    return map;
  }


  int? get totalSteps {
    final steps = _metrics.where((m) => m.sensorType == 'step_count' && m.value != null);
    if (steps.isEmpty) return null;
    return steps.fold<double>(0.0, (sum, m) => sum + m.value!).toInt();
  }

  int? get avgBpm {
    final bpm = _metrics.where((m) => m.sensorType == 'pulse_rate' && m.value != null);
    if (bpm.isEmpty) return null;
    final avg = bpm.fold<double>(0.0, (sum, m) => sum + m.value!) / bpm.length;
    return avg.toInt();
  }

  double? get totalMets {
    final mets = _metrics.where((m) => m.sensorType == 'met' && m.value != null);
    if (mets.isEmpty) return null;
    return mets.fold<double>(0.0, (sum, m) => sum + m.value!);
  }

  double? get avgTemp {
    final temp = _metrics.where((m) => m.sensorType == 'temperature' && m.value != null);
    if (temp.isEmpty) return null;
    return temp.fold<double>(0.0, (sum, m) => sum + m.value!) / temp.length;
  }

  double? get compliancePercentage {
    final wearing = _metrics.where((m) => m.sensorType == 'wearing_detection');
    if (wearing.isEmpty) return null;
    
    int validPoints = 0;
    for (var m in wearing) {
      if (m.qualityFlag != 'device_not_worn_correctly' && m.qualityFlag != 'device_not_recording') {
        validPoints++;
      }
    }
    return (validPoints / wearing.length) * 100;
  }
  double? get sleepHours {
    final sleep = _metrics.where((m) => m.sensorType == 'sleep_detection' && m.value != null);
    if (sleep.isEmpty) return null;
    // Cada registro suele ser de 30s o 1min. Sumamos los que no sean 'Wake' (0)
    final sleepPoints = sleep.where((m) => m.value! > 0).length;
    return (sleepPoints * 30) / 3600; // Asumiendo buckets de 30s
  }

  double? get avgStress {
    final eda = _metrics.where((m) => m.sensorType == 'eda' && m.value != null);
    if (eda.isEmpty) return null;
    return eda.fold<double>(0.0, (sum, m) => sum + m.value!) / eda.length;
  }

  String get lastActivity {
    final act = _metrics.where((m) {
      final type = m.sensorType.toLowerCase().replaceAll('-', '_');
      return (type == 'activity_class' || type == 'activity_classification') && m.value != null;
    }).toList();
    
    if (act.isEmpty) return 'Desconocido';
    final val = act.last.value!.toInt();
    switch (val) {
      case 0: return 'Sedentario';
      case 1: return 'Caminando';
      case 2: return 'Corriendo';
      case 3: return 'Actividad Genérica';
      default: return 'Desconocido';
    }
  }

  String get lastPosition {
    final pos = _metrics.where((m) {
      final type = m.sensorType.toLowerCase().replaceAll('-', '_');
      return (type == 'body_position' || type == 'body_position_left') && m.value != null;
    }).toList();
    
    if (pos.isEmpty) return 'Desconocido';
    final val = pos.last.value!.toInt();
    switch (val) {
      case 0: return 'Sentado / Reclinado';
      case 1: return 'De pie';
      case 2: return 'Lateral Izquierdo';
      case 3: return 'Lateral Derecho';
      case 4: return 'Prono (Boca abajo)';
      case 5: return 'Supino (Boca arriba)';
      default: return 'Desconocido';
    }
  }
}
