import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vos_podes/game/missions.dart';
import 'package:vos_podes/game/progress.dart';

Mission mission(String id) => missions.firstWhere((m) => m.id == id);

Goal goal(String missionId, String id, {int variant = 0}) =>
    MissionRun(mission(missionId), variant).goals.firstWhere((g) => g.id == id);

void main() {
  test('normalize strips accents and punctuation', () {
    expect(normalize('¡Hola! ¿Cuánto sale?'), ' hola cuanto sale ');
  });

  test('greeting', () {
    final g = goal('panaderia', 'greet');
    expect(g.isMetBy('Hola, buen día.'), isTrue);
    expect(g.isMetBy('¡Buenas!'), isTrue);
    expect(g.isMetBy('Chocolate'), isFalse);
  });

  test('medialunas need the item and the right number', () {
    final three = goal('panaderia', 'medialunas', variant: 0);
    expect(three.isMetBy('¿Me das tres medialunas, por favor?'), isTrue);
    expect(three.isMetBy('Quiero 3 medialunas.'), isTrue);
    expect(three.isMetBy('-Hola, buen día. Me das tres medielunas, por favor'), isTrue);
    expect(three.isMetBy('Me das tres media lunas'), isTrue);
    expect(three.isMetBy('Quiero medialunas.'), isFalse);
    expect(three.isMetBy('Quiero dos medialunas.'), isFalse);

    final six = goal('panaderia', 'medialunas', variant: 1);
    expect(six.isMetBy('Media docena de medialunas'), isTrue);
    expect(six.isMetBy('Seis medialunas'), isTrue);

    final two = goal('panaderia', 'medialunas', variant: 2);
    expect(two.isMetBy('Dos medialunas, por favor'), isTrue);
    expect(two.isMetBy('Todas las medialunas'), isFalse, reason: '"dos" inside "todas"');
  });

  test('near misses on long words only', () {
    expect(goal('kiosco', 'caramelos').isMetBy('Quiero caramellos'), isTrue);
    expect(goal('kiosco', 'figuritas').isMetBy('¿Tenés figurita?'), isTrue);
    expect(goal('heladeria', 'cucurucho').isMetBy('Un cucurucu'), isTrue);
    expect(goal('panaderia', 'alfajor').isMetBy('Quiero un alfahor'), isTrue);
    expect(goal('kiosco', 'caramelos').isMetBy('Quiero chicles'), isFalse);
  });

  test('new places', () {
    expect(goal('plaza', 'jugar').isMetBy('¿Puedo jugar con ustedes?'), isTrue);
    expect(goal('plaza', 'arco', variant: 1).isMetBy('¡Yo atajo!'), isTrue);
    expect(goal('plaza', 'gol', variant: 2).isMetBy('¡Goooool!'), isTrue);
    expect(goal('plaza', 'gol', variant: 2).isMetBy('Gooool'), isTrue);
    expect(goal('plaza', 'gol', variant: 2).isMetBy('¡Gol!'), isTrue);
    expect(goal('colectivo', 'va').isMetBy('¿Este colectivo va al zoológico?'), isTrue);
    expect(goal('colectivo', 'pagar').isMetBy('Pago con la SUBE'), isTrue);
    expect(goal('verduleria', 'papas', variant: 1).isMetBy('Dos kilos de papas'), isTrue);
    expect(goal('verduleria', 'papas', variant: 1).isMetBy('Quiero zapatos'), isFalse);
  });

  test('every hint satisfies its own goal, in every variant', () {
    for (final m in missions) {
      for (var v = 0; v < m.variants.length; v++) {
        for (final g in MissionRun(m, v).goals) {
          expect(g.isMetBy(g.hintEs), isTrue, reason: '${m.id}#$v/${g.id}: "${g.hintEs}"');
        }
      }
    }
  });

  test('goal ids are unique inside a run', () {
    for (final m in missions) {
      for (var v = 0; v < m.variants.length; v++) {
        final ids = MissionRun(m, v).goals.map((g) => g.id).toList();
        expect(ids.toSet().length, ids.length, reason: '${m.id}#$v $ids');
      }
    }
  });

  test('a new visit never repeats the last variant', () {
    final m = mission('panaderia');
    for (var seed = 0; seed < 50; seed++) {
      final run = MissionRun.pick(m, lastIndex: 1, random: Random(seed));
      expect(run.variantIndex, isNot(1));
    }
  });

  test('twists reach the character prompt', () {
    expect(MissionRun(mission('heladeria'), 2).systemPrompt, contains('chocolate flavor ran out'));
    expect(MissionRun(mission('heladeria'), 0).systemPrompt, isNot(contains('Today:')));
  });

  test('stars by hints used', () {
    expect(Progress.starsForHints(0), 3);
    expect(Progress.starsForHints(2), 2);
    expect(Progress.starsForHints(3), 1);
  });

  test('every sticker referenced by a mission exists', () {
    for (final m in missions) {
      for (final id in m.stickerIds) {
        expect(stickers.any((s) => s.id == id), isTrue, reason: id);
      }
    }
  });
}
