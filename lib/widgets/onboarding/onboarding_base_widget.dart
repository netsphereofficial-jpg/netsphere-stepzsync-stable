import 'package:flutter/material.dart';

/// Reusable base widget for onboarding screens
/// Provides consistent layout and styling across all onboarding screens
class OnboardingBaseWidget extends StatelessWidget {
  final IconData icon;
  final Color iconBackgroundColor;
  final String title;
  final String subtitle;
  final List<OnboardingStep> steps;
  final String infoBoxText;
  final String primaryButtonText;
  final VoidCallback onPrimaryButtonPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryButtonPressed;
  final bool isLoading;
  final double progress; // 0.0 to 1.0
  final String stepIndicatorText; // e.g., "1 of 3"

  const OnboardingBaseWidget({
    Key? key,
    required this.icon,
    required this.iconBackgroundColor,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.infoBoxText,
    required this.primaryButtonText,
    required this.onPrimaryButtonPressed,
    this.secondaryButtonText,
    this.onSecondaryButtonPressed,
    this.isLoading = false,
    required this.progress,
    required this.stepIndicatorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon in circle
                    _buildIconSection(),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2759FF), // Primary blue
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: Color(0xFF7788B3), // Secondary blue
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Steps
                    ...steps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < steps.length - 1 ? 24 : 0,
                        ),
                        child: _buildStep(index + 1, step),
                      );
                    }).toList(),

                    const SizedBox(height: 40),

                    // Info box
                    _buildInfoBox(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  /// Build progress indicator at top
  Widget _buildProgressIndicator() {
    return Column(
      children: [
        // Step indicator text
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            stepIndicatorText,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF7788B3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Progress bar
        LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFFEFF2F8),
          valueColor: const AlwaysStoppedAnimation<Color>(
            Color(0xFF2759FF), // Primary blue
          ),
          minHeight: 4,
        ),
      ],
    );
  }

  /// Build icon section with circular background
  Widget _buildIconSection() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: iconBackgroundColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 40,
        color: iconBackgroundColor,
      ),
    );
  }

  /// Build individual step with number badge
  Widget _buildStep(int number, OnboardingStep step) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2759FF), // Primary blue
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Step content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step icon and title
              Row(
                children: [
                  Icon(
                    step.icon,
                    size: 20,
                    color: const Color(0xFF2759FF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3F4E75), // Label color
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Step description
              Text(
                step.description,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xFF7788B3), // Secondary blue
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build info box
  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F8), // Field background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 20,
            color: Color(0xFF2759FF), // Primary blue
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              infoBoxText,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF3F4E75), // Label color
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build bottom action buttons
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : onPrimaryButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2759FF), // Primary blue
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: const Color(0xFF9CA3AF),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      primaryButtonText,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          // Secondary button (if provided)
          if (secondaryButtonText != null && onSecondaryButtonPressed != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: isLoading ? null : onSecondaryButtonPressed,
                child: Text(
                  secondaryButtonText!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Color(0xFF7788B3), // Secondary blue
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Model for individual onboarding steps
class OnboardingStep {
  final IconData icon;
  final String title;
  final String description;

  const OnboardingStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}
