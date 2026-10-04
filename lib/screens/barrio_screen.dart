import 'package:flutter/material.dart';

import '../app.dart';
import '../game/missions.dart';
import 'album_screen.dart';
import 'mission_screen.dart';
import 'players_screen.dart';

/// The neighborhood map: tap a shop to start its mission.
class BarrioScreen extends StatelessWidget {
  const BarrioScreen({super.key});

  // Where each shop sits on barrio.png, as fractions of the image.
  static const _hotspots = {
    'panaderia': Rect.fromLTWH(0.06, 0.08, 0.31, 0.24),
    'kiosco': Rect.fromLTWH(0.37, 0.08, 0.26, 0.24),
    'heladeria': Rect.fromLTWH(0.63, 0.08, 0.34, 0.25),
    'plaza': Rect.fromLTWH(0.22, 0.40, 0.56, 0.22),
  };

  void _open(BuildContext context, Mission m) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => MissionScreen(mission: m)));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: services.progress,
      builder: (context, _) {
        final player = services.progress.active!;
        return LayoutBuilder(
          builder: (context, box) {
            // barrio.png (752×1344) covers the screen, anchored at the top;
            // hotspots are mapped through the same scale and offset.
            final scale = [
              box.maxWidth / 752,
              box.maxHeight / 1344,
            ].reduce((a, b) => a > b ? a : b);
            final imgW = 752 * scale;
            final imgH = 1344 * scale;
            final dx = (box.maxWidth - imgW) / 2;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: dx,
                  top: 0,
                  width: imgW,
                  height: imgH,
                  child: Image.asset(
                    'assets/images/backgrounds/barrio.png',
                    fit: BoxFit.fill,
                  ),
                ),
                for (final m in missions.where(
                  (m) => _hotspots.containsKey(m.id),
                ))
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(
                      dx + _hotspots[m.id]!.left * imgW,
                      _hotspots[m.id]!.top * imgH,
                      _hotspots[m.id]!.width * imgW,
                      _hotspots[m.id]!.height * imgH,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _open(context, m),
                      child: Align(
                        alignment: m.id == 'plaza'
                            ? Alignment.topCenter
                            : Alignment.bottomCenter,
                        child: _ShopBadge(
                          mission: m,
                          stars: player.stars[m.id] ?? 0,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Row(
                        children: [
                          _Pill(
                            icon: Icons.person_rounded,
                            label: '${player.name} · ⭐ ${player.totalStars}',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PlayersScreen(),
                              ),
                            ),
                          ),
                          const Spacer(),
                          _Pill(
                            icon: Icons.collections_bookmark_rounded,
                            label:
                                'Альбом ${player.stickers.length}/${stickers.length}',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AlbumScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: SafeArea(
                    top: false,
                    child: SoftCard(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Куда пойдём?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GridView.count(
                            padding: EdgeInsets.zero,
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 0.95,
                            children: [
                              for (final m in missions)
                                InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _open(context, m),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Palette.cream,
                                        backgroundImage: AssetImage(
                                          m.characterImage,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      FittedBox(
                                        child: Text(
                                          _short(m.placeEs),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Stars(player.stars[m.id] ?? 0, size: 15),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _ShopBadge extends StatelessWidget {
  const _ShopBadge({required this.mission, required this.stars});

  final Mission mission;
  final int stars;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          child: Text(
            _short(mission.placeEs),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),
        Stars(stars, size: 13),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const StadiumBorder(),
    elevation: 3,
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Palette.celesteDark),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ),
  );
}

String _short(String place) => place.replaceFirst(RegExp(r'^(La|El) '), '');
