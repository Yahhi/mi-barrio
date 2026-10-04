import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ai/brain.dart';
import '../app.dart';
import '../game/missions.dart';
import '../game/progress.dart';

enum _Phase { starting, idle, listening, hearing, thinking, speaking, done }

class _Line {
  _Line.character(this.es) : fromChild = false;
  _Line.child(this.es) : fromChild = true;

  final bool fromChild;
  String es;
  String? ru;
  bool translating = false;
  bool showRu = false;
  String? wavPath;
}

/// One shop, one character, one conversation. The child talks into the mic;
/// Whisper hears it, keywords tick the goals, Gemma answers in character and
/// Piper says the answer out loud.
class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key, required this.mission});

  final Mission mission;

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  Mission get m => widget.mission;

  final _lines = <_Line>[];
  final _met = <String>{};
  final _hinted = <String>{};
  final _scroll = ScrollController();
  _Phase _phase = _Phase.starting;
  bool _goalsOpen = true;
  String? _toast;
  Timer? _autoStop;
  String? _justMet;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _autoStop?.cancel();
    services.audio.stopPlayback();
    services.brain.endScene();
    super.dispose();
  }

  Future<void> _start() async {
    await services.brain.startScene(systemPromptFor(m), m.openerEs);
    final line = _Line.character(m.openerEs);
    setState(() => _lines.add(line));
    await _speak(line);

    // Debug/demo: --dart-define=DEMO_SAY="Hola|Tres medialunas|..." plays
    // the child's side of the conversation by itself.
    const script = String.fromEnvironment('DEMO_SAY');
    if (script.isNotEmpty) {
      for (final said in script.split('|')) {
        if (!mounted || _phase == _Phase.done) break;
        await Future<void>.delayed(const Duration(seconds: 1));
        await _childSaid(said);
      }
    }
  }

  // ---- talking -----------------------------------------------------------

  Future<void> _micPressed() async {
    switch (_phase) {
      case _Phase.idle:
        if (!await services.audio.hasMicPermission()) {
          _showToast('Разреши доступ к микрофону в настройках 🎤');
          return;
        }
        HapticFeedback.mediumImpact();
        await services.audio.startRecording();
        setState(() => _phase = _Phase.listening);
        _autoStop = Timer(const Duration(seconds: 12), _stopListening);
      case _Phase.listening:
        await _stopListening();
      case _Phase.speaking:
        await services.audio.stopPlayback();
      default:
        break;
    }
  }

  Future<void> _stopListening() async {
    _autoStop?.cancel();
    if (_phase != _Phase.listening) return;
    HapticFeedback.lightImpact();
    setState(() => _phase = _Phase.hearing);
    final path = await services.audio.stopRecording();
    var text = '';
    if (path != null) {
      try {
        text = await services.speech.transcribe(path);
      } catch (e) {
        debugPrint('STT failed: $e');
      }
    }
    text = _dropWhisperGhosts(text);
    if (text.isEmpty) {
      setState(() => _phase = _Phase.idle);
      _showToast('Не получилось расслышать. Нажми и скажи ещё раз!');
      return;
    }
    await _childSaid(text);
  }

  Future<void> _childSaid(String text) async {
    final newlyMet = [
      for (final g in m.goals)
        if (!_met.contains(g.id) && g.isMetBy(text)) g.id,
    ];
    setState(() {
      _lines.add(_Line.child(text));
      if (_lines.where((l) => l.fromChild).length == 1) _goalsOpen = false;
      _met.addAll(newlyMet);
      if (newlyMet.isNotEmpty) _justMet = newlyMet.last;
      _phase = _Phase.thinking;
    });
    if (newlyMet.isNotEmpty) HapticFeedback.heavyImpact();
    _scrollDown();

    final reply = _Line.character('');
    setState(() => _lines.add(reply));
    try {
      await for (final token in services.brain.reply(text)) {
        setState(() => reply.es += token);
        _scrollDown();
      }
    } catch (e) {
      debugPrint('LLM failed: $e');
    }
    reply.es = cleanForSpeech(reply.es);
    if (reply.es.isEmpty) {
      reply.es = '¿Cómo? No te escuché bien. ¿Me lo decís otra vez?';
    }
    setState(() {});
    await _speak(reply);

    if (_met.length == m.goals.length) await _finish();
  }

  Future<void> _speak(_Line line) async {
    if (!mounted) return;
    setState(() => _phase = _Phase.speaking);
    try {
      if (line.wavPath == null) {
        final path = services.audio.newWavPath('say');
        await services.speech.synthesize(line.es, m.voice, m.speed, path);
        line.wavPath = path;
      }
      await services.audio.play(line.wavPath!);
    } catch (e) {
      debugPrint('TTS failed: $e');
    }
    if (mounted && _phase == _Phase.speaking) {
      setState(() => _phase = _Phase.idle);
    }
  }

  Future<void> _typeInstead() async {
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'Напиши по-испански…',
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.send_rounded),
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    if (text != null && text.isNotEmpty && _phase == _Phase.idle) {
      await _childSaid(text);
    }
  }

  // ---- help --------------------------------------------------------------

  Future<void> _showHint() async {
    final goal = m.goals.firstWhere(
      (g) => !_met.contains(g.id),
      orElse: () => m.goals.last,
    );
    _hinted.add(goal.id);
    setState(() {});
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '💡 ${goal.titleRu}',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text(
              goal.hintEs,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(goal.hintRu, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final path = services.audio.newWavPath('hint');
                await services.speech.synthesize(
                  goal.hintEs,
                  Voice.daniela,
                  0.8,
                  path,
                );
                await services.audio.play(path);
              },
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Послушать'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTranslation(_Line line) async {
    if (line.ru != null) {
      setState(() => line.showRu = !line.showRu);
      return;
    }
    if (_phase != _Phase.idle || line.translating) return;
    setState(() => line.translating = true);
    try {
      line.ru = await services.brain.translateToRussian(line.es);
      line.showRu = true;
    } catch (e) {
      debugPrint('Translate failed: $e');
    }
    if (mounted) setState(() => line.translating = false);
  }

  // ---- finishing ---------------------------------------------------------

  Future<void> _finish() async {
    setState(() => _phase = _Phase.done);
    final reward = await services.progress.completeMission(m, _hinted.length);
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RewardDialog(mission: m, reward: reward),
    );
    if (!mounted) return;
    if (again == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MissionScreen(mission: m)),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  // ---- helpers -----------------------------------------------------------

  /// Whisper invents these on silence or noise.
  String _dropWhisperGhosts(String s) {
    final n = normalize(s);
    const ghosts = [
      'amara org',
      'subtitulos',
      'suscribete',
      'gracias por ver',
      'musica',
    ];
    if (ghosts.any(n.contains) || n.trim().length < 2) return '';
    return s.trim();
  }

  void _showToast(String text) {
    setState(() => _toast = text);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _toast == text) setState(() => _toast = null);
    });
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(m.background, fit: BoxFit.cover),
          Container(color: Colors.white.withValues(alpha: 0.15)),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                _goalsCard(),
                Expanded(child: _conversation()),
                _bottomBar(),
              ],
            ),
          ),
          if (_toast != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 170,
              child: SoftCard(
                color: Palette.ink,
                child: Text(
                  _toast!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    child: Row(
      children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            m.placeEs,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ),
        Badge(
          isLabelVisible: _hinted.isNotEmpty,
          label: Text('${_hinted.length}'),
          child: IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: Palette.sun,
              foregroundColor: Palette.ink,
            ),
            icon: const Icon(Icons.lightbulb_rounded),
            onPressed: _phase == _Phase.done ? null : _showHint,
          ),
        ),
      ],
    ),
  );

  Widget _goalsCard() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: GestureDetector(
      onTap: () => setState(() => _goalsOpen = !_goalsOpen),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _goalsOpen
                          ? m.introRu
                          : 'Задание: ${_met.length} из ${m.goals.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Stars(Progress.starsForHints(_hinted.length), size: 18),
                  Icon(
                    _goalsOpen
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
              if (_goalsOpen) ...[
                const SizedBox(height: 6),
                for (final g in m.goals)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        AnimatedScale(
                          scale: _justMet == g.id ? 1.35 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          onEnd: () {
                            if (_justMet == g.id) {
                              setState(() => _justMet = null);
                            }
                          },
                          child: Icon(
                            _met.contains(g.id)
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: _met.contains(g.id)
                                ? Palette.leaf
                                : Colors.black26,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            g.titleRu,
                            style: TextStyle(
                              fontSize: 15,
                              decoration: _met.contains(g.id)
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: _met.contains(g.id)
                                  ? Colors.black45
                                  : Palette.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _conversation() => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    itemCount: _lines.length,
    itemBuilder: (_, i) {
      final line = _lines[i];
      final isLast = i == _lines.length - 1;
      return Align(
        alignment: line.fromChild
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: EdgeInsets.only(bottom: 10, left: line.fromChild ? 40 : 0),
          child: GestureDetector(
            onTap: line.fromChild ? null : () => _toggleTranslation(line),
            child: SoftCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              color: line.fromChild ? Palette.celeste : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!line.fromChild)
                    Text(
                      m.character,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Palette.caramel,
                      ),
                    ),
                  Text(
                    line.es.isEmpty && isLast ? '…' : line.es,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: line.fromChild ? Colors.white : Palette.ink,
                    ),
                  ),
                  if (!line.fromChild) ...[
                    if (line.showRu && line.ru != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          line.ru!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniButton(
                          label: line.translating
                              ? '…'
                              : (line.showRu ? 'ES' : 'RU'),
                          onTap: () => _toggleTranslation(line),
                        ),
                        const SizedBox(width: 6),
                        _MiniButton(
                          icon: Icons.volume_up_rounded,
                          onTap: () {
                            if (_phase == _Phase.idle && line.es.isNotEmpty) {
                              _speak(line);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _bottomBar() {
    final (label, color, icon) = switch (_phase) {
      _Phase.starting => ('Заходим…', Colors.grey, Icons.hourglass_top_rounded),
      _Phase.idle => ('Нажми и говори', Palette.coral, Icons.mic_rounded),
      _Phase.listening => (
        'Слушаю… нажми, когда закончишь',
        Colors.redAccent,
        Icons.stop_rounded,
      ),
      _Phase.hearing => (
        'Разбираю, что ты сказал(а)…',
        Palette.celesteDark,
        Icons.hearing_rounded,
      ),
      _Phase.thinking => (
        '${m.character} думает…',
        Palette.celesteDark,
        Icons.more_horiz_rounded,
      ),
      _Phase.speaking => (
        '${m.character} говорит',
        Palette.caramel,
        Icons.volume_up_rounded,
      ),
      _Phase.done => ('¡Muy bien!', Palette.leaf, Icons.celebration_rounded),
    };
    final busy =
        _phase == _Phase.hearing ||
        _phase == _Phase.thinking ||
        _phase == _Phase.starting;
    final charHeight = MediaQuery.of(context).size.height * 0.27;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedScale(
          scale: _phase == _Phase.speaking ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
          child: Image.asset(m.characterImage, height: charHeight),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MicButton(
                      color: color,
                      icon: icon,
                      pulsing: _phase == _Phase.listening,
                      busy: busy,
                      onTap: _micPressed,
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      iconSize: 24,
                      icon: const Icon(Icons.keyboard_rounded),
                      onPressed: _phase == _Phase.idle ? _typeInstead : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(10),
      ),
      child: icon != null
          ? Icon(icon, size: 18, color: Palette.celesteDark)
          : Text(
              label!,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Palette.celesteDark,
              ),
            ),
    ),
  );
}

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.color,
    required this.icon,
    required this.pulsing,
    required this.busy,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final bool pulsing;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, child) {
      final glow = widget.pulsing ? 10 + 18 * _pulse.value : 6.0;
      return GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.6),
                blurRadius: glow,
                spreadRadius: glow / 3,
              ),
            ],
          ),
          child: widget.busy
              ? const Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 4,
                  ),
                )
              : Icon(widget.icon, color: Colors.white, size: 48),
        ),
      );
    },
  );
}

class _RewardDialog extends StatelessWidget {
  const _RewardDialog({required this.mission, required this.reward});

  final Mission mission;
  final MissionReward reward;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Palette.cream,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '¡Muy bien!',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Palette.coral,
            ),
          ),
          const Text(
            'Задание выполнено!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Stars(reward.stars, size: 52),
          ),
          if (reward.stars < 3)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Попробуй без подсказок — получишь 3 звезды!',
                textAlign: TextAlign.center,
              ),
            ),
          if (reward.newStickers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Новые наклейки:',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in reward.newStickers)
                  SizedBox(
                    width: 84,
                    child: Column(
                      children: [
                        Image.asset(stickerById(id).asset, height: 76),
                        Text(
                          stickerById(id).nameEs,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Ещё раз'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('На карту'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
