import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

String friendlyError(Object error) => error is ApiException
    ? error.message
    : 'Algo não saiu como esperado. Tente novamente.';

class GameBackdrop extends StatelessWidget {
  const GameBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.7, -0.8),
              radius: 1.7,
              colors: [Color(0xFF1B2D3B), GameColors.background],
            ),
          ),
        ),
      ),
      Positioned(
        top: -130,
        right: -135,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.10,
            child: SigilMark(size: 420, color: GameColors.gold),
          ),
        ),
      ),
      Positioned.fill(child: child),
    ],
  );
}

class SigilMark extends StatelessWidget {
  const SigilMark({super.key, this.size = 86, this.color = GameColors.gold});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: Size.square(size), painter: _SigilPainter(color)),
  );
}

class _SigilPainter extends CustomPainter {
  const _SigilPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.45;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width / 110);
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.72, paint);
    canvas.drawCircle(center, radius * 0.12, paint);
    final star = Path();
    for (var index = 0; index < 6; index++) {
      final angle = index * math.pi / 3 - math.pi / 2;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.72;
      if (index == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, paint);
    for (var index = 0; index < 8; index++) {
      final angle = index * math.pi / 4;
      final inner =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.82;
      final outer =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.98;
      canvas.drawLine(inner, outer, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SigilPainter oldDelegate) =>
      oldDelegate.color != color;
}

class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.accent,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GameColors.surfaceRaised, GameColors.surface],
        ),
        border: Border.all(
          color: accent?.withValues(alpha: 0.65) ?? GameColors.border,
        ),
        borderRadius: BorderRadius.circular(GameLayout.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GameLayout.radius),
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: panel,
      ),
    );
  }
}

class GameBadge extends StatelessWidget {
  const GameBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.tooltip,
  });
  final String label;
  final IconData icon;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: GameColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

class GameProgressBar extends StatelessWidget {
  const GameProgressBar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.label,
    this.height = 12,
    this.animationKey,
  });
  final int value;
  final int max;
  final Color color;
  final String? label;
  final double height;
  final Key? animationKey;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Semantics(
      label: label == null ? '$value de $max' : '$label: $value de $max',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              '$label: $value / $max',
              style: const TextStyle(
                color: GameColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: TweenAnimationBuilder<double>(
              key: animationKey,
              tween: Tween<double>(end: fraction),
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => LinearProgressIndicator(
                value: progress,
                minHeight: height,
                color: color,
                backgroundColor: GameColors.background,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GameSectionHeading extends StatelessWidget {
  const GameSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, color: GameColors.gold),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    ],
  );
}

class GameLoadingView extends StatelessWidget {
  const GameLoadingView({
    super.key,
    this.message = 'Preparando sua jornada...',
  });
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SigilMark(size: 66),
        const SizedBox(height: 20),
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(height: 14),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class GameErrorView extends StatelessWidget {
  const GameErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: GamePanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: GameColors.warning,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class GameEmptyState extends StatelessWidget {
  const GameEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome,
  });
  final String title;
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: GamePanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: GameColors.gold),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
