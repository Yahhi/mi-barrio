/// Game content: missions, their goals, hints and stickers.
///
/// Goals are checked with keywords on the child's transcript (see
/// [Goal.isMetBy]), so progress is instant and predictable. The language
/// model only plays the character.
library;

class Goal {
  const Goal({
    required this.id,
    required this.titleRu,
    required this.hintEs,
    required this.hintRu,
    required this.keywordGroups,
  });

  final String id;
  final String titleRu;
  final String hintEs;
  final String hintRu;

  /// Every group must match; inside a group any keyword is enough.
  /// Keywords are matched against the normalized transcript (lowercase,
  /// no accents, no punctuation).
  final List<List<String>> keywordGroups;

  bool isMetBy(String utterance) {
    final text = ' ${normalize(utterance)} ';
    final words = text.trim().split(' ');
    return keywordGroups.every(
      (group) => group.any((k) => _matches(normalize(k), text, words)),
    );
  }

  /// Exact substring, or — for single long words — a near miss, because
  /// children mispronounce and Whisper misspells ("medielunas").
  static bool _matches(String keyword, String text, List<String> words) {
    if (text.contains(keyword)) return true;
    final k = keyword.trim();
    if (k.contains(' ') || k.length < 6) return false;
    final allowed = k.length >= 8 ? 2 : 1;
    for (final w in words) {
      if ((w.length - k.length).abs() > allowed + 1) continue;
      final stem = w.endsWith('s') ? w.substring(0, w.length - 1) : w;
      if (_distance(w, k) <= allowed || _distance(stem, k) <= allowed) {
        return true;
      }
    }
    return false;
  }
}

class Sticker {
  const Sticker(this.id, this.nameEs, this.nameRu);

  final String id;
  final String nameEs;
  final String nameRu;

  String get asset => 'assets/images/stickers/$id.png';
}

enum Voice { daniela, ald }

class Mission {
  const Mission({
    required this.id,
    required this.placeEs,
    required this.placeRu,
    required this.character,
    required this.characterImage,
    required this.background,
    required this.voice,
    required this.speed,
    required this.introRu,
    required this.openerEs,
    required this.persona,
    required this.goals,
    required this.stickerIds,
    required this.farewellEs,
  });

  final String id;
  final String placeEs;
  final String placeRu;
  final String character;
  final String characterImage;
  final String background;
  final Voice voice;
  final double speed;
  final String introRu;

  /// First line the character says, pre-written so the scene starts instantly.
  final String openerEs;

  /// Who the character is and what the shop sells, for the system prompt.
  final String persona;
  final List<Goal> goals;

  /// Awarded by stars: 1★ → first, 2★ → first two, 3★ → all three.
  final List<String> stickerIds;
  final String farewellEs;
}

const _greet = Goal(
  id: 'greet',
  titleRu: 'Поздоровайся',
  hintEs: '¡Hola! ¡Buen día!',
  hintRu: 'Привет! Доброе утро!',
  keywordGroups: [
    [
      ' hola',
      'buen dia',
      'buenos dias',
      'buenas',
      'que tal',
      'como estas',
      'como andas',
    ],
  ],
);

const _askPrice = Goal(
  id: 'price',
  titleRu: 'Спроси, сколько стоит',
  hintEs: '¿Cuánto es?',
  hintRu: 'Сколько это стоит?',
  keywordGroups: [
    ['cuanto', 'precio', 'cuesta', 'sale ', 'vale '],
  ],
);

const _rules = '''
Rules:
- Speak ONLY Rioplatense Spanish from Buenos Aires. Always use voseo: "vos querés", "vos tenés", "¿qué querés?", "mirá", "decime", "dale". Never use "tú" or "vosotros".
- The child is 9-10 years old, learning Spanish; their first language is Russian. Use very simple, common words.
- Reply with 1 or 2 short sentences, at most 20 words in total.
- Stay in character and in the shop. Talk only about the shop, its products and the purchase.
- Be warm and encouraging. If the child makes a mistake, do not correct them; just answer naturally, using the correct words yourself.
- If the child speaks Russian, says something unclear, or seems stuck, say kindly and simply that you did not understand, and ask again with an easy question.
- Never ask for personal information (full name, address, school, phone). Never talk about anything scary, violent or for adults.
- Never add up a total: when asked how much it is, say the price of each item the child wants, one by one. Say prices in words, for example "quinientos pesos". No digits, no emojis, no lists, no stage directions, no translations. Write only what you say out loud.''';

