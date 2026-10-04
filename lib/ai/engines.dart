import '../game/missions.dart' show Voice;
import 'audio.dart';
import 'speech.dart';

/// Hears the child. Swappable so different speech recognizers can be compared.
abstract class Ears {
  Future<bool> hasPermission();
  Future<void> start();

  /// Stops listening and returns what was understood ('' if nothing).
  Future<String> stop();
}

/// Speaks a character's line out loud; completes when playback ends.
abstract class Mouth {
  Future<void> say(
    String text, {
    required Voice voice,
    required double speed,
    String speaker = '',
  });
  Future<void> stop();
}

/// Whisper through sherpa-onnx, recording to a WAV file first.
class WhisperEars implements Ears {
  WhisperEars(this._audio, this._speech);

  final Audio _audio;
  final Speech _speech;

  @override
  Future<bool> hasPermission() => _audio.hasMicPermission();

  @override
  Future<void> start() => _audio.startRecording();

  @override
  Future<String> stop() async {
    final path = await _audio.stopRecording();
    if (path == null) return '';
    return _speech.transcribe(path);
  }
}

/// Piper through sherpa-onnx. Remembers rendered lines so replays are instant.
class PiperMouth implements Mouth {
  PiperMouth(this._audio, this._speech);

  final Audio _audio;
  final Speech _speech;
  final _cache = <String, String>{};

  @override
  Future<void> say(
    String text, {
    required Voice voice,
    required double speed,
    String speaker = '',
  }) async {
    final key = '${voice.name}|$speed|$text';
    var path = _cache[key];
    if (path == null) {
      path = _audio.newWavPath('say');
      await _speech.synthesize(text, voice, speed, path);
      _cache[key] = path;
    }
    await _audio.play(path);
  }

  @override
  Future<void> stop() => _audio.stopPlayback();
}
