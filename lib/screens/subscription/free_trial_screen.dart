import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/subscription_controller.dart';
import '../../models/subscription_models.dart';

class FreeTrialScreen extends StatefulWidget {
  const FreeTrialScreen({Key? key}) : super(key: key);

  @override
  State<FreeTrialScreen> createState() => _FreeTrialScreenState();
}

class _FreeTrialScreenState extends State<FreeTrialScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPlanIndex = 1; // Default to yearly (free trial)
  late final SubscriptionController _controller;
  late final AnimationController _shimmerController;

  // Colors
  static const _bg = Color(0xFF0B0F1E);
  static const _cardBg = Color(0xFF141929);
  static const _accent = Color(0xFF6C5CE7);
  static const _accentLight = Color(0xFF8B7CF6);
  static const _green = Color(0xFF00D68F);
  static const _gold = Color(0xFFFFD93D);
  static const _cardBorder = Color(0xFF1E2440);

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<SubscriptionController>()
        ? Get.find<SubscriptionController>()
        : Get.put(SubscriptionController());
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  List<SubscriptionPlan> get _plans {
    final storePlans = _controller.availablePlans
        .where((p) => p.type != SubscriptionPlanType.free)
        .toList();
    if (storePlans.isNotEmpty) return storePlans;
    return SubscriptionPlan.getAllPlans()
        .where((p) => p.type != SubscriptionPlanType.free)
        .toList();
  }

  SubscriptionPlan get _selectedPlan {
    final plans = _plans;
    if (_selectedPlanIndex >= plans.length) return plans.last;
    return plans[_selectedPlanIndex];
  }

  String get _ctaText {
    if (_selectedPlan.billingPeriod == '/year') return 'Start 7-Day Free Trial';
    if (_selectedPlan.billingPeriod == 'one-time') return 'Get Lifetime Access';
    return 'Subscribe Now';
  }

  String get _disclaimerText {
    final plan = _selectedPlan;
    final price = plan.price ?? '--';
    if (plan.billingPeriod == '/year') {
      return '7 days free, then $price/year. Cancel anytime.';
    } else if (plan.billingPeriod == '/month') {
      return '$price billed monthly. Cancel anytime.';
    } else {
      return 'One-time payment of $price. No subscription.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Obx(() {
            final plans = _plans;
            return Column(
              children: [
                // Top bar with close
                _buildTopBar(),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        _buildHeroSection(),
                        const SizedBox(height: 20),
                        _buildFeaturesList(),
                        const SizedBox(height: 20),
                        _buildPlanSelector(plans),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Sticky bottom CTA
                _buildBottomCTA(),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white54),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        // Glowing app icon
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_accent, Color(0xFF0984E3)],
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Image.asset('assets/app_icon.png', width: 64, height: 64),
          ),
        ).animate()
          .fadeIn(duration: 500.ms)
          .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        // Title
        Text(
          'Unlock Premium',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 100.ms),
        const SizedBox(height: 6),
        Text(
          'Race harder. Track smarter. Win more.',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        const SizedBox(height: 14),
        // Free trial badge
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + 2 * _shimmerController.value, 0),
                  end: Alignment(1 + 2 * _shimmerController.value, 0),
                  colors: [
                    _green.withValues(alpha: 0.15),
                    _green.withValues(alpha: 0.3),
                    _green.withValues(alpha: 0.15),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: _green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '7 DAYS FREE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _green,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'then auto-renews',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _green.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          },
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms).scale(begin: const Offset(0.9, 0.9), duration: 400.ms, delay: 300.ms),
      ],
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      _FeatureItem(Icons.flash_on_rounded, 'Unlimited Quick Races', 'No cooldown limits'),
      _FeatureItem(Icons.emoji_events_rounded, 'Create & Join Races', 'Up to 7 active races'),
      _FeatureItem(Icons.leaderboard_rounded, 'Leaderboards', 'Country-level rankings'),
      _FeatureItem(Icons.insights_rounded, 'Advanced Statistics', 'Heart-rate zones, filters & more'),
      _FeatureItem(Icons.directions_run_rounded, 'Marathon Mode', 'Coming soon'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'WHAT YOU GET',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _accentLight,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(height: 1, color: _cardBorder),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...features.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            final isLast = f.subtitle == 'Coming soon';
            return Padding(
              padding: EdgeInsets.only(bottom: i < features.length - 1 ? 12 : 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isLast
                          ? _gold.withValues(alpha: 0.12)
                          : _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      f.icon,
                      size: 18,
                      color: isLast ? _gold : _accentLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        Text(
                          f.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isLast ? _gold.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SOON',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _gold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.check_circle_rounded, size: 18, color: _green.withValues(alpha: 0.8)),
                ],
              ),
            ).animate()
              .fadeIn(duration: 300.ms, delay: Duration(milliseconds: 350 + i * 60))
              .slideX(begin: 0.05, end: 0, duration: 300.ms, delay: Duration(milliseconds: 350 + i * 60));
          }),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildPlanSelector(List<SubscriptionPlan> plans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'CHOOSE YOUR PLAN',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...List.generate(plans.length, (index) {
          final plan = plans[index];
          final isSelected = _selectedPlanIndex == index;
          final isYearly = plan.billingPeriod == '/year';
          final isLifetime = plan.billingPeriod == 'one-time';
          final price = plan.price ?? '--';

          String label;
          String priceText;
          String? tagText;
          Color tagColor;

          if (isYearly) {
            label = 'Yearly';
            priceText = '$price/year';
            tagText = '7-DAY FREE TRIAL';
            tagColor = _green;
          } else if (isLifetime) {
            label = 'Lifetime';
            priceText = price;
            tagText = 'BEST VALUE';
            tagColor = _gold;
          } else {
            label = 'Monthly';
            priceText = '$price/mo';
            tagText = null;
            tagColor = Colors.white;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPlanIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? _accent.withValues(alpha: 0.08) : _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? _accent : _cardBorder,
                    width: isSelected ? 1.8 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: _accent.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 0)]
                      : [],
                ),
                child: Row(
                  children: [
                    // Radio
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _accent : Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                        color: isSelected ? _accent : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    // Label & price
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            priceText,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tag
                    if (tagText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tagColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          tagText,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: tagColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ).animate()
            .fadeIn(duration: 300.ms, delay: Duration(milliseconds: 500 + index * 80))
            .slideY(begin: 0.08, end: 0, duration: 300.ms, delay: Duration(milliseconds: 500 + index * 80));
        }),
      ],
    );
  }

  Widget _buildBottomCTA() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CTA button
            Obx(() {
              final purchasing = _controller.isPurchasing.value;
              final isYearly = _selectedPlan.billingPeriod == '/year';

              return SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_accent, Color(0xFF0984E3)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: purchasing ? null : () {
                      HapticFeedback.mediumImpact();
                      _controller.purchaseSubscription(_selectedPlan);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: purchasing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isYearly) ...[
                                const Icon(Icons.lock_open_rounded, size: 18),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                _ctaText,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            // Disclaimer
            Text(
              _disclaimerText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.3),
                height: 1.4,
              ),
            ),
            // Restore purchases (iOS)
            if (Platform.isIOS) ...[
              const SizedBox(height: 6),
              Obx(() {
                final restoring = _controller.isRestoring.value;
                return GestureDetector(
                  onTap: restoring ? null : _controller.restorePurchases,
                  child: restoring
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                        )
                      : Text(
                          'Restore Purchases',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureItem(this.icon, this.title, this.subtitle);
}