String systemPromptFor(Mission m) => '${m.persona}\n$_rules';

const missions = <Mission>[
  Mission(
    id: 'panaderia',
    placeEs: 'La panadería',
    placeRu: 'Пекарня',
    character: 'Doña Rosa',
    characterImage: 'assets/images/characters/rosa.png',
    background: 'assets/images/backgrounds/panaderia.png',
    voice: Voice.daniela,
    speed: 0.92,
    introRu: 'Ты в пекарне доньи Росы. Купи завтрак для всей семьи!',
    openerEs: '¡Buen día, corazón! Pasá, pasá. ¿Qué querés llevar hoy?',
    persona:
        'You are Doña Rosa, a sweet grandmotherly baker in your small panadería in Buenos Aires. '
        'You call children "corazón" or "querido/querida". '
        'You sell: medialunas (quinientos pesos each), alfajores de maicena (mil pesos each), '
        'bolas de fraile (ochocientos pesos each) and pan francés (dos mil pesos the kilo). ',
    goals: [
      _greet,
      Goal(
        id: 'medialunas',
        titleRu: 'Попроси 3 медиалуны (medialunas)',
        hintEs: '¿Me das tres medialunas, por favor?',
        hintRu: 'Дайте мне, пожалуйста, три медиалуны.',
        keywordGroups: [
          ['medialuna', 'media luna'],
          ['tres', ' 3 '],
        ],
      ),
      Goal(
        id: 'alfajor',
        titleRu: 'Купи ещё альфахор (alfajor)',
        hintEs: 'Y también un alfajor de maicena.',
        hintRu: 'И ещё один альфахор, пожалуйста.',
        keywordGroups: [
          ['alfajor', 'alfajores'],
        ],
      ),
      _askPrice,
      _byeRosa,
    ],
    stickerIds: ['medialuna', 'alfajor_maicena', 'bola_fraile'],
    farewellEs: '¡Chau, corazón! ¡Que las disfrutes!',
  ),
  Mission(
    id: 'kiosco',
    placeEs: 'El kiosco',
    placeRu: 'Киоск',
    character: 'Tito',
    characterImage: 'assets/images/characters/tito.png',
    background: 'assets/images/backgrounds/kiosco.png',
    voice: Voice.ald,
    speed: 1.0,
    introRu: 'Это киоск Тито. Здесь продают сладости и карточки для альбома!',
    openerEs: '¡Hola, che! ¿Todo bien? ¿Qué andás buscando?',
    persona:
        'You are Tito, a cheerful young man who runs a kiosco on a street corner in Buenos Aires. '
        'You are funny and relaxed, you say "che" and "dale". '
        'You sell: caramelos (cien pesos each), alfajores de chocolate (mil doscientos pesos), '
        'chicles (trescientos pesos) and sobres de figuritas for the football sticker album '
        '(mil quinientos pesos each pack).',
    goals: [
      _greet,
      Goal(
        id: 'figuritas',
        titleRu: 'Спроси, есть ли карточки (figuritas)',
        hintEs: '¿Tenés figuritas?',
        hintRu: 'У тебя есть фигуритас (карточки)?',
        keywordGroups: [
          ['figurita'],
        ],
      ),
      Goal(
        id: 'caramelos',
        titleRu: 'Купи конфеты (caramelos)',
        hintEs: 'Quiero cinco caramelos, por favor.',
        hintRu: 'Я хочу пять конфет, пожалуйста.',
        keywordGroups: [
          ['caramelo'],
        ],
      ),
      _askPrice,
      _byeTito,
    ],
    stickerIds: ['caramelos', 'alfajor_chocolate', 'figuritas'],
    farewellEs: '¡Dale, nos vemos! ¡Chau!',
  ),
  Mission(
    id: 'heladeria',
    placeEs: 'La heladería',
    placeRu: 'Кафе-мороженое',
    character: 'Mili',
    characterImage: 'assets/images/characters/mili.png',
    background: 'assets/images/backgrounds/heladeria.png',
    voice: Voice.daniela,
    speed: 1.05,
    introRu: 'Жарко! Зайди к Мили и закажи себе мороженое.',
    openerEs: '¡Hola! Bienvenido a la heladería. ¿Qué te sirvo?',
    persona:
        'You are Mili, a friendly young woman who works in an ice-cream shop (heladería) in Buenos Aires. '
        'Flavors (gustos): dulce de leche, chocolate, frutilla, vainilla, limón, menta and sambayón. '
        'Sizes: cucurucho (cone, mil quinientos pesos, up to two gustos) and vasito '
        '(small cup, mil doscientos pesos, up to two gustos). '
        'Ask the child "¿cucurucho o vasito?" and "¿qué gustos querés?" when it helps the conversation.',
    goals: [
      _greet,
      Goal(
        id: 'gustos',
        titleRu: 'Спроси, какие есть вкусы (gustos)',
        hintEs: '¿Qué gustos tenés?',
        hintRu: 'Какие у тебя есть вкусы?',
        keywordGroups: [
          ['gusto', 'sabor'],
        ],
      ),
      Goal(
        id: 'cucurucho',
        titleRu: 'Выбери рожок или стаканчик',
        hintEs: 'Quiero un cucurucho, por favor.',
        hintRu: 'Я хочу рожок, пожалуйста.',
        keywordGroups: [
          ['cucurucho', 'cono', 'vasito', 'vaso'],
        ],
      ),
      Goal(
        id: 'flavor',
        titleRu: 'Назови вкус мороженого',
        hintEs: 'De dulce de leche y chocolate.',
        hintRu: 'Дульсе де лече и шоколад.',
        keywordGroups: [
          [
            'dulce de leche',
            'chocolate',
            'frutilla',
            'vainilla',
            'limon',
            'menta',
            'sambayon',
            'crema',
          ],
        ],
      ),
      _byeMili,
    ],
    stickerIds: ['cucurucho', 'vasito', 'pote_helado'],
    farewellEs: '¡Que lo disfrutes! ¡Chau, chau!',
  ),
];

