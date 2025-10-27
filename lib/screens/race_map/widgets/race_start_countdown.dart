import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../../../config/app_colors.dart';

class RaceStartCountdown extends StatelessWidget {
  final DateTime scheduleTime;
  final bool isOrganizer;

  const RaceStartCountdown({
    super.key,
    required this.scheduleTime,
    this.isOrganizer = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final timeLeft = scheduleTime.difference(now);

        if (timeLeft.isNegative) {
          return const SizedBox.shrink();
        }

        final days = timeLeft.inDays;
        final hours = timeLeft.inHours % 24;
        final minutes = timeLeft.inMinutes % 60;
        final seconds = timeLeft.inSeconds % 60;

        // Determine if we're in the final countdown (less than 1 minute)
        final isFinalCountdown = timeLeft.inSeconds <= 60;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isFinalCountdown
                          ? [
                              Colors.orange.withValues(alpha: 0.7),
                              Colors.deepOrange.withValues(alpha: 0.7),
                            ]
                          : [
                              AppColors.appColor.withValues(alpha: 0.7),
                              AppColors.appColor.withValues(alpha: 0.65),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isFinalCountdown ? Colors.orange : AppColors.appColor)
                            .withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFinalCountdown ? Icons.warning_amber_rounded : Icons.timer_outlined,
                            color: Colors.white,
                            size: 18,
                          )
                              .animate(
                                onPlay: (controller) => controller.repeat(),
                              )
                              .scale(
                                duration: 1000.ms,
                                begin: const Offset(1.0, 1.0),
                                end: const Offset(1.2, 1.2),
                                curve: Curves.easeInOut,
                              )
                              .then()
                              .scale(
                                duration: 1000.ms,
                                begin: const Offset(1.2, 1.2),
                                end: const Offset(1.0, 1.0),
                                curve: Curves.easeInOut,
                              ),
                          const SizedBox(width: 8),
                          Text(
                            isFinalCountdown ? "RACE STARTING SOON!" : "RACE STARTS IN",
                            style: GoogleFonts.poppins(
                              fontSize: isFinalCountdown ? 13 : 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Countdown Timer Display
                      if (days > 0)
                        _buildTimerRow(days, hours, minutes, seconds, isFinalCountdown)
                      else if (hours > 0)
                        _buildTimerRowHMS(hours, minutes, seconds, isFinalCountdown)
                      else if (minutes > 0)
                        _buildTimerRowMS(minutes, seconds, isFinalCountdown)
                      else
                        _buildFinalSeconds(seconds),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Build timer row with days, hours, minutes, seconds
  Widget _buildTimerRow(int days, int hours, int minutes, int seconds, bool isFinalCountdown) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeUnit(days, "DAYS", isFinalCountdown),
        _buildTimeSeparator(),
        _buildTimeUnit(hours, "HRS", isFinalCountdown),
        _buildTimeSeparator(),
        _buildTimeUnit(minutes, "MIN", isFinalCountdown),
        _buildTimeSeparator(),
        _buildTimeUnit(seconds, "SEC", isFinalCountdown),
      ],
    );
  }

  // Build timer row with hours, minutes, seconds
  Widget _buildTimerRowHMS(int hours, int minutes, int seconds, bool isFinalCountdown) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeUnit(hours, "HRS", isFinalCountdown),
        _buildTimeSeparator(),
        _buildTimeUnit(minutes, "MIN", isFinalCountdown),
        _buildTimeSeparator(),
        _buildTimeUnit(seconds, "SEC", isFinalCountdown),
      ],
    );
  }

  // Build timer row with minutes and seconds
  Widget _buildTimerRowMS(int minutes, int seconds, bool isFinalCountdown) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeUnit(minutes, "MIN", isFinalCountdown),
        _buildTimeSeparator(),
        _buildTimeUnit(seconds, "SEC", isFinalCountdown),
      ],
    );
  }

  // Build final seconds countdown (large, animated)
  Widget _buildFinalSeconds(int seconds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Text(
        seconds.toString(),
        style: GoogleFonts.poppins(
          fontSize: 64,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1,
        ),
      )
          .animate(
            onPlay: (controller) => controller.repeat(),
          )
          .scale(
            duration: 500.ms,
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.15, 1.15),
            curve: Curves.easeOut,
          )
          .then()
          .scale(
            duration: 500.ms,
            begin: const Offset(1.15, 1.15),
            end: const Offset(1.0, 1.0),
            curve: Curves.easeIn,
          ),
    );
  }

  // Build individual time unit
  Widget _buildTimeUnit(int value, String label, bool isFinalCountdown) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // Build separator between time units
  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: Text(
        ":",
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.7),
          height: 1.5,
        ),
      ),
    );
  }
}
