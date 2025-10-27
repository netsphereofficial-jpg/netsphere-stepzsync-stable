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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.appColor.withOpacity(0.1),
              Colors.white,
              AppColors.appColor.withOpacity(0.05),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(
            title: "Upgrade Plan",
            isBack: true,
            onBackClick: () => Get.back(),
            actions: [
              if (Platform.isIOS)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Obx(() => IconButton(
                    onPressed: controller.isRestoring.value
                        ? null
                        : controller.restorePurchases,
                    icon: controller.isRestoring.value
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.appColor,
                            ),
                          )
                        : Icon(
                            Icons.restore,
                            color: AppColors.appColor,
                          ),
                  )),
                ),
            ],
          ),
          body: Obx(() {
            if (controller.isInitializing.value) {
              return _buildLoadingState();
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 16),
                    _buildCurrentPlanCard(),
                    const SizedBox(height: 16),
                    _buildCompactPlanCards(),
                    const SizedBox(height: 12),
                    _buildFeatureHighlights(),
                    const SizedBox(height: 12),
                    _buildFeaturesComparison(),
                    const SizedBox(height: 12),
                    _buildBottomInfo(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.appColor),
          const SizedBox(height: 16),
          Text(
            'Loading plans...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.greyColor2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.appColor,
            AppColors.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.appColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.rocket_launch_rounded,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock Premium Features',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Join thousands of runners worldwide',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms)
      .slideY(begin: -0.3, end: 0, duration: 600.ms);
  }

  Widget _buildCurrentPlanCard() {
    return Obx(() {
      final currentSub = controller.currentSubscription.value;
      final planName = controller.currentPlanDisplayName;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: currentSub.isPremium ? AppColors.neonGreen : AppColors.appColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (currentSub.isPremium ? AppColors.neonGreen : AppColors.appColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                currentSub.isPremium ? Icons.star : Icons.person_outline,
                color: currentSub.isPremium ? AppColors.neonGreen : AppColors.appColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Plan',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.greyColor2,
                    ),
                  ),
                  Text(
                    planName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (currentSub.isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      );
    }).animate()
      .fadeIn(duration: 400.ms, delay: 200.ms)
      .slideX(begin: 0.3, end: 0, duration: 400.ms, delay: 200.ms);
  }

  Widget _buildCompactPlanCards() {
    final plans = SubscriptionPlan.getAllPlans();

    return Column(
      children: plans.map((plan) {
        final delay = plan.type.index * 100;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: _buildCompactPlanCard(plan),
        ).animate()
          .fadeIn(duration: 500.ms, delay: Duration(milliseconds: 300 + delay))
          .slideX(begin: 0.4, end: 0, duration: 500.ms, delay: Duration(milliseconds: 300 + delay));
      }).toList(),
    );
  }

  Widget _buildCompactPlanCard(SubscriptionPlan plan) {
    final isCurrentPlan = controller.isPlanActive(plan.type);
    final isFree = plan.type == SubscriptionPlanType.free;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isPopular
              ? AppColors.neonGreen
              : (isCurrentPlan ? AppColors.appColor : Colors.grey.withOpacity(0.2)),
          width: plan.isPopular || isCurrentPlan ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Plan Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                plan.subtitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.greyColor2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      if (!isFree) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (plan.originalPrice != null) ...[
                              Text(
                                plan.originalPrice!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.greyColor2,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              plan.price ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            if (plan.billingPeriod != null)
                              Text(
                                plan.billingPeriod!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.greyColor2,
                                ),
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 6),
                      // Key Features (max 3)
                      ...plan.features.take(3).map((feature) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            Icon(
                              feature.isAvailable ? Icons.check_circle : Icons.cancel,
                              color: feature.isAvailable ? AppColors.greenColor : Colors.red,
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                feature.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: feature.isAvailable ? AppColors.primary : AppColors.greyColor2,
                                  decoration: feature.isAvailable ? null : TextDecoration.lineThrough,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),

                      if (plan.features.length > 3)
                        Text(
                          '+${plan.features.length - 3} more',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: AppColors.appColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),

                // Action Button
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: _buildCompactButton(plan),
                ),
              ],
            ),
          ),

          // Popular Badge
          if (plan.isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.neonGreen, AppColors.electricBlue],
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'POPULAR',
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactButton(SubscriptionPlan plan) {
    final isCurrentPlan = controller.isPlanActive(plan.type);
    final isPurchasing = controller.isPurchasing.value &&
                        controller.selectedPlan.value?.type == plan.type;

    if (isCurrentPlan) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.appColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.appColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.check, color: AppColors.appColor, size: 16),
            const SizedBox(height: 2),
            Text(
              'Current',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.appColor,
              ),
            ),
          ],
        ),
      );
    }

    if (plan.type == SubscriptionPlanType.free) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.greyColor2.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(Icons.arrow_downward, color: AppColors.greyColor2, size: 16),
            const SizedBox(height: 2),
            Text(
              'Downgrade',
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: AppColors.greyColor2,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: isPurchasing ? null : () => controller.purchaseSubscription(plan),
      style: ElevatedButton.styleFrom(
        backgroundColor: plan.isPopular ? AppColors.neonGreen : AppColors.appColor,
        foregroundColor: plan.isPopular ? AppColors.primary : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: isPurchasing
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Platform.isIOS ? Icons.apple : Icons.android,
                  size: 14,
                ),
                const SizedBox(height: 2),
                Text(
                  'Upgrade',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFeatureHighlights() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.neonGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Premium Benefits',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildBenefitItem(Icons.public, 'Global Races', 'Premium 2')),
              Expanded(child: _buildBenefitItem(Icons.leaderboard, 'Leaderboards', 'Premium 1')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildBenefitItem(Icons.analytics, 'Advanced Stats', 'Premium 1')),
              Expanded(child: _buildBenefitItem(Icons.emoji_events, 'Hall of Fame', 'Premium 2')),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 800.ms)
      .slideY(begin: 0.2, end: 0, duration: 600.ms, delay: 800.ms);
  }

  Widget _buildBenefitItem(IconData icon, String title, String requiredPlan) {
    return Column(
      children: [
        Icon(icon, color: AppColors.appColor, size: 24),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          requiredPlan,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.greyColor2,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesComparison() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, color: AppColors.appColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Feature Comparison',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildComparisonTable(),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 900.ms)
      .slideY(begin: 0.2, end: 0, duration: 600.ms, delay: 900.ms);
  }

  Widget _buildComparisonTable() {
    final features = [
      'Race Access',
      'Join Races',
      'Create Races',
      'Marathons',
      'Statistics',
      'Heart Rate Zones',
      'Leaderboards',
      'Hall of Fame',
      'Group Chat',
      'Global Features',
    ];

    final plans = SubscriptionPlan.getAllPlans();

    return Column(
      children: [
        // Header row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                'Feature',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            ...plans.map((plan) => Expanded(
              child: Column(
                children: [
                  Text(
                    plan.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    plan.name,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: Colors.grey.withOpacity(0.2),
        ),
        const SizedBox(height: 8),

        // Feature rows
        ...features.map((feature) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  feature,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.greyColor2,
                  ),
                ),
              ),
              ...plans.map((plan) {
                final hasFeature = _planHasFeature(plan, feature);
                return Expanded(
                  child: Center(
                    child: Icon(
                      hasFeature ? Icons.check_circle : Icons.cancel,
                      color: hasFeature ? AppColors.greenColor : Colors.red,
                      size: 18,
                    ),
                  ),
                );
              }),
            ],
          ),
        )),
      ],
    );
  }

  bool _planHasFeature(SubscriptionPlan plan, String feature) {
    // Simplified feature mapping - in real app, this would be more sophisticated
    switch (feature) {
      case 'Race Access':
        return true;
      case 'Join Races':
        return true;
      case 'Create Races':
        return true;
      case 'Marathons':
        return plan.type != SubscriptionPlanType.free;
      case 'Statistics':
        return true;
      case 'Heart Rate Zones':
        return plan.type != SubscriptionPlanType.free;
      case 'Leaderboards':
        return plan.type != SubscriptionPlanType.free;
      case 'Hall of Fame':
        return plan.type == SubscriptionPlanType.premium2;
      case 'Group Chat':
        return plan.type == SubscriptionPlanType.premium2;
      case 'Global Features':
        return plan.type == SubscriptionPlanType.premium2;
      default:
        return false;
    }
  }

  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Platform.isIOS ? Icons.apple : Icons.android,
                color: AppColors.appColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Secure ${Platform.isIOS ? 'App Store' : 'Google Play'} Purchase',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cancel anytime in your device settings',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppColors.greyColor2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: 1000.ms);
  }
}