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
