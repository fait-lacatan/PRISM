import 'package:flutter/material.dart';

class AnimatedCounter extends StatelessWidget {
  final double value;
  final String suffix;
  final TextStyle? style;
  final int decimals;

  const AnimatedCounter({super.key, required this.value, this.suffix = '', this.style, this.decimals = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return Text(
          '${val.toStringAsFixed(decimals)}$suffix',
          style: style,
        );
      },
    );
  }
}
