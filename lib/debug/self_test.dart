import 'package:flutter/foundation.dart';

import '../ai/brain.dart';
import '../app.dart';
import '../game/missions.dart';

/// Run with --dart-define=SELFTEST=true. Exercises voice → ears → brain
/// without a microphone and prints timings, so the pipeline can be checked
/// on a simulator or a new device.
Future<void> runSelfTest() async {
  final sw = Stopwatch()..start();
  void log(String s) => debugPrint('[SELFTEST ${sw.elapsedMilliseconds}ms] $s');

  final m = missions.first;
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
    final met = m.goals
        .where((g) => g.isMetBy(heard))
        .map((g) => g.id)
        .toList();
    log('goals met: $met');

    if (phrase == missions.first.goals.first.hintEs || met.contains('greet')) {
      await services.brain.startScene(systemPromptFor(m), m.openerEs);
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
