import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/text_styles.dart';

class MarathonScreen extends StatelessWidget {
  const MarathonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Marathon',
          style: AppTextStyles.heroHeading,
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Marathon Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF35B555),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF35B555).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 30),
              
              // Title
              Text(
                'Marathon',
                style: AppTextStyles.heroHeading.copyWith(
                  fontSize: 32,
                  color: const Color(0xFF35B555),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'Take on long-distance endurance challenges. Test your limits with epic marathon events and achieve legendary status!',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Features List
              _buildFeatureCard('🏃‍♀️', 'Endurance Tests', 'Long-distance challenges'),
              const SizedBox(height: 16),
              _buildFeatureCard('🎖️', 'Achievement Badges', 'Earn marathon medals'),
              const SizedBox(height: 16),
              _buildFeatureCard('📈', 'Progress Tracking', 'Monitor your stamina gains'),
              const SizedBox(height: 40),
              
              // Action Button
              ElevatedButton(
                onPressed: () {
                  Get.toNamed('/marathon-races');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF35B555),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Browse Marathon Races',
                  style: AppTextStyles.buttonText.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(String emoji, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.sectionHeading.copyWith(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}