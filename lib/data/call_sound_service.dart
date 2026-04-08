import 'package:just_audio/just_audio.dart';

class CallSoundService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playIncoming() async {
    await _player.setAsset('assets/sounds/incoming_call.mp3');
    await _player.setLoopMode(LoopMode.one);
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
