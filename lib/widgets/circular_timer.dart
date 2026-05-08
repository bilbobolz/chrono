import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CircularTimer extends StatelessWidget {
  final double progress;
  final int remainingSeconds;
  final Color color;
  final bool isBreak;

  const CircularTimer({
    super.key,
    required this.progress,
    required this.remainingSeconds,
    required this.color,
    this.isBreak = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,
      height: 310,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 310,
            height: 310,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              backgroundColor: color.withAlpha(40),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTimer(remainingSeconds),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                isBreak ? 'Descanso' : 'Trabajo',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      letterSpacing: 1,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
