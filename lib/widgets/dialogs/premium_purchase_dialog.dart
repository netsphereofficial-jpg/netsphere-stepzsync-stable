import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class PremiumPurchaseDialog {
  /// Show premium purchase dialog with Christmas special offer
  /// Expires: January 1, 2026
  static void show(BuildContext context) {
    // Check if offer is still valid
    final expirationDate = DateTime(2026, 1, 1);
    final now = DateTime.now();

    if (now.isAfter(expirationDate)) {
      // Offer expired, don't show dialog
      return;
    }

    Get.dialog(
      _PremiumPurchaseDialogContent(expirationDate: expirationDate),
      barrierDismissible: true,
    );
  }
}

class _PremiumPurchaseDialogContent extends StatefulWidget {
  final DateTime expirationDate;

  const _PremiumPurchaseDialogContent({
    required this.expirationDate,
  });

  @override
  State<_PremiumPurchaseDialogContent> createState() =>
      _PremiumPurchaseDialogContentState();
}

class _PremiumPurchaseDialogContentState
    extends State<_PremiumPurchaseDialogContent> {
  Timer? _timer;
  int _daysRemaining = 0;

  @override
  void initState() {
    super.initState();
    _updateDaysRemaining();
    // Update countdown every hour
    _timer = Timer.periodic(Duration(hours: 1), (_) {
      _updateDaysRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateDaysRemaining() {
    final now = DateTime.now();
    final difference = widget.expirationDate.difference(now);
    setState(() {
      _daysRemaining = difference.inDays;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFDF9), // Warm white
                  Color(0xFFFFF5E6), // Cream
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Christmas Header with decorative elements
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFDC143C), // Christmas red
                        Color(0xFFB91C1C), // Dark red
                        Color(0xFF991B1B), // Deeper red
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Close button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Get.back(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Decorative snowflakes
                      Positioned(
                        top: 10,
                        left: 20,
                        child: Opacity(
                          opacity: 0.6,
                          child: Text('❄️', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      Positioned(
                        top: 15,
                        right: 25,
                        child: Opacity(
                          opacity: 0.5,
                          child: Text('❄️', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      Positioned(
                        top: 35,
                        right: 45,
                        child: Opacity(
                          opacity: 0.7,
                          child: Text('✨', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      Positioned(
                        top: 30,
                        left: 45,
                        child: Opacity(
                          opacity: 0.6,
                          child: Text('⭐', style: TextStyle(fontSize: 12)),
                        ),
                      ),

                      // Main content
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
                        child: Column(
                          children: [
                            // Christmas tree with glow effect
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                '🎄',
                                style: TextStyle(fontSize: 32),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Christmas Special',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 6),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFFFD700).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_outlined, size: 15, color: Color(0xFFDC143C)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Ends in $_daysRemaining days ⏰',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Color(0xFFDC143C),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content with better spacing
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    children: [
                      // Pricing Section with better layout
                      Stack(
                        children: [
                          Column(
                            children: [
                              // Original price
                              Text(
                                '\$600',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[400],
                                  decoration: TextDecoration.lineThrough,
                                  decorationThickness: 3,
                                  decorationColor: Color(0xFFDC143C),
                                ),
                              ),
                              SizedBox(height: 2),
                              // New price
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text(
                                      '\$',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '299',
                                    style: GoogleFonts.poppins(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF16A34A),
                                      height: 0.85,
                                      letterSpacing: -2,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              // Lifetime badge with better shadow
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF16A34A).withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '♾️',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'LIFETIME • ONE-TIME',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // 50% OFF badge - better positioned
                          Positioned(
                            top: -4,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFDC143C), Color(0xFFB91C1C)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFDC143C).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '50% OFF',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      // Features - Better styling
                      Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFFE5E7EB), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildCompactFeature('🌍', 'Global Races Worldwide'),
                            _buildCompactFeature('🏆', 'Advanced Leaderboards'),
                            _buildCompactFeature('📊', 'Performance Analytics'),
                            _buildCompactFeature('🎯', 'Marathon Events'),
                            _buildCompactFeature('🚫', 'Ad-Free Forever', isLast: true),
                          ],
                        ),
                      ),

                      SizedBox(height: 18),

                      // CTA Button with better styling
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFDC143C), Color(0xFFB91C1C)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFDC143C).withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Get.back();
                            Get.toNamed('/subscription');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '🎁',
                                style: TextStyle(fontSize: 20),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Claim Christmas Offer',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFeature(String emoji, String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: TextStyle(fontSize: 16)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
