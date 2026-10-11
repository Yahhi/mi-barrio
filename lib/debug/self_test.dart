import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../ai/brain.dart';
import '../app.dart';
import '../game/missions.dart';

/// Run with --dart-define=SELFTEST=true. Exercises voice → ears → brain
/// without a microphone and prints timings, so the pipeline can be checked
/// on a simulator or a new device.
Future<void> runSelfTest() async {
  final sw = Stopwatch()..start();
  void log(String s) => debugPrint('[SELFTEST ${sw.elapsedMilliseconds}ms] $s');

  final run = MissionRun(missions.first, 0);
  final m = run.mission;
  for (final phrase in [
    'Hola, buen día. ¿Me das tres medialunas, por favor?',
    '¿Cuánto es?',
  ]) {
    final wav = services.audio.newWavPath('selftest');
    var t = sw.elapsedMilliseconds;
    await services.speech.synthesize(phrase, Voice.daniela, 1.0, wav);
    log('TTS ${sw.elapsedMilliseconds - t}ms: "$phrase"');

    t = sw.elapsedMilliseconds;
    final heard = await services.speech.transcribe(wav);
    log('STT ${sw.elapsedMilliseconds - t}ms: "$heard"');
    final met = run.goals
        .where((g) => g.isMetBy(heard))
        .map((g) => g.id)
        .toList();
    log('goals met: $met');

    if (phrase == run.goals.first.hintEs || met.contains('greet')) {
      await services.brain.startScene(run.systemPrompt, m.openerEs);
    }
    t = sw.elapsedMilliseconds;
    var first = -1;
    final buf = StringBuffer();
    await for (final tok in services.brain.reply(heard)) {
      if (first < 0) first = sw.elapsedMilliseconds - t;
      buf.write(tok);
    }
    log(
      'LLM first token ${first}ms, total ${sw.elapsedMilliseconds - t}ms: "${cleanForSpeech(buf.toString())}"',
    );
  }
  final t = sw.elapsedMilliseconds;
  final ru = await services.brain.translateToRussian(
    '¡Buen día, corazón! ¿Qué querés llevar hoy?',
  );
  log('translate ${sw.elapsedMilliseconds - t}ms: "$ru"');
  log('DONE');
}

/// Run with --dart-define=PLANT_TEST=true after copying photos into the app's
/// Documents/plant_test folder. Prints the top 3 per photo, to compare with
/// the Python evaluation on the same images.
Future<void> runPlantTest() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/plant_test');
  if (!dir.existsSync()) return;
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final sw = Stopwatch()..start();
    final r = await services.plantEyes.identify(f.path);
    debugPrint(
      '[PLANT] ${f.path.split('/').last} ${sw.elapsedMilliseconds}ms '
      '${r.guesses.map((g) => '${g.id}:${g.score.toStringAsFixed(3)}').join(' ')} '
      'conf=${r.confident}',
    );
  }
}
