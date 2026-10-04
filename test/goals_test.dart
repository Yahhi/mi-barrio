import 'package:flutter_test/flutter_test.dart';
import 'package:vos_podes/game/missions.dart';
import 'package:vos_podes/game/progress.dart';

Goal goal(String mission, String id) =>
    missions.firstWhere((m) => m.id == mission).goals.firstWhere((g) => g.id == id);

void main() {
  test('normalize strips accents and punctuation', () {
    expect(normalize('¡Hola! ¿Cuánto sale?'), ' hola cuanto sale ');
  });

  test('greeting', () {
    final g = goal('panaderia', 'greet');
    expect(g.isMetBy('Hola, buen día.'), isTrue);
    expect(g.isMetBy('¡Buenas!'), isTrue);
    expect(g.isMetBy('Chocolate'), isFalse, reason: '"hola" inside chocolate must not count');
  });

  test('three medialunas needs both the item and the number', () {
    final g = goal('panaderia', 'medialunas');
    expect(g.isMetBy('¿Me das tres medialunas, por favor?'), isTrue);
    expect(g.isMetBy('Quiero 3 medialunas.'), isTrue);
    expect(g.isMetBy('Quiero medialunas.'), isFalse);
    // Real Whisper output from the self-test:
    expect(g.isMetBy('-Hola, buen día. Me das tres medielunas, por favor'), isTrue);
    expect(g.isMetBy('Me das tres media lunas'), isTrue);
  });

  test('near misses on long words only', () {
    expect(goal('kiosco', 'caramelos').isMetBy('Quiero caramellos'), isTrue);
    expect(goal('kiosco', 'figuritas').isMetBy('¿Tenés figuritas?'), isTrue);
    expect(goal('kiosco', 'figuritas').isMetBy('¿Tenés figurita?'), isTrue);
    expect(goal('heladeria', 'cucurucho').isMetBy('Un cucurucu'), isTrue);
    expect(goal('panaderia', 'alfajor').isMetBy('Quiero un alfahor'), isTrue);
    expect(goal('kiosco', 'caramelos').isMetBy('Quiero chicles'), isFalse);
  });

  test('price and goodbye', () {
    expect(goal('kiosco', 'price').isMetBy('¿Cuánto es?'), isTrue);
    expect(goal('kiosco', 'price').isMetBy('¿Cuánto sale?'), isTrue);
    expect(goal('kiosco', 'bye').isMetBy('Gracias, chau.'), isTrue);
  });

  test('ice cream flavors and size', () {
    expect(goal('heladeria', 'flavor').isMetBy('De dulce de leche, por favor.'), isTrue);
    expect(goal('heladeria', 'cucurucho').isMetBy('Un cucurucho.'), isTrue);
    expect(goal('heladeria', 'gustos').isMetBy('¿Qué gustos tenés?'), isTrue);
  });

  test('every hint satisfies its own goal', () {
    for (final m in missions) {
      for (final g in m.goals) {
        expect(g.isMetBy(g.hintEs), isTrue, reason: '${m.id}/${g.id}: "${g.hintEs}"');
      }
    }
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
