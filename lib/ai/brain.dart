import 'package:flutter_gemma/flutter_gemma.dart';

/// Gemma 4 E2B, running on the phone. Plays one character per mission and
/// translates lines into Russian on request.
class Brain {
  Brain._(this._model);

  final InferenceModel _model;
  InferenceChat? _scene;

  static Future<Brain> load() async {
    final model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.gpu,
    );
    return Brain._(model);
  }

  /// Starts a fresh conversation for a mission. [opener] is the line the
  /// character already said, so the model knows how the scene began.
  Future<void> startScene(String systemPrompt, String opener) async {
    await _scene?.close();
    _scene = await _model.openChat(
      systemInstruction: systemPrompt,
      temperature: 0.7,
      topK: 40,
      topP: 0.95,
      randomSeed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      maxOutputTokens: 80,
      modelType: ModelType.gemma4,
    );
    _opener = opener;
  }

  String? _opener;

  /// Streams the character's reply to what the child said.
  Stream<String> reply(String childSaid) async* {
    final chat = _scene!;
    var text = childSaid;
    if (_opener != null) {
      // Give the model the scene's first line as context on the first turn.
      text =
          '(You already greeted the child with: "$_opener")\nChild: $childSaid';
      _opener = null;
    }
    await chat.addQueryChunk(Message.text(text: text, isUser: true));
    await for (final r in chat.generateChatResponseAsync()) {
      if (r is TextResponse) yield r.token;
    }
  }

  /// One-off Spanish → Russian translation for the 🇷🇺 button.
  Future<String> translateToRussian(String spanish) async {
    final chat = await _model.openChat(
      systemInstruction:
          'You translate Spanish into simple, natural Russian for a 9-year-old child. '
          'Reply with only the Russian translation, nothing else.',
      temperature: 0.1,
      topK: 1,
      maxOutputTokens: 120,
      modelType: ModelType.gemma4,
    );
    try {
      await chat.addQueryChunk(Message.text(text: spanish, isUser: true));
      final buf = StringBuffer();
      await for (final r in chat.generateChatResponseAsync()) {
        if (r is TextResponse) buf.write(r.token);
      }
      return buf.toString().trim();
    } finally {
      await chat.close();
    }
  }

  /// Second opinion when keywords miss: did the child complete this goal?
  /// Asked in a fresh session so it does not disturb the character.
  Future<bool> judgeGoal({
    required String goalRu,
    required String exampleEs,
    required String childSaid,
  }) async {
    final chat = await _model.openChat(
      systemInstruction: 'You check a language-learning game for children. Answer with exactly one word: yes or no.',
      temperature: 0,
      topK: 1,
      maxOutputTokens: 4,
      modelType: ModelType.gemma4,
    );
    try {
      await chat.addQueryChunk(
        Message.text(
          text:
              'Task for the child (in Russian): "$goalRu". Example of a correct answer: "$exampleEs".\n'
              'Speech recognition wrote what the child said, possibly with spelling mistakes: "$childSaid".\n'
              'Did the child clearly do the task? Ignore spelling and small grammar mistakes, '
              'but a wrong item or a wrong number is "no".',
          isUser: true,
        ),
      );
      final buf = StringBuffer();
      await for (final r in chat.generateChatResponseAsync()) {
        if (r is TextResponse) buf.write(r.token);
      }
      return buf.toString().trim().toLowerCase().startsWith('y');
    } finally {
      await chat.close();
    }
  }

  /// Copo retells a plant's verified facts as a tiny story for a child.
  /// Only the given facts may be used: no new claims, never food or medicine.
  Future<String> copoTells({
    required String nameRu,
    required String nameEs,
    required String facts,
  }) async {
    final chat = await _model.openChat(
      systemInstruction:
          'You are Copo, a cheerful Samoyed puppy who explores Buenos Aires with a 9-10-year-old child. '
          'Write in simple, natural Russian: exactly 2 short sentences, at most 40 words. '
          'Sentence 1: retell the most surprising of the given facts in your own playful words. '
          'Sentence 2: invite the child to notice or check one thing on the real plant (leaves, flowers, bark, trunk). '
          'No greeting, no "привет", do not call the plant beautiful. '
          'Use ONLY the given facts; do not add any other facts, numbers or names. '
          'Never say a plant can be eaten, tasted, or used as medicine. Address the child as "ты".',
      temperature: 0.6,
      topK: 40,
      maxOutputTokens: 120,
      modelType: ModelType.gemma4,
    );
    try {
      await chat.addQueryChunk(
        Message.text(
          text: 'Plant: $nameRu ($nameEs). Facts: $facts',
          isUser: true,
        ),
      );
      final buf = StringBuffer();
      await for (final r in chat.generateChatResponseAsync()) {
        if (r is TextResponse) buf.write(r.token);
      }
      return cleanForSpeech(buf.toString());
    } finally {
      await chat.close();
    }
  }

  Future<void> endScene() async {
    await _scene?.close();
    _scene = null;
  }
}

/// Removes things a TTS voice should not read aloud.
String cleanForSpeech(String s) => s
    .replaceAll(RegExp(r'\*[^*]*\*'), '') // *stage directions*
    .replaceAll(RegExp(r'\([^)]*\)'), '')
    .replaceAll(
      RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]', unicode: true),
      '',
    )
    .replaceAll(RegExp(r'^\s*(Doña Rosa|Rosa|Tito|Mili)\s*:\s*'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
