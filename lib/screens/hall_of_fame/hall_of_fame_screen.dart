import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/text_styles.dart';

class HallOfFameScreen extends StatelessWidget {
  const HallOfFameScreen({super.key});

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
          'Hall of Fame',
          style: AppTextStyles.heroHeading,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.amber.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Legends Vault Icon
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
                'Hall of Fame',
                style: AppTextStyles.heroHeading.copyWith(
                  fontSize: 32,
                  color: const Color(0xFF35B555),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'Explore the hall of fame featuring top performers, record holders, and legendary achievements in the running community!',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Features List
              _buildFeatureCard('👑', 'Hall of Champions', 'Top performing athletes'),
              const SizedBox(height: 16),
              _buildFeatureCard('📊', 'Record Breakers', 'Speed and distance records'),
              const SizedBox(height: 16),
              _buildFeatureCard('🌟', 'Achievement Gallery', 'Legendary accomplishments'),
              const SizedBox(height: 40),
              
              // Leaderboard Categories
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryButton('Top Runners', Icons.directions_run),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCategoryButton('Speed Kings', Icons.speed),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryButton('Distance Masters', Icons.straighten),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCategoryButton('Weekly Heroes', Icons.calendar_month),
                  ),
                ],
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

  Widget _buildCategoryButton(String title, IconData icon) {
    return ElevatedButton(
      onPressed: () {
        Get.snackbar(
          'Coming Soon!',
          '$title category is under development',
          backgroundColor: const Color(0xFF35B555),
          colorText: Colors.white,
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF35B555),
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF35B555)),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTextStyles.buttonText.copyWith(
              color: const Color(0xFF35B555),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}