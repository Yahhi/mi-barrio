import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import '../game/missions.dart' show Voice;

/// Where every on-device model lives, and how it gets there.
///
/// - Gemma 4 E2B (2.6 GB): downloaded once from Hugging Face by flutter_gemma.
/// - Whisper small (375 MB): downloaded once from Hugging Face.
/// - Piper voices (130 MB) + espeak-ng data: bundled in the app, copied out
///   on first launch because sherpa-onnx needs real file paths.
class ModelFiles {
  ModelFiles._(this.root);

  final String root;

  static Future<ModelFiles> open() async {
    final dir = await getApplicationSupportDirectory();
    return ModelFiles._(dir.path);
  }

  static const gemmaUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';
  static const _gemmaBytes = 2588147712;

  static const _whisperBase =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/';
  static const _whisperFiles = {
    'small-encoder.int8.onnx': 112442483,
    'small-decoder.int8.onnx': 262226114,
    'small-tokens.txt': 0,
  };

  String get whisperDir => '$root/whisper';
  String get whisperEncoder => '$whisperDir/small-encoder.int8.onnx';
  String get whisperDecoder => '$whisperDir/small-decoder.int8.onnx';
  String get whisperTokens => '$whisperDir/small-tokens.txt';

  String get ttsDir => '$root/tts';
  String get espeakDir => '$ttsDir/espeak-ng-data';
  String voiceModel(Voice v) => switch (v) {
    Voice.daniela => '$ttsDir/es_AR-daniela-high.onnx',
    Voice.ald => '$ttsDir/es_MX-ald-medium.onnx',
  };
  String voiceTokens(Voice v) => '$ttsDir/tokens_${v.name}.txt';

  /// Copies bundled voices out of the app bundle. Fast after the first run.
  Future<void> ensureVoices() async {
    await Directory(ttsDir).create(recursive: true);
    for (final f in [
      'es_AR-daniela-high.onnx',
      'es_MX-ald-medium.onnx',
      'tokens_daniela.txt',
      'tokens_ald.txt',
    ]) {
      final out = File('$ttsDir/$f');
      if (await out.exists()) continue;
      final data = await rootBundle.load('assets/tts/$f');
      await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    if (!await Directory(espeakDir).exists()) {
      final data = await rootBundle.load('assets/tts/espeak-ng-data.zip');
      final archive = ZipDecoder().decodeBytes(data.buffer.asUint8List());
      for (final file in archive) {
        final path = '$ttsDir/${file.name}';
        if (file.isFile) {
          final out = File(path);
          await out.parent.create(recursive: true);
          await out.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(path).create(recursive: true);
        }
      }
    }
  }

  Future<bool> whisperReady() async {
    for (final f in _whisperFiles.keys) {
      if (!await File('$whisperDir/$f').exists()) return false;
    }
    return true;
  }

  /// Downloads Whisper files; [onBytes] gets the running byte count.
  Future<void> ensureWhisper(void Function(int bytes) onBytes) async {
    await Directory(whisperDir).create(recursive: true);
    var done = 0;
    final client = HttpClient();
    try {
      for (final entry in _whisperFiles.entries) {
        final target = File('$whisperDir/${entry.key}');
        if (await target.exists()) {
          done += entry.value;
          onBytes(done);
          continue;
        }
        final part = File('${target.path}.part');
        final req = await client.getUrl(Uri.parse('$_whisperBase${entry.key}'));
        final res = await req.close();
        if (res.statusCode != 200) {
          throw HttpException('HTTP ${res.statusCode} for ${entry.key}');
        }
        final sink = part.openWrite();
        await for (final chunk in res) {
          sink.add(chunk);
          done += chunk.length;
          onBytes(done);
        }
        await sink.close();
        await part.rename(target.path);
      }
    } finally {
      client.close();
    }
  }

  /// Installs (or just re-activates) Gemma. [onPercent] is 0..100.
  Future<void> ensureGemma(void Function(int percent) onPercent) async {
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(gemmaUrl).withProgress(onPercent).install();
  }

  static const totalDownloadBytes = _gemmaBytes + 112442483 + 262226114;
}
