import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../app.dart';
import '../game/missions.dart' show Voice;
import '../game/progress.dart';
import 'plant_card_screen.dart';
import 'plants.dart';

/// Copo's herbarium: today's quest, the camera, and every plant collected.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  PlantCatalog get catalog => services.plants;
  bool _busy = false;
  String? _docs;

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then(
      (d) => setState(() => _docs = d.path),
    );
  }

  Future<void> _snap(ImageSource source) async {
    final shot = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (shot == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final dir = Directory('$_docs/herbarium');
      await dir.create(recursive: true);
      final name = 'p_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(shot.path).copy('${dir.path}/$name');
      final result = await services.plantEyes.identify('${dir.path}/$name');
      if (!mounted) return;
      setState(() => _busy = false);

      Plant? plant;
      final best = result.guesses.first;
      if (best.score < 0.3) {
        _say(
          'Хм… Кажется, это не растение из нашего района. Подойди поближе к листьям или цветку!',
        );
        return;
      }
      if (result.confident) {
        plant = catalog.byId(best.id);
      } else {
        plant = await _chooseAmong([
          for (final g in result.guesses) ?catalog.byId(g.id),
        ]);
      }
      if (plant == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlantCardScreen(
            plant: plant!,
            photoPath: '${dir.path}/$name',
            photoName: name,
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      debugPrint('Identify failed: $e');
      if (mounted) {
        setState(() => _busy = false);
        _say('Не получилось рассмотреть фото. Попробуй ещё раз!');
      }
    }
  }

  /// Copo isn't sure: the child compares the plant with three candidates.
  Future<Plant?> _chooseAmong(
    List<Plant> options,
  ) => showModalBottomSheet<Plant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Palette.cream,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset('assets/images/characters/copo.png', height: 64),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Я не уверен! Это одно из этих растений. Посмотри внимательно — какое похоже?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final p in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.pop(ctx, p),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.es,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          p.ru,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '🔎 ${p.lookForRu}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _say(
                  'Ничего страшного! Сфотографируй лист или цветок поближе.',
                );
              },
              child: const Text('Ни одно не похоже'),
            ),
          ],
        ),
      ),
    ),
  );

  void _say(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text, style: const TextStyle(fontSize: 16)),
      backgroundColor: Palette.ink,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final player = services.progress.active!;
    final quest = catalog.questFor(DateTime.now());
    final today = DateTime.now();
    final questDone = player.finds.any(
      (f) =>
          f.plantId == quest.id &&
          f.date.year == today.year &&
          f.date.month == today.month &&
          f.date.day == today.day,
    );
    final kinds = {for (final f in player.finds) f.plantId};
    final local = kinds
        .where((id) => catalog.byId(id)?.isFromHere ?? false)
        .length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.cream,
        title: const Text(
          'Herbario de Copo',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
            children: [
              SoftCard(
                color: questDone ? const Color(0xFFE4F5E9) : Colors.white,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/characters/copo.png',
                      height: 80,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            questDone
                                ? 'Задание дня выполнено! 🎉'
                                : 'Задание дня',
                            style: const TextStyle(
                              color: Palette.caramel,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Найди ${quest.ru}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                quest.esWithArticle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Palette.celesteDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.volume_up_rounded,
                                  color: Palette.celesteDark,
                                ),
                                onPressed: () => services.mouth.say(
                                  quest.esWithArticle,
                                  voice: Voice.daniela,
                                  speed: 0.85,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '🔎 ${quest.lookForRu}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          if (quest.whenRu.isNotEmpty)
                            Text(
                              '🗓 ${quest.whenRu}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Мой гербарий · ${kinds.length} из ${catalog.plants.length}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '🇦🇷 родом отсюда: $local   ✈️ приехали издалека: ${kinds.length - local}',
              ),
              const SizedBox(height: 10),
              if (player.finds.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Пока пусто. Выйди на улицу, найди дерево или цветок и сфотографируй его!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                  children: [
                    for (final f in player.finds)
                      if (catalog.byId(f.plantId) case final p?)
                        _FindTile(find: f, plant: p, docs: _docs),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.leaf,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      onPressed: _busy || _docs == null
                          ? null
                          : () => _snap(ImageSource.camera),
                      icon: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.photo_camera_rounded, size: 28),
                      label: Text(
                        _busy
                            ? 'Копо рассматривает…'
                            : 'Сфотографировать растение',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    iconSize: 28,
                    tooltip: 'Из галереи',
                    onPressed: _busy || _docs == null
                        ? null
                        : () => _snap(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindTile extends StatelessWidget {
  const _FindTile({
    required this.find,
    required this.plant,
    required this.docs,
  });

  final Find find;
  final Plant plant;
  final String? docs;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlantCardScreen(
            plant: plant,
            photoPath: '$docs/herbarium/${find.photoPath}',
          ),
        ),
      );
    },
    child: SoftCard(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: docs == null
                  ? const SizedBox()
                  : Image.file(
                      File('$docs/herbarium/${find.photoPath}'),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      cacheWidth: 300,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              '${plant.isFromHere ? '🇦🇷 ' : ''}${plant.es}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );
}
