import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../animations/sync_animation_widget.dart';
import '../../models/health_sync_models.dart';

/// Health sync dialog with beautiful animations
///
/// Shows a full-screen overlay with sync progress
/// Non-dismissible until sync completes
class HealthSyncDialog extends StatefulWidget {
  final Stream<HealthSyncStatus> syncStatusStream;
  final VoidCallback? onSyncComplete;

  const HealthSyncDialog({
    super.key,
    required this.syncStatusStream,
    this.onSyncComplete,
  });

  @override
  State<HealthSyncDialog> createState() => _HealthSyncDialogState();

  /// Show the sync dialog
  static void show(
    BuildContext context, {
    required Stream<HealthSyncStatus> syncStatusStream,
    VoidCallback? onSyncComplete,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss during sync
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => HealthSyncDialog(
        syncStatusStream: syncStatusStream,
        onSyncComplete: onSyncComplete,
      ),
    );
  }
}

class _HealthSyncDialogState extends State<HealthSyncDialog>
    with SingleTickerProviderStateMixin {
  HealthSyncStatus _currentStatus = HealthSyncStatus.connecting;
  SyncAnimationPhase _currentPhase = SyncAnimationPhase.connecting;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();

    // Listen to sync status updates
    widget.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _currentPhase = _mapStatusToPhase(status);
        });

        // Auto-dismiss after completion
        if (status == HealthSyncStatus.completed) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              _dismissDialog();
            }
          });
        } else if (status == HealthSyncStatus.failed ||
            status == HealthSyncStatus.permissionDenied ||
            status == HealthSyncStatus.notAvailable) {
          // Dismiss on failure/notAvailable after showing error briefly
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _dismissDialog();
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  SyncAnimationPhase _mapStatusToPhase(HealthSyncStatus status) {
    switch (status) {
      case HealthSyncStatus.idle:
      case HealthSyncStatus.connecting:
        return SyncAnimationPhase.connecting;
      case HealthSyncStatus.syncing:
        return SyncAnimationPhase.syncing;
      case HealthSyncStatus.updating:
        return SyncAnimationPhase.updating;
      case HealthSyncStatus.completed:
        return SyncAnimationPhase.completed;
      case HealthSyncStatus.failed:
      case HealthSyncStatus.permissionDenied:
      case HealthSyncStatus.notAvailable:
        return SyncAnimationPhase.connecting;
    }
  }

  void _dismissDialog() {
    _fadeController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSyncComplete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated sync indicator
                SyncAnimationWidget(phase: _currentPhase),

                const SizedBox(height: 32),

                // Status text
                _buildStatusText(),

                const SizedBox(height: 16),

                // Description text
                _buildDescriptionText(),

                // Error handling
                if (_currentStatus == HealthSyncStatus.failed ||
                    _currentStatus == HealthSyncStatus.permissionDenied)
                  _buildErrorActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    String statusText;
    Color textColor;

    switch (_currentStatus) {
      case HealthSyncStatus.idle:
      case HealthSyncStatus.connecting:
        statusText = 'Connecting';
        textColor = const Color(0xFF2759FF);
        break;
      case HealthSyncStatus.syncing:
        statusText = 'Syncing Data';
        textColor = const Color(0xFF2759FF);
        break;
      case HealthSyncStatus.updating:
        statusText = 'Updating Stats';
        textColor = const Color(0xFF2759FF);
        break;
      case HealthSyncStatus.completed:
        statusText = 'Sync Complete!';
        textColor = Colors.green;
        break;
      case HealthSyncStatus.failed:
        statusText = 'Sync Failed';
        textColor = Colors.red;
        break;
      case HealthSyncStatus.permissionDenied:
        statusText = 'Permission Required';
        textColor = Colors.orange;
        break;
      case HealthSyncStatus.notAvailable:
        statusText = 'Not Available';
        textColor = Colors.grey;
        break;
    }

    return Text(
      statusText,
      style: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescriptionText() {
    String descriptionText;

    switch (_currentStatus) {
      case HealthSyncStatus.idle:
      case HealthSyncStatus.connecting:
        descriptionText = 'Connecting to Health services...';
        break;
      case HealthSyncStatus.syncing:
        descriptionText = 'Fetching your fitness data from Health Connect...';
        break;
      case HealthSyncStatus.updating:
        descriptionText = 'Calculating your statistics...';
        break;
      case HealthSyncStatus.completed:
        descriptionText = 'Your data has been synced successfully!';
        break;
      case HealthSyncStatus.failed:
        descriptionText = 'Failed to sync. Using pedometer data instead.';
        break;
      case HealthSyncStatus.permissionDenied:
        descriptionText = 'Please grant health permissions to sync data.';
        break;
      case HealthSyncStatus.notAvailable:
        descriptionText = 'Health services not available. If on iOS Simulator, please test on a real device.';
        break;
    }

    return Text(
      descriptionText,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.grey[600],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildErrorActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: _dismissDialog,
            child: Text(
              'Continue Anyway',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple sync progress indicator (alternative lightweight version)
class SimpleSyncDialog {
  static void show(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void dismiss(BuildContext context) {
    Navigator.of(context).pop();
  }
}