const _byeRosa = Goal(
  id: 'bye',
  titleRu: 'Скажи спасибо и попрощайся',
  hintEs: '¡Muchas gracias, Doña Rosa! ¡Chau!',
  hintRu: 'Большое спасибо, донья Роса! Пока!',
  keywordGroups: [
    ['gracias', 'chau', 'adios', 'hasta luego', 'nos vemos', 'hasta manana'],
  ],
);
const _byeTito = Goal(
  id: 'bye',
  titleRu: 'Скажи спасибо и попрощайся',
  hintEs: '¡Gracias, Tito! ¡Chau!',
  hintRu: 'Спасибо, Тито! Пока!',
  keywordGroups: [
    ['gracias', 'chau', 'adios', 'hasta luego', 'nos vemos', 'hasta manana'],
  ],
);
const _byeMili = Goal(
  id: 'bye',
  titleRu: 'Скажи спасибо и попрощайся',
  hintEs: '¡Gracias, Mili! ¡Chau!',
  hintRu: 'Спасибо, Мили! Пока!',
  keywordGroups: [
    ['gracias', 'chau', 'adios', 'hasta luego', 'nos vemos', 'hasta manana'],
  ],
);

/// Bonus stickers that are not tied to a single mission.
const firstMissionSticker = 'copo_sticker';
const allMissionsSticker = 'mate';
const allPerfectSticker = 'colectivo';

const stickers = <Sticker>[
  Sticker('medialuna', 'medialuna', 'медиалуна — аргентинский круассан'),
  Sticker('alfajor_maicena', 'alfajor de maicena', 'альфахор с дульсе де лече'),
  Sticker('bola_fraile', 'bola de fraile', 'пончик «бола де фраиле»'),
  Sticker('caramelos', 'caramelos', 'конфеты'),
  Sticker('alfajor_chocolate', 'alfajor de chocolate', 'шоколадный альфахор'),
  Sticker('figuritas', 'figuritas', 'карточки для альбома'),
  Sticker('cucurucho', 'cucurucho', 'рожок мороженого'),
  Sticker('vasito', 'vasito', 'стаканчик мороженого'),
  Sticker('pote_helado', 'pote de helado', 'коробка мороженого'),
  Sticker('copo_sticker', 'Copo', 'Копо — твой друг-самоед'),
  Sticker('mate', 'mate', 'мате — аргентинский чай'),
  Sticker('colectivo', 'colectivo', 'городской автобус'),
];

Sticker stickerById(String id) => stickers.firstWhere((s) => s.id == id);

int _distance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Lowercase, strip accents and punctuation, collapse spaces.
String normalize(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    if (i >= 0) {
      buf.write(to[i]);
    } else if (RegExp(r'[a-z0-9 ]').hasMatch(ch)) {
      buf.write(ch);
    } else {
      buf.write(' ');
    }
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
}
