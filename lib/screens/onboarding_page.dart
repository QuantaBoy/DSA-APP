import 'package:flutter/material.dart';

import 'motion.dart';

const _slides = [
  (
    image: 'assets/illustrations/onboard_solve.png',
    title: 'Solve with a plan',
    text: "Follow Striver's A2Z sheet step by step, and code and run every problem right in the app.",
  ),
  (
    image: 'assets/illustrations/onboard_review.png',
    title: 'Review on schedule',
    text: 'Each solved problem comes back after 1, 3, 7, 14, 30… days, just before you would forget it.',
  ),
  (
    image: 'assets/illustrations/onboard_progress.png',
    title: 'Watch it stick',
    text: 'Streaks, recall rate and your weakest topics show exactly where to focus next.',
  ),
];

/// First-launch intro: three slides, then [onDone] (which shows sign-in).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _page == _slides.length - 1
      ? widget.onDone()
      : _pages.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(onPressed: last ? null : widget.onDone, child: const Text('Skip')),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(children: [
                        Expanded(child: Bob(height: 8, child: Image.asset(s.image, fit: BoxFit.contain))),
                        const SizedBox(height: 12),
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6, color: colors.primary)),
                        const SizedBox(height: 10),
                        Text(s.text, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant, height: 1.45)),
                        const SizedBox(height: 28),
                      ]),
                    );
                  },
                ),
              ),
              // Page dots: the current one stretches into a pill.
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? colors.primary : colors.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: last
                      ? FilledButton.icon(
                          key: const ValueKey('start'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                          onPressed: widget.onDone,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Get started'),
                        )
                      : Row(key: const ValueKey('next'), children: [
                          Text('${_page + 1} / ${_slides.length}', style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(64, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                            onPressed: _next,
                            child: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
