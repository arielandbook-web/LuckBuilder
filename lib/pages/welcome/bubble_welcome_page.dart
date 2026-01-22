import 'dart:math';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BubbleWelcomePage extends StatefulWidget {
  const BubbleWelcomePage({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<BubbleWelcomePage> createState() => _BubbleWelcomePageState();
}

class _BubbleWelcomePageState extends State<BubbleWelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _breathCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat(reverse: true);

  late final AnimationController _popCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  final AudioPlayer _player = AudioPlayer();
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    // 可選：預先載入音效，降低首次播放延遲
    _player.setSource(AssetSource('sfx/pop_01.wav'));
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _popCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_popped) return;
    setState(() => _popped = true);

    // Haptics
    HapticFeedback.lightImpact();

    // Sound
    // ignore: unawaited_futures
    _player.play(AssetSource('sfx/pop_01.wav'), volume: 0.75);

    // Animation
    await _popCtrl.forward();

    // Next
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          const _BubbleBackground(),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onTap,
              child: AnimatedBuilder(
                animation: Listenable.merge([_breathCtrl, _popCtrl]),
                builder: (_, __) {
                  final breath = 1.0 + (_breathCtrl.value * 0.03);

                  // pop progress
                  final t = _popCtrl.value;
                  final popT = Curves.easeOutCubic.transform(t);

                  double scale = breath;
                  double opacity = 1.0;

                  if (_popped) {
                    // 0~0.15: press down
                    if (t < 0.15) {
                      scale = lerpDouble(breath, 0.96, t / 0.15)!;
                    } else {
                      // then slightly expand & fade out
                      scale = lerpDouble(0.96, 1.08, (t - 0.15) / 0.85)!;
                      opacity = lerpDouble(1.0, 0.0, popT)!;
                    }
                  }

                  return SizedBox(
                    width: min(size.width * 0.78, 360),
                    height: min(size.width * 0.78, 360),
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const _GlassBubble(),
                            if (_popped) _PopBurst(progress: t),
                            AnimatedOpacity(
                              opacity: _popped ? (1.0 - popT) : 1.0,
                              duration: const Duration(milliseconds: 120),
                              child: const Text(
                                '學習泡泡',
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: Color(0xE6FFFFFF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleBackground extends StatelessWidget {
  const _BubbleBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.35, -0.15),
          radius: 1.2,
          colors: [
            Color(0xFF1B2B5A),
            Color(0xFF0B0F1E),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _BgBubblesPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BgBubblesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);

    // soft dust
    final dustPaint = Paint()..color = const Color(0x14FFFFFF);
    for (int i = 0; i < 120; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 1.6 + 0.2;
      canvas.drawCircle(Offset(x, y), r, dustPaint);
    }

    // bubbles
    final bubblePaint = Paint()..color = const Color(0x26FFFFFF);
    for (int i = 0; i < 14; i++) {
      final r = rnd.nextDouble() * 22 + 10;
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), r, bubblePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassBubble extends StatelessWidget {
  const _GlassBubble();

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x22FFFFFF),
            border: Border.all(color: const Color(0x33FFFFFF), width: 1),
            boxShadow: const [
              BoxShadow(
                blurRadius: 30,
                spreadRadius: 2,
                color: Color(0x22000000),
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PopBurst extends StatelessWidget {
  const _PopBurst({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PopPainter(progress),
      child: const SizedBox.expand(),
    );
  }
}

class _PopPainter extends CustomPainter {
  _PopPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // ring
    final ringP = Curves.easeOutExpo.transform(t);
    final ringR = (size.width * 0.35) + ringP * (size.width * 0.30);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(2.2, 0.0, ringP)!
      ..color = Color.lerp(const Color(0x66FFFFFF), const Color(0x00FFFFFF), ringP)!;
    canvas.drawCircle(c, ringR, ringPaint);

    // particles
    final particlePaint = Paint()..color = const Color(0x55FFFFFF);
    final count = 20;
    for (int i = 0; i < count; i++) {
      final ang = (i / count) * pi * 2;
      final dist = ringP * (size.width * 0.32);
      final p = c + Offset(cos(ang), sin(ang)) * dist;
      final pr = lerpDouble(4.2, 0.0, ringP)!;
      canvas.drawCircle(p, pr, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PopPainter oldDelegate) => oldDelegate.t != t;
}
