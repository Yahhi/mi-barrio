/// Game content: missions, their goals, hints and stickers.
///
/// Goals are checked with keywords on the child's transcript (see
/// [Goal.isMetBy]), so progress is instant and predictable. The language
/// model only plays the character.
library;

import 'dart:math';

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

/// One version of a mission. Every visit picks a variant at random, so the
/// task changes a little each time: other quantities, other items, a twist.
class Variant {
  const Variant({required this.introRu, required this.goals, this.twist = ''});

  final String introRu;

  /// The goals between the greeting and the goodbye.
  final List<Goal> goals;

  /// Extra instruction for the character, e.g. "today you ran out of X".
  final String twist;
}

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
    required this.openerEs,
    required this.persona,
    required this.variants,
    required this.stickerIds,
    this.greet = _greet,
  });

  final String id;
  final String placeEs;
  final String placeRu;
  final String character;
  final String characterImage;
  final String background;
  final Voice voice;
  final double speed;

  /// First line the character says, pre-written so the scene starts instantly.
  final String openerEs;

  /// Who the character is and what they sell or do, for the system prompt.
  final String persona;
  final List<Variant> variants;
  final Goal greet;

  /// Awarded by stars: 1★ → first, 2★ → first two, 3★ → all three.
  final List<String> stickerIds;

  Goal get bye => Goal(
    id: 'bye',
    titleRu: 'Скажи спасибо и попрощайся',
    hintEs: '¡Muchas gracias, $character! ¡Chau!',
    hintRu: 'Большое спасибо! Пока!',
    keywordGroups: const [
      ['gracias', 'chau', 'adios', 'hasta luego', 'nos vemos', 'hasta manana'],
    ],
  );
}

/// A mission as played this time: one variant, its goals and its prompt.
class MissionRun {
  MissionRun(this.mission, this.variantIndex);

  /// Picks a random variant, avoiding [lastIndex] when there is a choice.
  factory MissionRun.pick(Mission m, {int? lastIndex, Random? random}) {
    final r = random ?? Random();
    var i = r.nextInt(m.variants.length);
    if (m.variants.length > 1 && i == lastIndex) {
      i = (i + 1 + r.nextInt(m.variants.length - 1)) % m.variants.length;
    }
    return MissionRun(m, i);
  }

  final Mission mission;
  final int variantIndex;

  Variant get variant => mission.variants[variantIndex];
  String get introRu => variant.introRu;
  List<Goal> get goals => [mission.greet, ...variant.goals, mission.bye];

