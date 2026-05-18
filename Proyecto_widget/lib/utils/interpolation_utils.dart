import '../models/biomarker.dart';

class InterpolationUtils {
  static bool isBad(String flag) =>
      flag.contains('device_not') ||
      flag.contains('low_signal') ||
      flag.contains('motion');

  /// Returns parallel lists of length == data.length:
  /// - [original]: valid (non-bad) values; null for bad/missing points.
  /// - [interpolated]: gaps filled according to [method] ('ffill'|'linear'|'spline').
  static ({List<double?> original, List<double?> interpolated}) compute(
    List<Biomarker> data,
    String method,
  ) {
    if (data.isEmpty) return (original: [], interpolated: []);

    final n = data.length;
    final original     = List<double?>.filled(n, null);
    final interpolated = List<double?>.filled(n, null);

    for (int i = 0; i < n; i++) {
      if (!isBad(data[i].qualityFlag) && data[i].value != null) {
        original[i]     = data[i].value;
        interpolated[i] = data[i].value;
      }
    }

    if (method == 'ffill') {
      _ffill(interpolated, n);
    } else if (method == 'spline') {
      _spline(interpolated, n);
    } else {
      _linear(interpolated, n);
    }

    return (original: original, interpolated: interpolated);
  }

  static void _ffill(List<double?> out, int n) {
    double? last;
    for (int i = 0; i < n; i++) {
      if (out[i] != null) {
        last = out[i];
      } else if (last != null) {
        out[i] = last;
      }
    }
  }

  static void _linear(List<double?> out, int n) {
    int i = 0;
    while (i < n) {
      if (out[i] != null) { i++; continue; }
      final prev = i - 1;
      int next = i;
      while (next < n && out[next] == null) { next++; }
      if (prev >= 0 && next < n) {
        final span = (next - prev).toDouble();
        for (int j = prev + 1; j < next; j++) {
          out[j] = out[prev]! + (out[next]! - out[prev]!) * (j - prev) / span;
        }
        i = next;
      } else if (next < n) {
        for (int j = 0; j < next; j++) { out[j] ??= out[next]; }
        i = next + 1;
      } else if (prev >= 0) {
        for (int j = i; j < n; j++) { out[j] ??= out[prev]; }
        break;
      } else {
        break;
      }
    }
  }

  static void _spline(List<double?> out, int n) {
    final List<int> x = [];
    final List<double> y = [];
    for (int i = 0; i < n; i++) {
      if (out[i] != null) {
        x.add(i);
        y.add(out[i]!);
      }
    }

    final k = x.length;
    if (k == 0) return;
    if (k == 1) {
      for (int i = 0; i < n; i++) {
        out[i] = y[0];
      }
      return;
    }
    if (k == 2) {
      _linear(out, n);
      return;
    }

    final List<double> h = List<double>.filled(k - 1, 0.0);
    for (int i = 0; i < k - 1; i++) {
      h[i] = (x[i + 1] - x[i]).toDouble();
    }

    final List<double> a = List<double>.filled(k, 0.0);
    final List<double> b = List<double>.filled(k, 0.0);
    final List<double> cMat = List<double>.filled(k, 0.0);
    final List<double> d = List<double>.filled(k, 0.0);

    for (int i = 1; i < k - 1; i++) {
      a[i] = h[i - 1];
      b[i] = 2.0 * (h[i - 1] + h[i]);
      cMat[i] = h[i];
      d[i] = 6.0 * ((y[i + 1] - y[i]) / h[i] - (y[i] - y[i - 1]) / h[i - 1]);
    }

    final List<double> cp = List<double>.filled(k, 0.0);
    final List<double> dp = List<double>.filled(k, 0.0);
    final List<double> c = List<double>.filled(k, 0.0);

    cp[1] = cMat[1] / b[1];
    dp[1] = d[1] / b[1];
    for (int i = 2; i < k - 1; i++) {
      final denom = b[i] - a[i] * cp[i - 1];
      cp[i] = cMat[i] / denom;
      dp[i] = (d[i] - a[i] * dp[i - 1]) / denom;
    }

    c[k - 2] = dp[k - 2];
    for (int i = k - 3; i >= 1; i--) {
      c[i] = dp[i] - cp[i] * c[i + 1];
    }

    for (int i = 0; i < x[0]; i++) {
      out[i] = y[0];
    }

    for (int interval = 0; interval < k - 1; interval++) {
      final xStart = x[interval];
      final xEnd = x[interval + 1];
      final hVal = h[interval];

      for (int i = xStart; i <= xEnd; i++) {
        final t = (i - xStart) / hVal;
        final term1 = t * y[interval + 1] + (1.0 - t) * y[interval];
        final term2 = (hVal * hVal / 6.0) * (
          (t * t * t - t) * c[interval + 1] +
          ((1.0 - t) * (1.0 - t) * (1.0 - t) - (1.0 - t)) * c[interval]
        );
        out[i] = term1 + term2;
      }
    }

    for (int i = x[k - 1] + 1; i < n; i++) {
      out[i] = y[k - 1];
    }
  }
}
