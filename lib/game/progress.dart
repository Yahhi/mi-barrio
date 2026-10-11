import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'missions.dart';

class Player {
  Player({
    required this.name,
    Map<String, int>? stars,
    Set<String>? stickers,
    this.onboarded = false,
    List<Find>? finds,
  }) : finds = finds ?? [],
       stars = stars ?? {},
       stickers = stickers ?? {};

  String name;

  /// Has seen Copo's walkthrough of the mission screen.
  bool onboarded;

  /// Plants collected outside: newest first.
  final List<Find> finds;

  /// Best stars per mission id (1..3).
  final Map<String, int> stars;
  final Set<String> stickers;

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
    'name': name,
    'stars': stars,
    'stickers': stickers.toList(),
    'onboarded': onboarded,
    'finds': [for (final f in finds) f.toJson()],
  };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    name: j['name'] as String,
    stars: (j['stars'] as Map).map((k, v) => MapEntry(k as String, v as int)),
    stickers: (j['stickers'] as List).cast<String>().toSet(),
    onboarded: j['onboarded'] as bool? ?? false,
    finds: [
      for (final f in (j['finds'] as List? ?? const []))
        Find.fromJson(f as Map<String, dynamic>),
    ],
  );
}

/// A plant a child photographed and recognized, for the herbarium.
class Find {
  Find({required this.plantId, required this.photoPath, required this.date});

  final String plantId;

  /// File name inside the app's documents/herbarium folder.
  final String photoPath;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'plant': plantId,
    'photo': photoPath,
    'date': date.toIso8601String(),
  };

  factory Find.fromJson(Map<String, dynamic> j) => Find(
    plantId: j['plant'] as String,
    photoPath: j['photo'] as String,
    date: DateTime.parse(j['date'] as String),
  );
}

/// Result of finishing a mission, for the celebration screen.
class MissionReward {
  MissionReward(this.stars, this.newStickers);

  final int stars;
  final List<String> newStickers;
}

class Progress extends ChangeNotifier {
  static const _key = 'progress_v1';

  final List<Player> players = [];
  int activeIndex = 0;

  Player? get active => players.isEmpty
      ? null
      : players[activeIndex.clamp(0, players.length - 1)];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    players
      ..clear()
      ..addAll((j['players'] as List).map((p) => Player.fromJson(p)));
    activeIndex = j['active'] as int? ?? 0;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'players': players.map((p) => p.toJson()).toList(),
        'active': activeIndex,
      }),
    );
    notifyListeners();
  }

  Future<void> addPlayer(String name) async {
    players.add(Player(name: name));
    activeIndex = players.length - 1;
    await _save();
  }

  Future<void> renamePlayer(int index, String name) async {
    players[index].name = name;
    await _save();
  }

  Future<void> select(int index) async {
    activeIndex = index;
    await _save();
  }

  Future<void> markOnboarded() async {
    active!.onboarded = true;
    await _save();
  }

  Future<void> addFind(Find f) async {
    active!.finds.insert(0, f);
    await _save();
  }

  static int starsForHints(int hintsUsed) =>
      hintsUsed == 0 ? 3 : (hintsUsed <= 2 ? 2 : 1);

  Future<MissionReward> completeMission(Mission m, int hintsUsed) async {
    final p = active!;
    final stars = starsForHints(hintsUsed);
    final wasFirstEver = p.stars.isEmpty;
    p.stars[m.id] = (p.stars[m.id] ?? 0) > stars ? p.stars[m.id]! : stars;

    final earned = <String>[
      ...m.stickerIds.take(stars),
      if (wasFirstEver) firstMissionSticker,
      if (missions.every((x) => p.stars.containsKey(x.id))) allMissionsSticker,
      if (missions.every((x) => p.stars[x.id] == 3)) allPerfectSticker,
    ];
    final fresh = earned.where((s) => !p.stickers.contains(s)).toList();
    p.stickers.addAll(fresh);
    await _save();
    return MissionReward(stars, fresh);
  }
}
