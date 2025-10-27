import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickValidation {
  static OverlayEntry? _currentOverlay;

  static void showError(BuildContext context, String message) {
    _showValidation(context, message, ValidationStyle.error);
  }

  static void showSuccess(BuildContext context, String message) {
    _showValidation(context, message, ValidationStyle.success);
  }

  static void showWarning(BuildContext context, String message) {
    _showValidation(context, message, ValidationStyle.warning);
  }

  static void _showValidation(BuildContext context, String message, ValidationStyle style) {
    // Remove any existing validation
    _currentOverlay?.remove();

    // Add haptic feedback
    HapticFeedback.lightImpact();

    try {
      // Find the nearest Navigator's overlay
      final NavigatorState? navigator = Navigator.maybeOf(context);
      if (navigator == null) {
        // Fallback to print if no Navigator found
        print('QuickValidation: $message');
        return;
      }

      final OverlayState? overlayState = navigator.overlay;
      if (overlayState == null) {
        // Fallback to print if no Overlay found
        print('QuickValidation: $message');
        return;
      }

      _currentOverlay = OverlayEntry(
        builder: (context) => _ValidationOverlay(
          message: message,
          style: style,
          onDismiss: () {
            _currentOverlay?.remove();
            _currentOverlay = null;
          },
        ),
      );

      overlayState.insert(_currentOverlay!);

      // Auto dismiss after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        _currentOverlay?.remove();
        _currentOverlay = null;
      });
    } catch (e) {
      // Fallback to print if overlay insertion fails
      print('QuickValidation: $message (Error: $e)');
    }
  }

  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

enum ValidationStyle {
  error,
  success,
  warning,
}

class _ValidationOverlay extends StatefulWidget {
  final String message;
  final ValidationStyle style;
  final VoidCallback onDismiss;

  const _ValidationOverlay({
    required this.message,
    required this.style,
    required this.onDismiss,
  });

  @override
  State<_ValidationOverlay> createState() => _ValidationOverlayState();
}

class _ValidationOverlayState extends State<_ValidationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Auto dismiss animation
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    _controller.reverse().then((_) => widget.onDismiss());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: _getBackgroundColor(),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: _getBorderColor(),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _getAccentColor(),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          _getIcon(),
                          color: _getAccentColor(),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: _getTextColor(),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (widget.style) {
      case ValidationStyle.error:
        return Colors.white;
      case ValidationStyle.success:
        return Colors.white;
      case ValidationStyle.warning:
        return Colors.white;
    }
  }

  Color _getBorderColor() {
    switch (widget.style) {
      case ValidationStyle.error:
        return const Color(0xFFFECACA);
      case ValidationStyle.success:
        return const Color(0xFFBBF7D0);
      case ValidationStyle.warning:
        return const Color(0xFFFEDBA6);
    }
  }

  Color _getAccentColor() {
    switch (widget.style) {
      case ValidationStyle.error:
        return const Color(0xFFDC2626);
      case ValidationStyle.success:
        return const Color(0xFF16A34A);
      case ValidationStyle.warning:
        return const Color(0xFFEA580C);
    }
  }

  Color _getTextColor() {
    switch (widget.style) {
      case ValidationStyle.error:
        return const Color(0xFF991B1B);
      case ValidationStyle.success:
        return const Color(0xFF166534);
      case ValidationStyle.warning:
        return const Color(0xFF9A3412);
    }
  }

  IconData _getIcon() {
    switch (widget.style) {
      case ValidationStyle.error:
        return Icons.error_outline;
      case ValidationStyle.success:
        return Icons.check_circle_outline;
      case ValidationStyle.warning:
        return Icons.warning_amber_outlined;
    }
  }
}