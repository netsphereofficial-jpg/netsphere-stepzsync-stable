import 'package:flutter/material.dart';
import '../widgets/draggable_manual_sync_button.dart';

/// Manual Sync Button Overlay Manager
///
/// Manages the lifecycle and visibility of the draggable manual sync button
/// across different screens in the app.
///
/// Usage:
/// - Call `ManualSyncButtonOverlayManager.show(context)` to display button
/// - Call `ManualSyncButtonOverlayManager.hide()` to remove button
/// - Button automatically persists across navigation
class ManualSyncButtonOverlayManager {
  static OverlayEntry? _overlayEntry;
  static bool _isVisible = false;

  /// Show the draggable manual sync button
  static void show(BuildContext context) {
    if (_isVisible) {
      print('⚠️ Manual sync button is already visible');
      return;
    }

    try {
      _overlayEntry = OverlayEntry(
        builder: (context) => Material(
          type: MaterialType.transparency,
          child: Stack(
            children: const [
              DraggableManualSyncButton(),
            ],
          ),
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
      _isVisible = true;
      print('✅ Manual sync button overlay inserted');
    } catch (e) {
      print('❌ Error showing manual sync button overlay: $e');
    }
  }

  /// Hide the draggable manual sync button
  static void hide() {
    if (!_isVisible || _overlayEntry == null) {
      print('⚠️ Manual sync button is already hidden or not initialized');
      return;
    }

    try {
      _overlayEntry?.remove();
      _overlayEntry?.dispose();
      _overlayEntry = null;
      _isVisible = false;
      print('✅ Manual sync button overlay removed');
    } catch (e) {
      print('❌ Error hiding manual sync button overlay: $e');
      // Force cleanup even if error occurs
      _overlayEntry = null;
      _isVisible = false;
    }
  }

  /// Check if button is currently visible
  static bool get isVisible => _isVisible;

  /// Toggle button visibility
  static void toggle(BuildContext context) {
    if (_isVisible) {
      hide();
    } else {
      show(context);
    }
  }

  /// Cleanup - should be called when app is closing
  static void dispose() {
    hide();
  }
}
