import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vos_podes/explore/plant_eyes.dart';
import 'package:vos_podes/explore/plants.dart';

void main() {
  final raw = jsonDecode(File('assets/plants/plants.json').readAsStringSync()) as List;
  final plants = [for (final j in raw) Plant.fromJson(j as Map<String, dynamic>)];
  final tableIds = File('assets/plants/table_ids.txt').readAsLinesSync().where((l) => l.isNotEmpty).toList();

  test('ids are unique', () {
    expect(plants.map((p) => p.id).toSet().length, plants.length);
  });

  test('every plant has names, origin and a fact', () {
    for (final p in plants) {
      expect(p.es, isNotEmpty, reason: p.id);
      expect(p.ru, isNotEmpty, reason: p.id);
      expect(p.originRu, isNotEmpty, reason: p.id);
      expect(p.factRu, isNotEmpty, reason: p.id);
      expect(p.lookForRu, isNotEmpty, reason: p.id);
    }
  });

  test('dangerous plants always carry a warning text', () {
    for (final p in plants.where((p) => p.safety != Safety.ok)) {
      expect(p.safetyRu, isNotEmpty, reason: p.id);
    }
  });

  test('no card suggests eating or curing with a plant', () {
    final risky = RegExp(r'съедобн|можно есть|лечит|лекарств|вкусн', caseSensitive: false);
    for (final p in plants) {
      final text = '${p.factRu} ${p.originRu} ${p.lookForRu}';
      expect(risky.hasMatch(text), isFalse, reason: '${p.id}: $text');
    }
  });

  test('lookup table covers every plant and nothing else', () {
    final ids = plants.map((p) => p.id).toSet();
    expect(tableIds.toSet(), ids);
    final bytes = File('assets/plants/table_f32.bin').lengthSync();
    expect(bytes, tableIds.length * 1024 * 4);
  });

  test('daily quest is stable within a day and never a do-not-touch plant', () {
    final catalog = PlantCatalog.of(plants);
    final a = catalog.questFor(DateTime(2026, 10, 11, 8));
    final b = catalog.questFor(DateTime(2026, 10, 11, 20));
    expect(a.id, b.id);
    for (var d = 1; d <= 60; d++) {
      expect(catalog.questFor(DateTime(2026, 10, d)).safety, isNot(Safety.dontTouch));
    }
  });

  test('confidence needs a clear margin', () {
    expect(PlantResult([PlantGuess('a', 0.60), PlantGuess('b', 0.50)]).confident, isTrue);
    expect(PlantResult([PlantGuess('a', 0.60), PlantGuess('b', 0.57)]).confident, isFalse);
  });
}
