import 'dart:convert';

import 'package:flutter/services.dart';

enum Origin { nativeAr, nativeRegion, introduced }

enum Safety { ok, dontEat, dontTouch }

/// One plant a child can find in Buenos Aires, with verified facts
/// (sources in assets/plants/SOURCES.md).
class Plant {
  Plant.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      scientific = j['scientific'] as String,
      es = j['es'] as String,
      esArticle = (j['es_article'] as String?) ?? 'el',
      ru = j['ru'] as String,
      kind = (j['kind'] as String?) ?? '',
      origin = switch (j['origin']) {
        'native_ar' => Origin.nativeAr,
        'native_region' => Origin.nativeRegion,
        _ => Origin.introduced,
      },
      originRu = (j['origin_ru'] as String?) ?? '',
      factRu = (j['fact_ru'] as String?) ?? '',
      factEs = (j['fact_es'] as String?) ?? '',
      whenRu = (j['when_to_find'] as String?) ?? '',
      lookForRu = (j['look_for_ru'] as String?) ?? '',
      safety = switch (j['safety']) {
        'dont_touch' => Safety.dontTouch,
        'dont_eat' => Safety.dontEat,
        _ => Safety.ok,
      },
      safetyRu = (j['safety_ru'] as String?) ?? '';

  final String id;
  final String scientific;
  final String es;
  final String esArticle;
  final String ru;
  final String kind;
  final Origin origin;
  final String originRu;
  final String factRu;
  final String factEs;
  final String whenRu;
  final String lookForRu;
  final Safety safety;
  final String safetyRu;

  bool get isFromHere => origin != Origin.introduced;
  String get esWithArticle => '$esArticle $es';
}

class PlantCatalog {
  PlantCatalog._(this.plants);

  /// For tests: a catalog from already parsed plants.
  factory PlantCatalog.of(List<Plant> plants) = PlantCatalog._;

  final List<Plant> plants;

  Plant? byId(String id) => plants.where((p) => p.id == id).firstOrNull;

  static Future<PlantCatalog> load() async {
    final raw = jsonDecode(
      await rootBundle.loadString('assets/plants/plants.json'),
    ) as List;
    return PlantCatalog._([
      for (final j in raw) Plant.fromJson(j as Map<String, dynamic>),
    ]);
  }

  /// Today's quest: the same for the whole day, different every day.
  Plant questFor(DateTime day) {
    final pool = plants.where((p) => p.safety != Safety.dontTouch).toList();
    final n = day.year * 400 + day.month * 31 + day.day;
    return pool[n % pool.length];
  }
}
