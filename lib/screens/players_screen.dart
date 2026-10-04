import 'package:flutter/material.dart';

import '../app.dart';
import 'barrio_screen.dart';

/// Who is playing? Each child has their own stars and sticker album.
class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final progress = services.progress;

  Future<void> _add() async {
    final name = await _askName(context, '');
    if (name == null || name.isEmpty) return;
    await progress.addPlayer(name);
    setState(() {});
  }

  Future<void> _rename(int i) async {
    final name = await _askName(context, progress.players[i].name);
    if (name == null || name.isEmpty) return;
    await progress.renamePlayer(i, name);
    setState(() {});
  }

  Future<void> _pick(int i) async {
    await progress.select(i);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BarrioScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Image.asset('assets/images/characters/copo.png', height: 150),
            const Text(
              '¡Hola! Кто играет?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Меня зовут Копо. Я покажу тебе наш район в Буэнос-Айресе!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < progress.players.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: () => _pick(i),
                        child: SoftCard(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: i.isEven
                                    ? Palette.celeste
                                    : Palette.coral,
                                child: Text(
                                  progress.players[i].name.characters.first
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      progress.players[i].name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '⭐ ${progress.players[i].totalStars}   🃏 ${progress.players[i].stickers.length}',
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded),
                                onPressed: () => _rename(i),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Добавить игрока'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _askName(BuildContext context, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Как тебя зовут?'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 22),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Готово'),
        ),
      ],
    ),
  );
}
