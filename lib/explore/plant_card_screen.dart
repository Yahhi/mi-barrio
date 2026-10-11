import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../game/missions.dart' show Voice;
import '../game/progress.dart';
import 'plants.dart';

/// What this plant is to this place: names in Spanish and Russian, where it
/// comes from, one fact, how to recognize it, and a safety note when needed.
class PlantCardScreen extends StatefulWidget {
  const PlantCardScreen({
    super.key,
    required this.plant,
    required this.photoPath,
    this.photoName,
  });

  final Plant plant;
  final String photoPath;

  /// Set when the photo was just taken: the card offers "add to herbarium".
  final String? photoName;

  @override
  State<PlantCardScreen> createState() => _PlantCardScreenState();
}

class _PlantCardScreenState extends State<PlantCardScreen> {
  Plant get p => widget.plant;
  String? _story;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sayName());
    _tellStory();
  }

  Future<void> _sayName() =>
      services.mouth.say(p.esWithArticle, voice: Voice.daniela, speed: 0.85);

  Future<void> _tellStory() async {
    try {
      final story = await services.brain.copoTells(
        nameRu: p.ru,
        nameEs: p.esWithArticle,
        facts: [
          p.originRu,
          p.factRu,
          p.lookForRu,
          p.whenRu,
        ].where((s) => s.isNotEmpty).join(' '),
      );
      debugPrint('[COPO] $story');
      if (mounted && story.isNotEmpty) setState(() => _story = story);
    } catch (e) {
      debugPrint('Copo story failed: $e');
    }
  }

  Future<void> _save() async {
    await services.progress.addFind(
      Find(plantId: p.id, photoPath: widget.photoName!, date: DateTime.now()),
    );
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() => _saved = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = !services.progress.active!.finds.any(
      (f) => f.plantId == p.id,
    );
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.width * 0.62,
            pinned: true,
            backgroundColor: Palette.leaf,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.file(File(widget.photoPath), fit: BoxFit.cover),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            sliver: SliverList.list(
              children: [
                if (widget.photoName != null && isNew)
                  const Text(
                    'Новое растение! ✨',
                    style: TextStyle(
                      color: Palette.coral,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.esWithArticle,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Palette.celesteDark,
                      ),
                      icon: const Icon(Icons.volume_up_rounded),
                      onPressed: _sayName,
                    ),
                  ],
                ),
                Text(
                  '${p.ru} · ${p.scientific}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                if (p.safety != Safety.ok)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SoftCard(
                      color: const Color(0xFFFFE1DA),
                      child: Row(
                        children: [
                          const Text('⚠️', style: TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.safetyRu.isNotEmpty
                                  ? p.safetyRu
                                  : (p.safety == Safety.dontTouch
                                        ? 'Не трогай и не ешь!'
                                        : 'Ядовито — не ешь!'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SoftCard(
                  color: p.isFromHere
                      ? const Color(0xFFE4F5E9)
                      : const Color(0xFFE6F0FA),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.isFromHere
                            ? '🇦🇷 Родом отсюда'
                            : '✈️ Приехал издалека',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(p.originRu, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/images/characters/copo.png',
                        height: 56,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.factRu,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_story != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _story!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Palette.caramel,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (p.factEs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SoftCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.factEs,
                            style: const TextStyle(
                              fontSize: 17,
                              color: Palette.celesteDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.volume_up_rounded,
                            color: Palette.celesteDark,
                          ),
                          onPressed: () => services.mouth.say(
                            p.factEs,
                            voice: Voice.daniela,
                            speed: 0.85,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '🔎 Как узнать: ${p.lookForRu}',
                  style: const TextStyle(fontSize: 15),
                ),
                if (p.whenRu.isNotEmpty)
                  Text('🗓 ${p.whenRu}', style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.photoName == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _saved ? Palette.leaf : Palette.coral,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: _saved ? null : _save,
                  icon: Icon(_saved ? Icons.check_rounded : Icons.eco_rounded),
                  label: Text(_saved ? 'В гербарии!' : 'В гербарий!'),
                ),
              ),
            ),
    );
  }
}
