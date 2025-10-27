import 'package:flutter/material.dart';

/// ✅ OPTIMIZATION: Simple loading overlay for race map
/// Shows clean white screen while map/route/markers load
/// Smooth fade-out animation for polished UX
class RaceMapShimmer extends StatefulWidget {
  final int loadingState; // 0=initial, 1=map, 2=route, 3=markers, 4=done

  const RaceMapShimmer({
    super.key,
    required this.loadingState,
  });

  @override
  State<RaceMapShimmer> createState() => _RaceMapShimmerState();
}

class _RaceMapShimmerState extends State<RaceMapShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(RaceMapShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Start fade-out animation when state reaches 4 (fully loaded)
    if (widget.loadingState == 4 && oldWidget.loadingState != 4) {
      _controller.forward();
    }
    // Reset if state goes back (shouldn't happen, but defensive)
    else if (widget.loadingState < 4 && oldWidget.loadingState == 4) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show shimmer once animation completes
    if (_controller.isCompleted) {
      return const SizedBox.shrink();
    }

    // Show full white overlay until state 4, then smooth fade
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = widget.loadingState < 4 ? 1.0 : _animation.value;

        if (opacity <= 0.0) {
          return const SizedBox.shrink();
        }

        return Opacity(
          opacity: opacity,
          child: Container(
            color: Colors.white,
          ),
        );
      },
    );
  }
}
