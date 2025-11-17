import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../controllers/subscription_controller.dart';
import '../../models/subscription_models.dart';
import '../../widgets/common/custom_app_bar.dart';

class SubscriptionScreen extends StatelessWidget {
  final SubscriptionController controller = Get.put(SubscriptionController());

  SubscriptionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0E27),
      appBar: CustomAppBar(
        title: "Choose Plan",
        isBack: true,
        circularBackButton: true,
        backButtonCircleColor: Colors.white.withOpacity(0.1),
        backButtonIconColor: Colors.white,
        backgroundColor: Color(0xFF0A0E27),
        titleColor: Colors.white,
        showGradient: false,
        titleStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        actions: [
          if (Platform.isIOS)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Obx(() => TextButton(
                onPressed: controller.isRestoring.value
                    ? null
                    : controller.restorePurchases,
                child: controller.isRestoring.value
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : Text(
                        'Restore',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
              )),
            ),
        ],
      ),
      body: Obx(() {
        if (controller.isInitializing.value) {
          return Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6C5CE7),
              strokeWidth: 2.5,
            ),
          );
        }

        return SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildCurrentPlan(),
                const SizedBox(height: 28),
                _buildCompactPlans(),
                const SizedBox(height: 20),
                _buildFooter(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Upgrade to Premium',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock unlimited races and exclusive features',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate()
      .fadeIn(duration: 400.ms)
      .slideY(begin: -0.1, end: 0, duration: 400.ms);
  }

  Widget _buildCurrentPlan() {
    return Obx(() {
      final currentSub = controller.currentSubscription.value;
      final planName = controller.currentPlanDisplayName;
      final isPremium = currentSub.isPremium;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPremium
                ? [Color(0xFF6C5CE7).withOpacity(0.2), Color(0xFF0984E3).withOpacity(0.15)]
                : [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPremium
                ? Color(0xFF6C5CE7).withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPremium ? Icons.verified : Icons.person_outline,
              color: isPremium ? Color(0xFF6C5CE7) : Colors.white60,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              'Current: $planName',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      );
    }).animate()
      .fadeIn(duration: 300.ms, delay: 150.ms)
      .scale(begin: const Offset(0.95, 0.95), duration: 300.ms, delay: 150.ms);
  }

  Widget _buildCompactPlans() {
    final plans = SubscriptionPlan.getAllPlans()
        .where((plan) => plan.type != SubscriptionPlanType.free)
        .toList();

    return Column(
      children: plans.asMap().entries.map((entry) {
        final index = entry.key;
        final plan = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: index < plans.length - 1 ? 14 : 0),
          child: _buildPlanCard(plan, index),
        ).animate()
          .fadeIn(duration: 400.ms, delay: Duration(milliseconds: 250 + (index * 80)))
          .slideX(begin: 0.1, end: 0, duration: 400.ms, delay: Duration(milliseconds: 250 + (index * 80)));
      }).toList(),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, int index) {
    final isCurrentPlan = controller.isPlanActive(plan.type);
    final isPurchasing = controller.isPurchasing.value &&
                        controller.selectedPlan.value?.type == plan.type;
    final isPopular = plan.isPopular;

    return Container(
      decoration: BoxDecoration(
        gradient: isPopular
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6C5CE7),
                  Color(0xFF0984E3),
                ],
              )
            : null,
        color: isPopular ? null : Color(0xFF151B3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPopular
              ? Colors.transparent
              : (isCurrentPlan ? Color(0xFF6C5CE7).withOpacity(0.5) : Colors.white.withOpacity(0.08)),
          width: isCurrentPlan ? 2 : 1.5,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: Color(0xFF6C5CE7).withOpacity(0.4),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                plan.name,
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (isPopular) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'BEST',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (plan.originalPrice != null)
                          Text(
                            plan.originalPrice!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.4),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              plan.price ?? '\$0',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                                letterSpacing: -1,
                              ),
                            ),
                            if (plan.billingPeriod != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4, left: 2),
                                child: Text(
                                  plan.billingPeriod!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...plan.features.take(4).map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        feature.isAvailable ? Icons.check_circle : Icons.cancel,
                        color: feature.isAvailable
                            ? (isPopular ? Colors.white.withOpacity(0.9) : Color(0xFF00D4AA))
                            : Colors.white.withOpacity(0.3),
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feature.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: feature.isAvailable
                                ? Colors.white.withOpacity(0.85)
                                : Colors.white.withOpacity(0.3),
                            decoration: feature.isAvailable
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                _buildActionButton(plan, isCurrentPlan, isPurchasing, isPopular),
              ],
            ),
          ),
          if (plan.originalPrice != null && plan.price != null)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPopular
                      ? Colors.white.withOpacity(0.25)
                      : Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_calculateSavings(plan.originalPrice!, plan.price!)} OFF',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    SubscriptionPlan plan,
    bool isCurrentPlan,
    bool isPurchasing,
    bool isPopular,
  ) {
    if (isCurrentPlan) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Active Plan',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: isPurchasing ? null : () => controller.purchaseSubscription(plan),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPopular ? Colors.white : Color(0xFF6C5CE7),
        foregroundColor: isPopular ? Color(0xFF0A0E27) : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 0),
      ),
      child: isPurchasing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isPopular ? Color(0xFF0A0E27) : Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Platform.isIOS ? Icons.apple : Icons.android,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Subscribe Now',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
    );
  }

  String _calculateSavings(String originalPrice, String price) {
    final original = double.tryParse(originalPrice.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final current = double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    if (original > 0 && current > 0) {
      final savings = ((original - current) / original * 100).round();
      return '$savings%';
    }
    return '0%';
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_rounded,
              color: Colors.white.withOpacity(0.4),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'Secure payment via ${Platform.isIOS ? 'App Store' : 'Google Play'}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Cancel anytime • No hidden fees',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.35),
          ),
        ),
      ],
    ).animate()
      .fadeIn(duration: 400.ms, delay: 550.ms);
  }
}
