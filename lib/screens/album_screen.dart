import 'package:flutter/material.dart';

import '../app.dart';
import '../game/missions.dart';

/// Sticker album. Locked stickers show as grey silhouettes.
class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final owned = services.progress.active!.stickers;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.cream,
        title: Text(
          'Мой альбом · ${owned.length}/${stickers.length}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
        children: [
          for (final s in stickers)
            GestureDetector(
              onTap: owned.contains(s.id) ? () => _show(context, s) : null,
              child: SoftCard(
                padding: const EdgeInsets.all(8),
                color: owned.contains(s.id)
                    ? Colors.white
                    : const Color(0xFFF1E9DA),
                child: Column(
                  children: [
                    Expanded(
                      child: owned.contains(s.id)
                          ? Image.asset(s.asset)
                          : ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Color(0x22000000),
                                BlendMode.srcIn,
                              ),
                              child: Image.asset(s.asset),
                            ),
                    ),
                    Text(
                      owned.contains(s.id) ? s.nameEs : '?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _show(BuildContext context, Sticker s) => showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(s.asset, height: 200),
            Text(
              s.nameEs,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            Text(
              s.nameRu,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    ),
  );
}
