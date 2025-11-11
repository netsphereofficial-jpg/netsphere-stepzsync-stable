import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/step_tracking_service.dart';

/// Draggable Manual Sync Button
///
/// Features:
/// - Draggable with free positioning anywhere on screen
/// - Shows "Sync" text instead of logo
/// - Animated pulse effect to indicate availability
/// - Shows sync status (idle, syncing, success, error)
/// - Persists position across app restarts
/// - Cooldown timer display when sync is unavailable
class DraggableManualSyncButton extends StatefulWidget {
  const DraggableManualSyncButton({super.key});

  @override
  State<DraggableManualSyncButton> createState() => _DraggableManualSyncButtonState();
}

class _DraggableManualSyncButtonState extends State<DraggableManualSyncButton>
    with SingleTickerProviderStateMixin {
  // Position state
  Offset _position = const Offset(300, 600); // Default position
  bool _isDragging = false;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  // Step tracking service
  late StepTrackingService _stepTrackingService;

  // Countdown timer
  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  // Preferences for position persistence
  static const String _positionXKey = 'manual_sync_button_x';
  static const String _positionYKey = 'manual_sync_button_y';

  @override
  void initState() {
    super.initState();

    // Get step tracking service
    _stepTrackingService = Get.find<StepTrackingService>();

    // Load saved position or use default
    _loadSavedPosition();

    // Initialize pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 6.28).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.linear,
      ),
    );

    // Start pulse animation loop
    _pulseController.repeat(reverse: true);

    // Start countdown timer
    _startCountdownTimer();
  }

  Future<void> _loadSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedX = prefs.getDouble(_positionXKey);
      final savedY = prefs.getDouble(_positionYKey);

      if (savedX != null && savedY != null && mounted) {
        setState(() {
          _position = Offset(savedX, savedY);
        });
      } else if (mounted) {
        // Default position: bottom right corner
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final screenSize = MediaQuery.of(context).size;
            setState(() {
              _position = Offset(
                screenSize.width - 100,
                screenSize.height - 200,
              );
            });
          }
        });
      }
    } catch (e) {
      print('Error loading manual sync button position: $e');
    }
  }

  Future<void> _savePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_positionXKey, _position.dx);
      await prefs.setDouble(_positionYKey, _position.dy);
    } catch (e) {
      print('Error saving manual sync button position: $e');
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final canSync = _stepTrackingService.canManualSync;
        final seconds = _stepTrackingService.secondsUntilManualSync;

        if (!canSync && seconds > 0) {
          setState(() {
            _secondsRemaining = seconds;
          });
        } else if (canSync) {
          setState(() {
            _secondsRemaining = 0;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSyncButtonPress() async {
    if (_stepTrackingService.isManualSyncing.value) return;

    if (!_stepTrackingService.canManualSync) {
      // Show cooldown message
      HapticFeedback.heavyImpact();

      return;
    }

    HapticFeedback.mediumImpact();

    // Trigger manual sync
    final success = await _stepTrackingService.manualSyncHealthData();

    if (success) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
          HapticFeedback.selectionClick();
        },
        onPanUpdate: (details) {
          setState(() {
            // Update position with boundary constraints
            final newX = (_position.dx + details.delta.dx)
                .clamp(0.0, screenSize.width - 80);
            final newY = (_position.dy + details.delta.dy)
                .clamp(0.0, screenSize.height - 80);
            _position = Offset(newX, newY);
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
          _savePosition();
          HapticFeedback.selectionClick();
        },
        onTap: _handleSyncButtonPress,
        child: Obx(() {
          final isSyncing = _stepTrackingService.isManualSyncing.value;
          final syncSuccess = _stepTrackingService.syncSuccess.value;
          final syncError = _stepTrackingService.syncError.value;
          final canSync = _stepTrackingService.canManualSync;

          return AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isDragging ? 1.15 : (isSyncing ? 1.0 : _pulseAnimation.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: RadialGradient(
                      colors: _getGradientColors(isSyncing, syncSuccess, syncError, canSync),
                      stops: const [0.0, 0.7, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getShadowColor(isSyncing, syncSuccess, syncError, canSync)
                            .withValues(alpha: _isDragging ? 0.6 : 0.4),
                        blurRadius: _isDragging ? 25 : (isSyncing ? 20 : 15),
                        spreadRadius: _isDragging ? 8 : (isSyncing ? 5 : 3),
                      ),
                      if (!isSyncing && canSync)
                        BoxShadow(
                          color: const Color(0xFFCDFF49).withValues(
                            alpha: 0.25 * _pulseAnimation.value,
                          ),
                          blurRadius: 30 * _pulseAnimation.value,
                          spreadRadius: 8 * _pulseAnimation.value,
                        ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSyncIcon(isSyncing, syncSuccess, syncError, canSync),
                        const SizedBox(width: 8),
                        _buildSyncText(isSyncing, syncSuccess, syncError, canSync),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  List<Color> _getGradientColors(bool isSyncing, bool syncSuccess, bool syncError, bool canSync) {
    if (syncSuccess && !isSyncing) {
      return [
        const Color(0xFF00C853),
        const Color(0xFF00A344),
        const Color(0xFF008936),
      ];
    }

    if (syncError && !isSyncing) {
      return [
        const Color(0xFFFF5252),
        const Color(0xFFE53935),
        const Color(0xFFD32F2F),
      ];
    }

    if (!canSync) {
      return [
        const Color(0xFF9E9E9E),
        const Color(0xFF757575),
        const Color(0xFF616161),
      ];
    }

    return [
      const Color(0xFF2759FF),
      const Color(0xFF1a4ae6),
      const Color(0xFF0d3bd3),
    ];
  }

  Color _getShadowColor(bool isSyncing, bool syncSuccess, bool syncError, bool canSync) {
    if (syncSuccess && !isSyncing) return const Color(0xFF00C853);
    if (syncError && !isSyncing) return const Color(0xFFFF5252);
    if (!canSync) return const Color(0xFF9E9E9E);
    return const Color(0xFF2759FF);
  }

  Widget _buildSyncIcon(bool isSyncing, bool syncSuccess, bool syncError, bool canSync) {
    // Show syncing state with rotating animation
    if (isSyncing) {
      return Transform.rotate(
        angle: _rotateAnimation.value,
        child: const Icon(
          Icons.sync,
          color: Color(0xFFCDFF49),
          size: 20,
        ),
      );
    }

    // Show success state (briefly)
    if (syncSuccess && !isSyncing) {
      return const Icon(
        Icons.check_circle_rounded,
        color: Colors.white,
        size: 20,
      );
    }

    // Show error state (briefly)
    if (syncError && !isSyncing) {
      return const Icon(
        Icons.error_rounded,
        color: Colors.white,
        size: 20,
      );
    }

    // Show cooldown timer icon
    if (!canSync) {
      return Icon(
        Icons.timer,
        color: Colors.white.withValues(alpha: 0.6),
        size: 20,
      );
    }

    // Default: Show sync icon with pulse
    return const Icon(
      Icons.cloud_sync_rounded,
      color: Color(0xFFCDFF49),
      size: 20,
    );
  }

  Widget _buildSyncText(bool isSyncing, bool syncSuccess, bool syncError, bool canSync) {
    String text = 'Sync';
    Color textColor = const Color(0xFFCDFF49);

    if (isSyncing) {
      text = 'Syncing...';
      textColor = const Color(0xFFCDFF49);
    } else if (syncSuccess && !isSyncing) {
      text = 'Success!';
      textColor = Colors.white;
    } else if (syncError && !isSyncing) {
      text = 'Failed';
      textColor = Colors.white;
    } else if (!canSync) {
      text = '${_secondsRemaining}s';
      textColor = Colors.white.withValues(alpha: 0.8);
    }

    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: 0.5,
      ),
    );
  }
}
