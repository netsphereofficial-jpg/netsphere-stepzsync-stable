import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/subscription_controller.dart';
import '../../models/subscription_models.dart';

class FreeTrialScreen extends StatefulWidget {
  const FreeTrialScreen({Key? key}) : super(key: key);

  @override
  State<FreeTrialScreen> createState() => _FreeTrialScreenState();
}

class _FreeTrialScreenState extends State<FreeTrialScreen> {
  int _selectedPlanIndex = 1; // Default to yearly
  late final SubscriptionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<SubscriptionController>()
        ? Get.find<SubscriptionController>()
        : Get.put(SubscriptionController());
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
    if (_selectedPlan.billingPeriod == '/year') return 'Start Free Trial';
    if (_selectedPlan.billingPeriod == 'one-time') return 'Buy Lifetime Access';
    return 'Subscribe Now';
  }

  String get _disclaimerText {
    final plan = _selectedPlan;
    final price = _planPrice(plan);
    if (plan.billingPeriod == '/year') {
      return 'After 7-day free trial, $price/year. Cancel anytime.';
    } else if (plan.billingPeriod == '/month') {
      return '$price/month. Cancel anytime from device settings.';
    } else {
      return 'One-time payment of $price. No recurring charges.';
    }
  }

  String _planPrice(SubscriptionPlan plan) {
    return plan.price ?? '--';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Obx(() {
          final plans = _plans;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Get.back(),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(Icons.close, size: 24, color: Colors.grey.shade500),
                    ),
                  ),
                ),
                // App icon + title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/app_icon.png', width: 44, height: 44),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Start Your Free Trial',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Trial badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 15),
                      const SizedBox(width: 5),
                      Text(
                        '7 days free, then auto-renews',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Features - compact list
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _featureRow(Icons.flash_on, 'Unlimited Quick Races'),
                      _featureRow(Icons.emoji_events, 'Create & Join All Race Types'),
                      _featureRow(Icons.leaderboard, 'Full Leaderboard Access'),
                      _featureRow(Icons.chat_bubble_outline, 'Chat & Social Features'),
                      _featureRow(Icons.bar_chart, 'Advanced Statistics'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Marathon card - compact
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_run, color: Color(0xFF7C4DFF), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Marathon Mode',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF4A148C)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('COMING SOON', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF7C4DFF))),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Plan selector - compact
                ...List.generate(plans.length, (index) {
                  final plan = plans[index];
                  final isSelected = _selectedPlanIndex == index;
                  final isYearly = plan.billingPeriod == '/year';
                  final isLifetime = plan.billingPeriod == 'one-time';
                  final price = _planPrice(plan);

                  String label;
                  String priceText;
                  String? badgeText;

                  if (isYearly) {
                    label = 'Yearly';
                    priceText = '$price/year';
                    badgeText = 'FREE TRIAL';
                  } else if (isLifetime) {
                    label = 'Lifetime';
                    priceText = '$price one-time';
                    badgeText = 'BEST VALUE';
                  } else {
                    label = 'Monthly';
                    priceText = '$price/month';
                    badgeText = null;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlanIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2196F3)),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                            const SizedBox(width: 6),
                            Text(priceText, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                            const Spacer(),
                            if (badgeText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isYearly
                                      ? const Color(0xFF2196F3).withValues(alpha: 0.1)
                                      : const Color(0xFFFF9800).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isYearly ? const Color(0xFF2196F3) : const Color(0xFFFF9800),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                // CTA button
                Obx(() {
                  final purchasing = _controller.isPurchasing.value;
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: purchasing ? null : () => _controller.purchaseSubscription(_selectedPlan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: purchasing
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(_ctaText, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                // Disclaimer
                Text(
                  _disclaimerText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, height: 1.3),
                ),
                if (Platform.isIOS) ...[
                  const SizedBox(height: 4),
                  Obx(() {
                    final restoring = _controller.isRestoring.value;
                    return GestureDetector(
                      onTap: restoring ? null : _controller.restorePurchases,
                      child: restoring
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                          : Text(
                              'Restore Purchases',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2196F3),
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF2196F3),
                              ),
                            ),
                    );
                  }),
                ],
                const SizedBox(height: 10),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 10),
          Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
        ],
      ),
    );
  }
}
