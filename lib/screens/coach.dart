import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/prefs.dart';

/// One tip: a spotlight on [target] with a short explanation.
typedef Tip = ({GlobalKey target, String title, String text});

/// Tips are off until the app turns them on at startup, so widget tests and screenshots never see them.
bool tipsEnabled = false;

/// Shows [tips] once per [id] (remembered on the device; Profile → Replay tips shows them again).
/// Call from initState; it waits for the first frame so the targets have a size.
void showTipsOnce(BuildContext context, String id, List<Tip> tips) {
  if (!tipsEnabled || Prefs.seenTips.value.contains(id)) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Wait for entrance animations to settle so targets are in their final place.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!context.mounted || Prefs.seenTips.value.contains(id)) return;
        final visible = [
          for (final t in tips)
            if (t.target.currentContext != null) t,
        ];
        if (visible.isEmpty) return;
        Prefs.markTipSeen(id);
        late final OverlayEntry entry;
        entry = OverlayEntry(
          builder: (_) => _Coach(tips: visible, onDone: () => entry.remove()),
        );
        Overlay.of(context, rootOverlay: true).insert(entry);
      }),
    );
  });
}

class _Coach extends StatefulWidget {
  const _Coach({required this.tips, required this.onDone});

  final List<Tip> tips;
  final VoidCallback onDone;

  @override
  State<_Coach> createState() => _CoachState();
}

class _CoachState extends State<_Coach> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Rect _targetRect() {
    final box = widget.tips[_index].target.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Rect.zero;
    return (box.localToGlobal(Offset.zero) & box.size).inflate(8);
  }

  void _next() {
    unawaited(HapticFeedback.selectionClick());
    if (_index == widget.tips.length - 1) {
      widget.onDone();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final screen = MediaQuery.sizeOf(context);
    final target = _targetRect();
    final tip = widget.tips[_index];
    final below = target.center.dy < screen.height / 2; // card on the roomier side of the target
    const cardWidth = 320.0;
    final left = (target.center.dx - cardWidth / 2).clamp(16.0, screen.width - cardWidth - 16);
    final last = _index == widget.tips.length - 1;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Scrim with a spotlight hole that glides between targets and gently pulses.
          Positioned.fill(
            child: GestureDetector(
              onTap: _next,
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: target),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                builder: (context, rect, _) => AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(painter: _SpotlightPainter(rect ?? target, _pulse.value, colors.primary)),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            left: left,
            top: below ? target.bottom + 16 : null,
            bottom: below ? null : screen.height - target.top + 16,
            width: cardWidth,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_index),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0, 1),
                child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
              ),
              child: Card(
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates_rounded, color: colors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(tip.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(tip.text, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.4)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 0; i < widget.tips.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(right: 4),
                              width: i == _index ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _index ? colors.primary : colors.primary.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          const Spacer(),
                          if (!last) TextButton(onPressed: widget.onDone, child: const Text('Skip')),
                          FilledButton(onPressed: _next, child: Text(last ? 'Got it' : 'Next')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.hole, this.pulse, this.color);

  final Rect hole;
  final double pulse; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, const Radius.circular(18));
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = Colors.black.withValues(alpha: 0.62));
    canvas.drawRRect(
      rrect.inflate(2 + 4 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: 0.9 - 0.5 * pulse),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole || old.pulse != pulse;
}
