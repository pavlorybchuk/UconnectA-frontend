import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class CallSoundService {
  final _player = FlutterRingtonePlayer();

  /// Plays the user's selected ringtone (Android) or the system ringtone
  /// sound (iOS) in a loop until [stop] is called.
  Future<void> playIncoming() async {
    await _player.play(
      android: AndroidSounds.ringtone, // uses the phone's current ringtone
      ios: IosSounds.electronic,       // closest built-in equivalent on iOS
      looping: true,
      volume: 1.0,
      asAlarm: false,
    );
  }

  Future<void> stop() async {
    await _player.stop();
  }
}