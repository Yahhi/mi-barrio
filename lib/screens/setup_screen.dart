import 'package:flutter/material.dart';

import '../ai/audio.dart';
import '../ai/brain.dart';
import '../ai/engines.dart';
import '../ai/model_files.dart';
import '../ai/speech.dart';
import '../app.dart';
import '../debug/self_test.dart';
import '../game/missions.dart';
import 'album_screen.dart';
import 'barrio_screen.dart';
import 'mission_screen.dart';
import 'players_screen.dart';

/// First launch: downloads the models (~3 GB, once). Later launches: loads
/// them into memory and goes straight to the game.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _status = 'Привет!';
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _progress = null;
    });
    try {
      await services.progress.load();
      final files = services.files = await ModelFiles.open();

      _set('Готовим голоса…');
      await files.ensureVoices();

      const total = ModelFiles.totalDownloadBytes;
      const whisperShare = total - 2588147712;
      var whisperBytes = 0;
      if (!await files.whisperReady()) {
        _set('Скачиваем «уши» — распознавание речи…', 0);
        await files.ensureWhisper((b) {
          whisperBytes = b;
          _set(null, b / total);
        });
      } else {
        whisperBytes = whisperShare;
      }

      _set(
        'Скачиваем «мозг» для персонажей…\nОдин раз, около 2,6 ГБ. Нужен Wi‑Fi.',
      );
      await files.ensureGemma((percent) {
        _set(
          null,
          (whisperBytes + (total - whisperShare) * percent / 100) / total,
        );
      });

      _set('Персонажи просыпаются…', null);
      services.audio = await Audio.create();
      services.speech = await Speech.start(files);
      services.ears = WhisperEars(services.audio, services.speech);
      services.mouth = PiperMouth(services.audio, services.speech);
      services.brain = await Brain.load();
      if (const bool.fromEnvironment('SELFTEST')) await runSelfTest();

      if (!mounted) return;
      // Debug: --dart-define=START=barrio|mission|album opens a screen directly.
      const start = String.fromEnvironment('START');
      if (start.isNotEmpty) {
        if (services.progress.players.isEmpty) {
          await services.progress.addPlayer('Test');
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BarrioScreen()),
        );
        if (start.startsWith('mission')) {
          // START=mission or START=mission:kiosco
          final id = start.contains(':')
              ? start.split(':').last
              : missions.first.id;
          final mission = missions.firstWhere((m) => m.id == id);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MissionScreen(mission: mission)),
          );
        } else if (start == 'album') {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AlbumScreen()));
        }
        return;
      }
      final hasPlayers = services.progress.players.isNotEmpty;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => hasPlayers
              ? const BarrioScreen()
              : const PlayersScreen(firstRun: true),
        ),
      );
    } catch (e, st) {
      debugPrint('Setup failed: $e\n$st');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _set(String? status, [double? progress]) {
    if (!mounted) return;
    setState(() {
      if (status != null) _status = status;
      _progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/characters/copo.png', height: 220),
            const SizedBox(height: 12),
            const Text(
              'Mi Barrio',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Palette.celesteDark,
              ),
            ),
            const SizedBox(height: 24),
            if (_error == null) ...[
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 14,
                  backgroundColor: Colors.white,
                  color: Palette.coral,
                ),
              ),
              if (_progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${(_progress! * 100).toStringAsFixed(0)}%'),
                ),
            ] else ...[
              const Text(
                'Что-то пошло не так 😕',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _run,
                child: const Text('Попробовать снова'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
