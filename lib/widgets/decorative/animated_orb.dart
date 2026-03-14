import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Performance-optimized animated gradient orb
///
/// CRITICAL: Wrapped in RepaintBoundary to isolate animations
/// and prevent parent widget repaints.
///
/// Usage:
/// ```dart
/// AnimatedOrb(
///   size: 256,
///   color: AppColors.blue500,
///   position: Alignment.topLeft,
///   offset: Offset(-80, -80),
/// )
/// ```
class AnimatedOrb extends StatefulWidget {
  final double size;
  final Color color;
  final Alignment position;
  final Offset offset;
  final double opacity;
  final Duration duration;

  const AnimatedOrb({
    super.key,
    required this.size,
    required this.color,
    this.position = Alignment.center,
    this.offset = Offset.zero,
    this.opacity = 0.15,
    this.duration = const Duration(seconds: 8),
  });

  @override
  State<AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<AnimatedOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: widget.opacity * 0.7,
      end: widget.opacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
      _controller.reset();
    // Guard against re-entrant calls on subsequent dependency changes
    // (e.g., theme or MediaQuery updates after initial mount).
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // CRITICAL: RepaintBoundary isolates animation repaints
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: reduceMotion
            ? const AlwaysStoppedAnimation(0.0)
            : _controller,
        builder: (context, child) {
          final scale = reduceMotion ? 1.0 : _scaleAnimation.value;
          final opacity =
              reduceMotion ? widget.opacity : _opacityAnimation.value;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withValues(alpha: opacity),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Static orb for reduced motion preference
///
/// Usage:
/// ```dart
/// StaticOrb(
///   size: 200,
///   color: AppColors.indigo500,
/// )
/// ```
class StaticOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const StaticOrb({
    super.key,
    required this.size,
    required this.color,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Decorative orb pair for hero sections
///
/// Includes both top-left and bottom-right orbs with
/// automatic reduced motion detection.
///
/// Usage:
/// ```dart
/// Stack(
///   children: [
///     DecorativeOrbs(),
///     HeroContent(),
///   ],
/// )
/// ```
class DecorativeOrbs extends StatelessWidget {
  final bool animate;

  const DecorativeOrbs({
    super.key,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    // Check for reduced motion preference
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate = animate && !reduceMotion;

    if (shouldAnimate) {
      return const Positioned.fill(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -80,
              top: -80,
              child: AnimatedOrb(
                size: 256,
                color: AppColors.blue500,
                position: Alignment.topLeft,
                offset: Offset(-80, -80),
              ),
            ),
            Positioned(
              right: -60,
              bottom: 100,
              child: AnimatedOrb(
                size: 200,
                color: AppColors.indigo500,
                position: Alignment.bottomRight,
                offset: Offset(-60, 100),
                duration: Duration(seconds: 10),
              ),
            ),
          ],
        ),
      );
    }

    // Static fallback for reduced motion
    return const Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -80,
            top: -80,
            child: StaticOrb(
              size: 256,
              color: AppColors.blue500,
            ),
          ),
          Positioned(
            right: -60,
            bottom: 100,
            child: StaticOrb(
              size: 200,
              color: AppColors.indigo500,
            ),
          ),
        ],
      ),
    );
  }
}
