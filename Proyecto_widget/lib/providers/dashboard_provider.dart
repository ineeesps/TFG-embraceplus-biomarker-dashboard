import 'package:flutter/material.dart';
import '../models/biomarker.dart';
import '../services/api_service.dart';

const List<String> kMovimientoSensores = [
  'activity_class',
  'activity_intensity',
  'acticounts_total',
  'actigraphy_vector',
  'accelerometer_std',
  'step_count',
  'wearing_detection',
  'acticounts_x',
  'acticounts_y',
  'acticounts_z',
];

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Biomarker> _metrics = [];
  List<Biomarker> _movimientoMetrics = [];
  bool _isLoading = false;
  bool _isMovimientoLoading = false;
  String? _error;

  DateTime? _movimientoStart;
  DateTime? _movimientoEnd;
  DateTime? _dataRangeStart;
  DateTime? _dataRangeEnd;

  List<Biomarker> get metrics              => _metrics;
  List<Biomarker> get movimientoMetrics    => _movimientoMetrics;
  bool get isLoading                       => _isLoading;
  bool get isMovimientoLoading             => _isMovimientoLoading;
  String? get error                        => _error;
  DateTime? get movimientoStart            => _movimientoStart;
  DateTime? get movimientoEnd              => _movimientoEnd;
  DateTime? get dataRangeStart             => _dataRangeStart;
  DateTime? get dataRangeEnd               => _dataRangeEnd;

  static String _bucketForDuration(Duration d) {
    final minutes = d.inMinutes;
    if (minutes <= 60)  { return '30 seconds'; }
    if (minutes <= 360) { return '2 minutes'; }
    if (minutes <= 720) { return '5 minutes'; }
    return '10 minutes';
  }

  String get movimientoResolucion {
    if (_movimientoStart == null || _movimientoEnd == null) { return ''; }
    final bucket = _bucketForDuration(_movimientoEnd!.difference(_movimientoStart!));
    return bucket.replaceAll(' seconds', ' seg').replaceAll(' minutes', ' min');
  }

  Future<void> fetchMetrics(String participantId, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final metadata = await _apiService.getParticipantMetadata(participantId, username);
      
      if (metadata['start_time'] != null) {
        _dataRangeStart = DateTime.parse(metadata['start_time']);
        _dataRangeEnd   = DateTime.parse(metadata['end_time']);
        
        if (metadata['active_start'] != null) {
          _movimientoStart = DateTime.parse(metadata['active_start']).subtract(const Duration(minutes: 2));
          _movimientoEnd   = DateTime.parse(metadata['active_end']).add(const Duration(minutes: 2));
        } else {
          _movimientoStart = _dataRangeStart;
          _movimientoEnd   = _dataRangeEnd;
        }

        if (_movimientoStart!.isBefore(_dataRangeStart!)) _movimientoStart = _dataRangeStart;
        if (_movimientoEnd!.isAfter(_dataRangeEnd!)) _movimientoEnd = _dataRangeEnd;
      }

      _metrics = await _apiService.getMetrics(participantId, username);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMovimientoMetrics(String participantId, String username) async {
    if (_movimientoStart == null || _movimientoEnd == null) return;
    _isMovimientoLoading = true;
    notifyListeners();
    try {
      final bucket = _bucketForDuration(_movimientoEnd!.difference(_movimientoStart!));
      final all = await _apiService.getMetrics(
        participantId,
        username,
        startTime: _movimientoStart!.toUtc().toIso8601String(),
        endTime:   _movimientoEnd!.toUtc().toIso8601String(),
        bucketSize: bucket,
      );
      _movimientoMetrics = all.where((m) => kMovimientoSensores.contains(m.sensorType)).toList();
    } catch (_) {
      _movimientoMetrics = [];
    } finally {
      _isMovimientoLoading = false;
      notifyListeners();
    }
  }

  Future<void> setMovimientoRango(
    DateTime start,
    DateTime end,
    String participantId,
    String username,
  ) async {
    _movimientoStart = start;
    _movimientoEnd   = end;
    await fetchMovimientoMetrics(participantId, username);
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
