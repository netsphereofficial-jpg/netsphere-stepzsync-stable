import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../services/step_tracking_service.dart';
import '../painters/sync_progress_ring_painter.dart';

/// Flippable widget wrapper for the center step circle
///
/// Provides 3D flip animation to reveal manual sync button on the back
/// Front: Normal step progress circle
/// Back: Manual sync button with status
class FlippableSyncCircleWidget extends StatefulWidget {
  // Child widget (the progress indicator from StatisticsCardWidget)
  final Widget frontWidget;

  // Animation controllers passed from parent
  final AnimationController syncProgressAnimationController;

  const FlippableSyncCircleWidget({
    super.key,
    required this.frontWidget,
    required this.syncProgressAnimationController,
  });

  @override
  State<FlippableSyncCircleWidget> createState() => _FlippableSyncCircleWidgetState();
}

class _FlippableSyncCircleWidgetState extends State<FlippableSyncCircleWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _isFlipped = false;
  Timer? _autoFlipTimer;
  Timer? _countdownTimer;

  // Get step tracking service
  late StepTrackingService _stepTrackingService;

  // Countdown state
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();

    // Get step tracking service
    _stepTrackingService = Get.find<StepTrackingService>();

    // Initialize flip animation
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _flipController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Initialize glow animation (to indicate interactivity)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Start glow animation loop
    _glowController.repeat(reverse: true);

    // Schedule random auto-flips
    _scheduleNextAutoFlip();

    // Listen for sync completion to auto-flip back
    ever(_stepTrackingService.isManualSyncing, (bool syncing) {
      if (!syncing && _isFlipped && _stepTrackingService.syncSuccess.value) {
        // Sync completed successfully - flip back after 1 second
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && _isFlipped) {
            _flipBack();
          }
        });
      }
    });

    // Start countdown timer when on cooldown
    _startCountdownTimer();
  }

  void _scheduleNextAutoFlip() {
    // Cancel existing timer
    _autoFlipTimer?.cancel();

    // Random interval between 30-90 seconds
    final randomSeconds = 30 + math.Random().nextInt(61);

    _autoFlipTimer = Timer(Duration(seconds: randomSeconds), () {
      if (mounted && !_isFlipped && !_stepTrackingService.isManualSyncing.value) {
        _flipToBack();
        // Auto flip back after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isFlipped) {
            _flipBack();
          }
        });
      }
      // Schedule next auto-flip
      _scheduleNextAutoFlip();
    });
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_stepTrackingService.canManualSync) {
        setState(() {
          _secondsRemaining = _stepTrackingService.secondsUntilManualSync;
        });
      } else {
        setState(() {
          _secondsRemaining = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _glowController.dispose();
    _autoFlipTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_stepTrackingService.isManualSyncing.value) return;

    HapticFeedback.mediumImpact();

    if (_isFlipped) {
      // Already flipped - do nothing, let user interact with buttons
    } else {
      // Flip to back
      _flipToBack();
    }
  }

  void _flipToBack() {
    if (!mounted || _isFlipped) return;

    setState(() {
      _isFlipped = true;
    });

    _flipController.forward();
  }

  void _flipBack() {
    if (!mounted || !_isFlipped) return;

    _flipController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isFlipped = false;
        });
      }
    });
  }

  Future<void> _handleSyncButtonPress() async {
    if (_stepTrackingService.isManualSyncing.value) return;
    if (!_stepTrackingService.canManualSync) return;

    HapticFeedback.lightImpact();

    // Trigger manual sync
    final success = await _stepTrackingService.manualSyncHealthData();

    if (success) {
      // Success haptic
      HapticFeedback.mediumImpact();
    } else {
      // Error haptic
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flipAnimation, _glowAnimation]),
        builder: (context, child) {
          // Calculate rotation angle (0 to π radians)
          final angle = _flipAnimation.value * math.pi;

          // Determine which side to show
          final isFrontVisible = angle <= math.pi / 2;

          // Calculate transform for 3D rotation
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateY(angle);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Glowing ring indicator (shows when not flipped and not syncing)
              if (!_isFlipped && !_stepTrackingService.isManualSyncing.value)
                _buildGlowingIndicator(),

              // Main flipping content
              Transform(
                transform: transform,
                alignment: Alignment.center,
                child: isFrontVisible
                    ? _buildFrontSide()
                    : Transform(
                        // Flip the back side so content is readable
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: _buildBackSide(),
                      ),
              ),

              // Sync progress ring overlay (shows during sync)
              Obx(() {
                if (_stepTrackingService.isManualSyncing.value) {
                  return _buildSyncProgressRing();
                }
                return const SizedBox.shrink();
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFrontSide() {
    return widget.frontWidget;
  }

  Widget _buildBackSide() {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF2759FF),
            Color(0xFF1a4ae6),
            Color(0xFF0d3bd3),
          ],
          stops: [0.0, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2759FF).withValues(alpha: 0.4),
            blurRadius: 25,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: const Color(0xFFCDFF49).withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFCDFF49).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Obx(() {
          final canSync = _stepTrackingService.canManualSync;
          final isSyncing = _stepTrackingService.isManualSyncing.value;
          final syncSuccess = _stepTrackingService.syncSuccess.value;
          final syncError = _stepTrackingService.syncError.value;
          final statusMessage = _stepTrackingService.syncStatusMessage.value;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon (smaller)
                if (isSyncing)
                  _buildSyncingIcon()
                else if (syncSuccess)
                  _buildSuccessIcon()
                else if (syncError)
                  _buildErrorIcon()
                else
                  _buildSyncIcon(),

                const SizedBox(height: 6),

                // Status text (compact)
                if (isSyncing || syncSuccess || syncError)
                  Flexible(
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: syncError ? Colors.red.shade300 : Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else if (canSync)
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tap to Sync',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getLastSyncText(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Cooldown',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_secondsRemaining}s',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFCDFF49),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                // Sync button (only show when can sync and not syncing)
                if (canSync && !isSyncing && !syncSuccess)
                  _buildSyncButton(),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSyncIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFCDFF49).withValues(alpha: 0.2),
      ),
      child: const Icon(
        Icons.cloud_sync,
        size: 24,
        color: Color(0xFFCDFF49),
      ),
    );
  }

  Widget _buildSyncingIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCDFF49)),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green.withValues(alpha: 0.2),
      ),
      child: const Icon(
        Icons.check_circle,
        size: 24,
        color: Colors.green,
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red.withValues(alpha: 0.2),
      ),
      child: Icon(
        Icons.error,
        size: 24,
        color: Colors.red.shade300,
      ),
    );
  }

  Widget _buildSyncButton() {
    return GestureDetector(
      onTap: _handleSyncButtonPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFCDFF49),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFCDFF49).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync, size: 14, color: Colors.black87),
            SizedBox(width: 4),
            Text(
              'Sync',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingIndicator() {
    final glowIntensity = _glowAnimation.value;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCDFF49).withValues(alpha: 0.2 + (glowIntensity * 0.3)),
                blurRadius: 20 + (glowIntensity * 10),
                spreadRadius: 2 + (glowIntensity * 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncProgressRing() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: widget.syncProgressAnimationController,
        builder: (context, child) {
          return Obx(() {
            final progress = _stepTrackingService.syncProgress.value;
            final isIndeterminate = progress < 0.2; // First phase is indeterminate

            return CustomPaint(
              painter: SyncProgressRingPainter(
                progress: progress,
                animationValue: widget.syncProgressAnimationController.value,
                isIndeterminate: isIndeterminate,
              ),
            );
          });
        },
      ),
    );
  }

  String _getLastSyncText() {
    final lastSync = _stepTrackingService.lastManualSyncTime.value;
    if (lastSync == null) {
      return 'Never synced';
    }

    final difference = DateTime.now().difference(lastSync);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
