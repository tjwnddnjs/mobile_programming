import 'dart:math';

import 'package:flutter/material.dart';

import '../ui/tiki_theme.dart';

class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({
    super.key,
    required this.label,
    this.color = Tiki.blue,
  });

  final String label;
  final Color color;

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  static const _avatars = [
    'assets/tikitalk/thinking_6041.png',
    'assets/tikitalk/thinking_6042.png',
    'assets/tikitalk/thinking_6043.png',
  ];

  late final String _avatar = _avatars[Random().nextInt(_avatars.length)];
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _dots.stop();
    } else if (!_dots.isAnimating) {
      _dots.repeat();
    }
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      label: widget.label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4),
        child: TikiPanel(
          color: widget.color,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Image.asset(_avatar,
                    width: 68, height: 72, fit: BoxFit.contain),
                const SizedBox(width: 10),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Tiki.white,
                      border: Border.all(color: Tiki.ink),
                      borderRadius: Tiki.radius,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.label, style: Tiki.label),
                          const SizedBox(height: 4),
                          AnimatedBuilder(
                            animation: _dots,
                            builder: (context, child) => Row(
                              children: List.generate(3, (index) {
                                final phase =
                                    2 * pi * (_dots.value - index / 5);
                                return Transform.translate(
                                  offset: Offset(0,
                                      animate ? -3 * max(0.0, sin(phase)) : 0),
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 5),
                                    child: Icon(Icons.circle,
                                        size: 6, color: Tiki.ink),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
