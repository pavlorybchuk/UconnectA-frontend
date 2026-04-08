import 'dart:async';
import 'package:vibration/vibration.dart';

class CallVibrationService {
  Timer? _timer;
  bool _enabled = false;

  Future<bool> _canVibrate() async {
    return await Vibration.hasVibrator();
  }

  /// Incoming call: repeating vibration
  Future<void> startIncoming() async {
    if (!await _canVibrate()) return;

    _enabled = true;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_enabled) return;

      Vibration.vibrate(pattern: [0, 700, 500], intensities: [128, 255]);
    });
  }

  /// Short feedback (accept)
  Future<void> shortPulse() async {
    if (!await _canVibrate()) return;

    Vibration.vibrate(duration: 80);
  }

  Future<void> stop() async {
    _enabled = false;
    _timer?.cancel();
    _timer = null;
    await Vibration.cancel();
  }
}