  String get systemPrompt => [
    mission.persona,
    if (variant.twist.isNotEmpty) 'Today: ${variant.twist}',
    _rules,
  ].join('\n');
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

const _greetKid = Goal(
  id: 'greet',
  titleRu: 'Поздоровайся',
  hintEs: '¡Hola! ¿Qué tal?',
  hintRu: 'Привет! Как дела?',
  keywordGroups: [
    [
      ' hola',
      'buenas',
      'que tal',
      'como estas',
      'como andas',
      'buen dia',
      'buenos dias',
    ],
  ],
);

Goal _price([String hintEs = '¿Cuánto es?']) => Goal(
  id: 'price',
  titleRu: 'Спроси, сколько стоит',
  hintEs: hintEs,
  hintRu: 'Сколько это стоит?',
  keywordGroups: const [
    ['cuanto', 'precio', 'cuesta', 'sale ', 'vale '],
  ],
);

/// Spoken and written forms of small numbers, for "three medialunas" goals.
List<String> _num(int n) => switch (n) {
  1 => [' un ', ' una ', ' uno ', ' 1 '],
  2 => [' dos ', ' 2 ', ' par '],
  3 => [' tres ', ' 3 '],
  4 => [' cuatro ', ' 4 '],
  5 => [' cinco ', ' 5 '],
  6 => [' seis ', ' 6 ', 'media docena'],
  _ => [' $n '],
};

const _numRu = {
  1: 'одну',
  2: 'две',
  3: 'три',
  4: 'четыре',
  5: 'пять',
  6: 'шесть',
};
const _numEs = {
  1: 'una',
  2: 'dos',
  3: 'tres',
  4: 'cuatro',
  5: 'cinco',
  6: 'seis',
};

Goal _medialunas(int n) => Goal(
  id: 'medialunas',
  titleRu: 'Попроси $n медиалун${n < 5 ? 'ы' : ''} (medialunas)',
  hintEs: '¿Me das ${_numEs[n]} medialunas, por favor?',
  hintRu: 'Дайте мне, пожалуйста, ${_numRu[n]} медиалун${n < 5 ? 'ы' : ''}.',
  keywordGroups: [
    ['medialuna', 'media luna'],
    _num(n),
  ],
);

const _rules = '''
Rules:
- Speak ONLY Rioplatense Spanish from Buenos Aires. Always use voseo: "vos querés", "vos tenés", "¿qué querés?", "mirá", "decime", "dale". Never use "tú" or "vosotros".
- The child is 9-10 years old, learning Spanish; their first language is Russian. Use very simple, common words.
- Reply with 1 or 2 short sentences, at most 20 words in total.
- Stay in character and in this place. Talk only about what happens here.
- Be warm and encouraging. If the child makes a mistake, do not correct them; just answer naturally, using the correct words yourself.
- If the child speaks Russian, says something unclear, or seems stuck, say kindly and simply that you did not understand, and ask an easy question that helps them continue.
- Never ask for personal information (full name, address, school, phone). Never talk about anything scary, violent or for adults.
- If you sell something: never add up a total; when asked how much it is, say the price of each item one by one. Say numbers in words, for example "quinientos pesos". No digits, no emojis, no lists, no stage directions, no translations. Write only what you say out loud.''';

final missions = <Mission>[
  Mission(
    id: 'panaderia',
    placeEs: 'La panadería',
    placeRu: 'Пекарня',
    character: 'Doña Rosa',
    characterImage: 'assets/images/characters/rosa.png',
    background: 'assets/images/backgrounds/panaderia.png',
    voice: Voice.daniela,
    speed: 0.92,
    openerEs: '¡Buen día, corazón! Pasá, pasá. ¿Qué querés llevar hoy?',
    persona:
        'You are Doña Rosa, a sweet grandmotherly baker in your small panadería in Buenos Aires. '
        'You call children "corazón" or "querido/querida". '
        'You sell: medialunas (quinientos pesos each), alfajores de maicena (mil pesos each), '
        'bolas de fraile (ochocientos pesos each) and pan francés (dos mil pesos the kilo).',
    variants: [
      Variant(
        introRu:
            'Ты в пекарне доньи Росы. Купи завтрак: три медиалуны и альфахор!',
        goals: [
          _medialunas(3),
          const Goal(
            id: 'alfajor',
            titleRu: 'Купи ещё альфахор (alfajor)',
            hintEs: 'Y también un alfajor de maicena.',
            hintRu: 'И ещё один альфахор, пожалуйста.',
            keywordGroups: [
              ['alfajor'],
            ],
          ),
          _price(),
        ],
      ),
      Variant(
        introRu: 'Мама просит шесть медиалун к чаю. А себе купи бола де фраиле — пончик!',
        goals: [
          _medialunas(6),
          const Goal(
            id: 'fraile',
            titleRu: 'Купи пончик (bola de fraile)',
            hintEs: 'Y una bola de fraile para mí.',
            hintRu: 'И одну бола де фраиле для меня.',
            keywordGroups: [
              ['fraile', 'bola de'],
            ],
          ),
          _price('¿Cuánto sale todo?'),
        ],
      ),
      Variant(
        introRu:
            'Нужен хлеб к обеду и две медиалуны. И узнай, есть ли альфахоры!',
        twist:
            'you sold all the alfajores this morning. If the child asks for alfajores, '
            'say sorry, there are none left, and offer a bola de fraile instead.',
        goals: [
          const Goal(
            id: 'pan',
            titleRu: 'Купи килограмм хлеба (pan)',
            hintEs: '¿Me das un kilo de pan, por favor?',
            hintRu: 'Дайте мне, пожалуйста, килограмм хлеба.',
            keywordGroups: [
              [' pan ', 'kilo'],
            ],
          ),
          _medialunas(2),
          const Goal(
            id: 'alfajor',
            titleRu: 'Спроси, есть ли альфахоры',
            hintEs: '¿Tenés alfajores?',
            hintRu: 'У вас есть альфахоры?',
            keywordGroups: [
              ['alfajor'],
            ],
          ),
        ],
      ),
    ],
    stickerIds: ['medialuna', 'alfajor_maicena', 'bola_fraile'],
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
    openerEs: '¡Hola, che! ¿Todo bien? ¿Qué andás buscando?',
    persona:
        'You are Tito, a cheerful young man who runs a kiosco on a street corner in Buenos Aires. '
        'You are funny and relaxed, you say "che" and "dale". '
        'You sell: caramelos (cien pesos each), alfajores de chocolate (mil doscientos pesos), '
        'chicles (trescientos pesos) and sobres de figuritas for the football sticker album '
        '(mil quinientos pesos each pack).',
    variants: [
      Variant(
        introRu:
            'Это киоск Тито. Узнай про карточки для альбома и купи конфет!',
        goals: [
          const Goal(
            id: 'figuritas',
            titleRu: 'Спроси, есть ли карточки (figuritas)',
            hintEs: '¿Tenés figuritas?',
            hintRu: 'У тебя есть фигуритас (карточки)?',
            keywordGroups: [
              ['figurita'],
            ],
          ),
          const Goal(
            id: 'caramelos',
            titleRu: 'Купи конфеты (caramelos)',
            hintEs: 'Quiero cinco caramelos, por favor.',
            hintRu: 'Я хочу пять конфет, пожалуйста.',
            keywordGroups: [
              ['caramelo'],
            ],
          ),
          _price('¿Cuánto sale?'),
        ],
      ),
      Variant(
        introRu: 'Перекус после школы: шоколадный альфахор и жвачка (chicle).',
        goals: [
          const Goal(
            id: 'alfajor',
            titleRu: 'Купи шоколадный альфахор',
            hintEs: 'Un alfajor de chocolate, por favor.',
            hintRu: 'Один шоколадный альфахор, пожалуйста.',
            keywordGroups: [
              ['alfajor'],
            ],
          ),
          const Goal(
            id: 'chicle',
            titleRu: 'Купи жвачку (chicle)',
            hintEs: 'Y un chicle también.',
            hintRu: 'И ещё жвачку.',
            keywordGroups: [
              ['chicle'],
            ],
          ),
          _price('¿Cuánto sale?'),
        ],
      ),
      Variant(
        introRu: 'Ты пришёл за карточками для альбома… Узнай, когда их привезут, и купи что-нибудь другое.',
        twist:
            'the figuritas are sold out. Their delivery arrives tomorrow morning ("mañana a la mañana"). '
            'Tell the child this when they ask, and suggest caramelos or chicles instead.',
        goals: [
          const Goal(
            id: 'figuritas',
            titleRu: 'Спроси про карточки (figuritas)',
            hintEs: '¿Tenés figuritas?',
            hintRu: 'У тебя есть фигуритас?',
            keywordGroups: [
              ['figurita'],
            ],
          ),
          const Goal(
            id: 'cuando',
            titleRu: 'Спроси, когда их привезут',
            hintEs: '¿Cuándo llegan?',
            hintRu: 'Когда их привезут?',
            keywordGroups: [
              ['cuando', 'manana'],
            ],
          ),
          const Goal(
            id: 'otra',
            titleRu: 'Купи что-нибудь другое',
            hintEs: 'Entonces quiero un chicle.',
            hintRu: 'Тогда я хочу жвачку.',
            keywordGroups: [
              ['caramelo', 'chicle', 'alfajor'],
            ],
          ),
        ],
      ),
    ],
    stickerIds: ['caramelos', 'alfajor_chocolate', 'figuritas'],
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
    openerEs: '¡Hola! Bienvenido a la heladería. ¿Qué te sirvo?',
    persona:
        'You are Mili, a friendly young woman who works in an ice-cream shop (heladería) in Buenos Aires. '
        'Flavors (gustos): dulce de leche, chocolate, frutilla, vainilla, limón, menta and sambayón. '
        'Sizes: cucurucho (cone, mil quinientos pesos, up to two gustos) and vasito '
        '(small cup, mil doscientos pesos, up to two gustos). '
        'Ask the child "¿cucurucho o vasito?" and "¿qué gustos querés?" when it helps the conversation.',
    variants: [
      Variant(
        introRu: 'Жарко! Зайди к Мили и закажи себе рожок мороженого.',
        goals: [
          const Goal(
            id: 'gustos',
            titleRu: 'Спроси, какие есть вкусы (gustos)',
            hintEs: '¿Qué gustos tenés?',
            hintRu: 'Какие у тебя есть вкусы?',
            keywordGroups: [
              ['gusto', 'sabor'],
            ],
          ),
          const Goal(
            id: 'cucurucho',
            titleRu: 'Попроси рожок (cucurucho)',
            hintEs: 'Quiero un cucurucho, por favor.',
            hintRu: 'Я хочу рожок, пожалуйста.',
            keywordGroups: [
              ['cucurucho', 'cono'],
            ],
          ),
          _flavor,
        ],
      ),
      Variant(
        introRu: 'Закажи стаканчик (vasito) и не забудь попросить ложечку!',
        goals: [
          const Goal(
            id: 'vasito',
            titleRu: 'Попроси стаканчик (vasito)',
            hintEs: 'Un vasito, por favor.',
            hintRu: 'Стаканчик, пожалуйста.',
            keywordGroups: [
              ['vasito', 'vaso'],
            ],
          ),
          _flavor,
          const Goal(
            id: 'cucharita',
            titleRu: 'Попроси ложечку (cucharita)',
            hintEs: '¿Me das una cucharita?',
            hintRu: 'Дадите мне ложечку?',
            keywordGroups: [
              ['cuchar'],
            ],
          ),
        ],
      ),
      Variant(
        introRu:
            'Ты очень хочешь шоколадное мороженое… Узнай, есть ли оно сегодня!',
        twist:
            'the chocolate flavor ran out today. If the child asks for chocolate, say sorry '
            'and suggest dulce de leche or another flavor.',
        goals: [
          const Goal(
            id: 'chocolate',
            titleRu: 'Спроси, есть ли шоколадное',
            hintEs: '¿Tenés chocolate?',
            hintRu: 'У тебя есть шоколадное?',
            keywordGroups: [
              ['chocolate'],
            ],
          ),
          const Goal(
            id: 'otro',
            titleRu: 'Выбери другой вкус',
            hintEs: 'Entonces dulce de leche, por favor.',
            hintRu: 'Тогда дульсе де лече, пожалуйста.',
            keywordGroups: [
              [
                'dulce de leche',
                'frutilla',
                'vainilla',
                'limon',
                'menta',
                'sambayon',
                'crema',
              ],
            ],
          ),
          const Goal(
            id: 'tamano',
            titleRu: 'Выбери: рожок или стаканчик',
            hintEs: 'En cucurucho, por favor.',
            hintRu: 'В рожке, пожалуйста.',
            keywordGroups: [
              ['cucurucho', 'cono', 'vasito', 'vaso'],
            ],
          ),
        ],
      ),
    ],
    stickerIds: ['cucurucho', 'vasito', 'pote_helado'],
  ),
  Mission(
    id: 'plaza',
    placeEs: 'La plaza',
    placeRu: 'Площадка',
    character: 'Juli',
    characterImage: 'assets/images/characters/juli.png',
    background: 'assets/images/backgrounds/plaza.png',
    voice: Voice.daniela,
    speed: 1.12,
    greet: _greetKid,
    openerEs: '¡Hola! ¿Sos nuevo en el barrio? Estamos jugando al fútbol.',
    persona:
        'You are Juli, a friendly ten-year-old girl from Buenos Aires playing fútbol with friends in the plaza. '
        'Talk like a kid: short and happy, using words like "dale", "re", "copado", "che". '
        'You love meeting new kids and you want them to join the game. '
        'Words you may use: pelota, arco, arquero (goalkeeper), atajar, patear, gol, equipo, penales.',
    variants: [
      Variant(
        introRu: 'В парке ребята играют в футбол. Познакомься с Хули и попросись в игру!',
        goals: [
          const Goal(
            id: 'name',
            titleRu: 'Скажи, как тебя зовут',
            hintEs: 'Me llamo… ¿Y vos?',
            hintRu: 'Меня зовут… А тебя?',
            keywordGroups: [
              ['me llamo', 'mi nombre', ' soy '],
            ],
          ),
          const Goal(
            id: 'jugar',
            titleRu: 'Спроси, можно ли поиграть',
            hintEs: '¿Puedo jugar con ustedes?',
            hintRu: 'Можно мне поиграть с вами?',
            keywordGroups: [
              ['jugar', 'juego', 'juegan'],
            ],
          ),
        ],
      ),
      Variant(
        introRu: 'Не хватает вратаря! Узнай, как зовут девочку, и предложи встать на ворота.',
        twist: 'your team needs a goalkeeper (arquero). Mention it if the child wants to play.',
        goals: [
          const Goal(
            id: 'su_nombre',
            titleRu: 'Спроси, как её зовут',
            hintEs: '¿Cómo te llamás?',
            hintRu: 'Как тебя зовут?',
            keywordGroups: [
              ['como te llamas', 'tu nombre', 'como te llamaba'],
            ],
          ),
          const Goal(
            id: 'jugar',
            titleRu: 'Спроси, можно ли поиграть',
            hintEs: '¿Puedo jugar?',
            hintRu: 'Можно мне поиграть?',
            keywordGroups: [
              ['jugar', 'juego', 'juegan'],
            ],
          ),
          const Goal(
            id: 'arco',
            titleRu: 'Скажи, что встанешь на ворота',
            hintEs: '¡Yo atajo!',
            hintRu: 'Я буду на воротах!',
            keywordGroups: [
              ['ataj', 'arquer', 'arco'],
            ],
          ),
        ],
      ),
      Variant(
        introRu: 'Хули предлагает пробить пенальти! Узнай, кто начинает, и забей гол.',
        twist: 'you propose playing penales (a penalty shootout), just the two of you.',
        goals: [
          const Goal(
            id: 'name',
            titleRu: 'Скажи, как тебя зовут',
            hintEs: 'Me llamo… ¿Y vos?',
            hintRu: 'Меня зовут… А тебя?',
            keywordGroups: [
              ['me llamo', 'mi nombre', ' soy '],
            ],
          ),
          const Goal(
            id: 'empieza',
            titleRu: 'Спроси, кто начинает',
            hintEs: '¿Quién empieza?',
            hintRu: 'Кто начинает?',
            keywordGroups: [
              ['empieza', 'empiezo', 'empezas', 'primero'],
            ],
          ),
          const Goal(
            id: 'gol',
            titleRu: 'Забей гол — крикни «¡Gol!»',
            hintEs: '¡Goooool!',
            hintRu: 'Гоооол!',
            keywordGroups: [
              [' gol', ' goo', 'golazo'],
            ],
          ),
        ],
      ),
    ],
    stickerIds: ['pelota', 'camiseta', 'copa'],
  ),
  Mission(
    id: 'colectivo',
    placeEs: 'El colectivo',
    placeRu: 'Автобус',
    character: 'Don Héctor',
    characterImage: 'assets/images/characters/hector.png',
    background: 'assets/images/backgrounds/colectivo.png',
    voice: Voice.ald,
    speed: 0.95,
    openerEs: '¡Buenas! Subí, subí. ¿A dónde vas?',
    persona:
        'You are Don Héctor, a kind, patient bus (colectivo) driver in Buenos Aires. '
        'Passengers pay with the SUBE card: they tap it on the machine, a ticket costs setecientos pesos. '
        'Your bus goes to the Obelisco, the zoológico and the plaza. When asked, you promise to tell the child where to get off.',
    variants: [
      Variant(
        introRu: 'Тебе нужно в зоопарк. Спроси водителя, едет ли туда автобус, и оплати проезд картой SUBE.',
        goals: [
          const Goal(
            id: 'va',
            titleRu: 'Спроси, едет ли автобус в зоопарк (zoológico)',
            hintEs: '¿Este colectivo va al zoológico?',
            hintRu: 'Этот автобус едет в зоопарк?',
            keywordGroups: [
              ['zoo'],
            ],
          ),
          const Goal(
            id: 'pagar',
            titleRu: 'Скажи, что платишь картой SUBE',
            hintEs: 'Pago con la SUBE.',
            hintRu: 'Я плачу картой SUBE.',
            keywordGroups: [
              ['sube', 'pag', 'tarjeta', 'boleto'],
            ],
          ),
          const Goal(
            id: 'bajar',
            titleRu: 'Попроси сказать, где выходить',
            hintEs: '¿Me avisás dónde bajo?',
            hintRu: 'Скажете мне, где выходить?',
            keywordGroups: [
              ['avis', 'bajo', 'bajar', 'parada'],
            ],
          ),
        ],
      ),
      Variant(
        introRu: 'Едем смотреть Обелиск! Узнай, сколько стоит билет и долго ли ехать.',
        goals: [
          const Goal(
            id: 'va',
            titleRu: 'Спроси, едет ли автобус к Обелиску',
            hintEs: '¿Va al Obelisco?',
            hintRu: 'Он едет к Обелиску?',
            keywordGroups: [
              ['obelisco'],
            ],
          ),
          _price('¿Cuánto sale el boleto?'),
          const Goal(
            id: 'falta',
            titleRu: 'Спроси, долго ли ехать',
            hintEs: '¿Falta mucho?',
            hintRu: 'Ещё долго ехать?',
            keywordGroups: [
              ['falta', 'tarda', 'lejos', 'cuanto tiempo'],
            ],
          ),
        ],
      ),
      Variant(
        introRu: 'Тебе нужно на площадь… Но этот ли автобус? Спроси водителя!',
        twist:
            'your bus does NOT go to the plaza today. When the child asks, say so kindly '
            'and tell them to take the colectivo ciento cincuenta y dos at the next stop.',
        goals: [
          const Goal(
            id: 'va',
            titleRu: 'Спроси, едет ли автобус на площадь (plaza)',
            hintEs: '¿Este colectivo va a la plaza?',
            hintRu: 'Этот автобус едет на площадь?',
            keywordGroups: [
              ['plaza'],
            ],
          ),
          const Goal(
            id: 'cual',
            titleRu: 'Спроси, какой автобус туда едет',
            hintEs: '¿Qué colectivo va a la plaza?',
            hintRu: 'Какой автобус едет на площадь?',
            keywordGroups: [
              ['que colectivo', 'cual', 'que linea', 'numero', 'que numero'],
            ],
          ),
        ],
      ),
    ],
    stickerIds: ['tarjeta', 'mapa', 'obelisco'],
  ),
  Mission(
    id: 'verduleria',
    placeEs: 'La verdulería',
    placeRu: 'Овощная лавка',
    character: 'Marta',
    characterImage: 'assets/images/characters/marta.png',
    background: 'assets/images/backgrounds/verduleria.png',
    voice: Voice.daniela,
    speed: 0.98,
    openerEs: '¡Hola, mi amor! Todo fresquito hoy. ¿Qué vas a llevar?',
    persona:
        'You are Marta, a cheerful greengrocer (verdulera) in Buenos Aires. You call children "mi amor". '
        'You sell by the kilo: manzanas (dos mil pesos), bananas (mil ochocientos), naranjas (mil quinientos), '
        'tomates (dos mil quinientos), papas (mil pesos). Sandía: tres mil pesos each. '
        'Everything is fresh and sweet today.',
    variants: [
      Variant(
        introRu: 'Купи фрукты домой: килограмм яблок и бананы.',
        goals: [
          const Goal(
            id: 'manzanas',
            titleRu: 'Попроси килограмм яблок (manzanas)',
            hintEs: 'Un kilo de manzanas, por favor.',
            hintRu: 'Килограмм яблок, пожалуйста.',
            keywordGroups: [
              ['manzana'],
            ],
          ),
          const Goal(
            id: 'bananas',
            titleRu: 'Купи бананы (bananas)',
            hintEs: 'Y bananas también.',
            hintRu: 'И ещё бананы.',
            keywordGroups: [
              ['banana'],
            ],
          ),
          _price(),
        ],
      ),
      Variant(
        introRu: 'Мама делает салат и суп: купи помидоры и картошку.',
        goals: [
          const Goal(
            id: 'tomates',
            titleRu: 'Купи помидоры (tomates)',
            hintEs: 'Quiero un kilo de tomates.',
            hintRu: 'Я хочу килограмм помидоров.',
            keywordGroups: [
              ['tomate'],
            ],
          ),
          const Goal(
            id: 'papas',
            titleRu: 'Купи картошку (papas)',
            hintEs: 'Y dos kilos de papas.',
            hintRu: 'И два килограмма картошки.',
            keywordGroups: [
              [' papa'],
            ],
          ),
          _price(),
        ],
      ),
      Variant(
        introRu: 'Летний день — купи арбуз (sandía) и спроси, сладкий ли он!',
        goals: [
          const Goal(
            id: 'sandia',
            titleRu: 'Попроси арбуз (sandía)',
            hintEs: '¿Me das una sandía?',
            hintRu: 'Дадите мне арбуз?',
            keywordGroups: [
              ['sandia'],
            ],
          ),
          const Goal(
            id: 'dulce',
            titleRu: 'Спроси, сладкий ли он',
            hintEs: '¿Está dulce?',
            hintRu: 'Он сладкий?',
            keywordGroups: [
              ['dulce', 'rica', 'madura'],
            ],
          ),
          _price(),
        ],
      ),
    ],
    stickerIds: ['banana', 'manzana', 'sandia'],
  ),
];

const _flavor = Goal(
  id: 'flavor',
  titleRu: 'Назови вкус мороженого',
  hintEs: 'De dulce de leche y frutilla.',
  hintRu: 'Дульсе де лече и клубника.',
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
  Sticker('pelota', 'pelota', 'мяч'),
  Sticker('camiseta', 'camiseta', 'футболка в цветах Аргентины'),
  Sticker('copa', 'copa', 'кубок'),
  Sticker('tarjeta', 'tarjeta SUBE', 'карта для проезда'),
  Sticker('mapa', 'mapa', 'карта города'),
  Sticker('obelisco', 'Obelisco', 'Обелиск — символ Буэнос-Айреса'),
  Sticker('banana', 'bananas', 'бананы'),
  Sticker('manzana', 'manzana', 'яблоко'),
  Sticker('sandia', 'sandía', 'арбуз'),
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
