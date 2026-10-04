import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Microphone in, speaker out. Both use the same iOS audio session
/// (play-and-record, routed to the loudspeaker) so playback stays loud
/// after the child has used the mic.
class Audio {
  Audio._(this._dir);

  final String _dir;
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  int _n = 0;

  static Future<Audio> create() async {
    final dir = await getTemporaryDirectory();
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
        respectSilence: false,
      ).build(),
    );
    return Audio._(dir.path);
  }

  String newWavPath(String tag) => '$_dir/${tag}_${_n++}.wav';

  Future<bool> hasMicPermission() => _recorder.hasPermission();

  Future<void> startRecording() async {
    await _player.stop();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
      ),
      path: newWavPath('mic'),
    );
  }

  /// Returns the WAV path, or null if nothing was recorded.
  Future<String?> stopRecording() => _recorder.stop();

  Future<bool> get isRecording => _recorder.isRecording();

  /// Plays a WAV file and completes when playback ends.
  Future<void> play(String path) async {
    final done = Completer<void>();
    late StreamSubscription<void> sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    await _player.play(DeviceFileSource(path));
    await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
    await sub.cancel();
  }

  Future<void> stopPlayback() => _player.stop();

  Future<void> cleanup() async {
    for (final f in Directory(_dir).listSync()) {
      if (f.path.endsWith('.wav')) f.deleteSync();
    }
  }
}
