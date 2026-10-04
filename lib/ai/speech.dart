import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../game/missions.dart' show Voice;
import 'model_files.dart';

/// Speech recognition (Whisper) and speech synthesis (Piper), both through
/// sherpa-onnx, running in a long-lived background isolate so decoding never
/// freezes the UI.
class Speech {
  Speech._(this._send, this._isolate);

  final SendPort _send;
  final Isolate _isolate;
  int _nextId = 0;

  static Future<Speech> start(ModelFiles files) async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_workerMain, ready.sendPort);
    final send = await ready.first as SendPort;

    final speech = Speech._(send, isolate);
    await speech._call({
      'cmd': 'init',
      'whisperEncoder': files.whisperEncoder,
      'whisperDecoder': files.whisperDecoder,
      'whisperTokens': files.whisperTokens,
      'espeak': files.espeakDir,
      for (final v in Voice.values) ...{
        'model_${v.name}': files.voiceModel(v),
        'tokens_${v.name}': files.voiceTokens(v),
      },
    });
    return speech;
  }

  /// Transcribes a 16 kHz mono WAV file to Spanish text.
  Future<String> transcribe(String wavPath) async =>
      (await _call({'cmd': 'stt', 'wav': wavPath})) as String;

  /// Speaks [text] into a WAV file at [outPath].
  Future<void> synthesize(
    String text,
    Voice voice,
    double speed,
    String outPath,
  ) => _call({
    'cmd': 'tts',
    'text': text,
    'voice': voice.name,
    'speed': speed,
    'out': outPath,
  });

  Future<Object?> _call(Map<String, Object?> msg) async {
    final reply = ReceivePort();
    _send.send({...msg, 'id': _nextId++, 'reply': reply.sendPort});
    final res = await reply.first as Map;
    reply.close();
    if (res['error'] != null) throw Exception(res['error']);
    return res['result'];
  }

  void dispose() => _isolate.kill();
}

void _workerMain(SendPort ready) {
  final inbox = ReceivePort();
  ready.send(inbox.sendPort);

  sherpa.OfflineRecognizer? recognizer;
  final tts = <String, sherpa.OfflineTts>{};
  late Map config;

  sherpa.OfflineTts ttsFor(String voice) => tts.putIfAbsent(voice, () {
    return sherpa.OfflineTts(
      sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: config['model_$voice'] as String,
            tokens: config['tokens_$voice'] as String,
            dataDir: config['espeak'] as String,
          ),
          numThreads: 2,
          debug: false,
        ),
      ),
    );
  });

  inbox.listen((raw) {
    final msg = raw as Map;
    final reply = msg['reply'] as SendPort;
    try {
      switch (msg['cmd']) {
        case 'init':
          sherpa.initBindings();
          config = msg;
          recognizer = sherpa.OfflineRecognizer(
            sherpa.OfflineRecognizerConfig(
              model: sherpa.OfflineModelConfig(
                whisper: sherpa.OfflineWhisperModelConfig(
                  encoder: msg['whisperEncoder'] as String,
                  decoder: msg['whisperDecoder'] as String,
                  language: 'es',
                  task: 'transcribe',
                ),
                tokens: msg['whisperTokens'] as String,
                modelType: 'whisper',
                numThreads: 2,
                debug: false,
              ),
            ),
          );
          // Warm up the main voice so the first line plays without delay.
          ttsFor(Voice.daniela.name);
          reply.send({'result': null});
        case 'stt':
          final wave = sherpa.readWave(msg['wav'] as String);
          if (wave.samples.isEmpty) {
            reply.send({'result': ''});
            return;
          }
          // Whisper clips the last word of short phrases; silence on both
          // sides fixes it ("¿Cuánto es?" came back as "¿Cuánt").
          final rate = wave.sampleRate;
          final padded = Float32List(
            wave.samples.length + rate * 3 ~/ 2,
          )..setRange(rate ~/ 2, rate ~/ 2 + wave.samples.length, wave.samples);
          final stream = recognizer!.createStream();
          stream.acceptWaveform(samples: padded, sampleRate: rate);
          recognizer!.decode(stream);
          final text = recognizer!.getResult(stream).text.trim();
          stream.free();
          reply.send({'result': text});
        case 'tts':
          final audio = ttsFor(msg['voice'] as String).generate(
            text: msg['text'] as String,
            speed: (msg['speed'] as num).toDouble(),
          );
          sherpa.writeWave(
            filename: msg['out'] as String,
            samples: audio.samples,
            sampleRate: audio.sampleRate,
          );
          reply.send({'result': null});
      }
    } catch (e) {
      reply.send({'error': e.toString()});
    }
  });
}
