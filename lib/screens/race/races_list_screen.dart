import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stepzsync/controllers/race/races_list_controller.dart';
import 'package:stepzsync/screens/races/create_race/create_race_screen.dart';
import 'package:stepzsync/widgets/race/race_card_widget.dart';

import '../../config/app_colors.dart';
import '../../config/assets/icons.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../utils/guest_utils.dart';
import '../../widgets/guest_upgrade_dialog.dart';

class RacesListScreen extends StatefulWidget {
  const RacesListScreen({super.key});

  @override
  State<RacesListScreen> createState() => _RacesListScreenState();
}

class _RacesListScreenState extends State<RacesListScreen>
    with TickerProviderStateMixin {
  final RacesListController controller = Get.put(RacesListController());
  late AnimationController _cardAnimationController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    // Start animations with delays
    Future.delayed(Duration(milliseconds: 400), () {
      _cardAnimationController.forward();
    });

    // Note: Real-time updates are now handled by Firebase streams in the controller
    // No need for periodic refresh timer

    // Start monitoring participant changes for user's joined races
    Future.delayed(Duration(milliseconds: 1000), () {
      controller.startMonitoringUserRaces();
    });
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    // Stop monitoring participant changes when screen is disposed
    controller.stopMonitoringAllRaces();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffE8E8F8),
      appBar: CustomAppBar(
        title: "All Races",
        isBack: true,
        circularBackButton: true,
        backButtonCircleColor: AppColors.neonYellow,
        backButtonIconColor: Colors.black,
        backgroundColor: Colors.white,
        titleColor: AppColors.appColor,
        showGradient: false,
        titleStyle: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.appColor,
        ),
      ),
      body: Container(
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: controller.refreshRaces,
                color: AppColors.neonYellow,
                child: Obx(() {
                  if (controller.isLoading.value && controller.races.isEmpty) {
                    return _buildLoadingState();
                  }

                  if (controller.filteredRaces.isEmpty &&
                      !controller.isLoading.value) {
                    return _buildEmptyState();
                  }

                  return Column(
                    children: [
                      // Search Bar
                      _buildSearchBar(),

                      // Animated Filter Bar
                      _buildAnimatedFilterBar(),

                      // Races list
                      Expanded(
                        child: ListView.builder(
                          physics: BouncingScrollPhysics(),
                          padding: EdgeInsets.only(
                            bottom: AppConstants.defaultPadding,
                          ),
                          itemCount: controller.filteredRaces.length,
                          itemBuilder: (context, index) {
                            final race = controller.filteredRaces[index];
                            return _buildAnimatedRaceCard(race, index);
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        // Animated Filter Bar (always visible)
        _buildAnimatedFilterBar(),

        // Loading shimmer cards
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
            ),
            itemBuilder: (context, index) => _buildShimmerCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Spacer(),
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Spacer(),
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        // Animated Filter Bar (always visible)
        _buildAnimatedFilterBar(),

        // Empty state content
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.neonYellow.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flag_outlined,
                    size: 50,
                    color: AppColors.buttonBlack,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  controller.races.isEmpty
                      ? 'No Races Available'
                      : 'No Races Match Your Filters',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    controller.races.isEmpty
                        ? 'Be the first to create a race and challenge others!'
                        : 'Try adjusting your filters or create a new race.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (controller.races.isNotEmpty) ...[
                      ElevatedButton(
                        onPressed: () {
                          controller.clearFilters();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.grey[700],
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'Clear Filters',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                    ],
                    ElevatedButton(
                      onPressed: () => Get.to(() => CreateRaceScreen()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonYellow,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        controller.races.isEmpty
                            ? 'Create First Race'
                            : 'Create New Race',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600,
                          color: AppColors.buttonBlack,

                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedFilterBar() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: 8,
      ),
      height: 60,
      child: Row(
        children: [
          // Filter label
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
             color: Color(0xff2759FF
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  IconPaths.filterIcon,
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                SizedBox(width: 6),
                Text(
                  'Filter',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 12),

          // Filter chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              child: Obx(() => Row(children: [..._buildFilterChips()])),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Color(0xff2759FF), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: 'Search races by title, creator, or location...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
          Obx(() => controller.searchQuery.value.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey, size: 20),
                  onPressed: controller.clearSearch,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                )
              : SizedBox.shrink()),
        ],
      ),
    );
  }

  List<Widget> _buildFilterChips() {
    return [
      _buildRaceTypeFilters(),
      SizedBox(width: 8),
      _buildDistanceFilters(),
      SizedBox(width: 8),
      _buildGenderFilters(),
    ];
  }

  Widget _buildRaceTypeFilters() {
    final filterOptions = [
      {'label': 'All', 'icon': Icons.dashboard, 'color': Color(0xFF6B7280)},
      {'label': 'Public', 'icon': Icons.public, 'color': Color(0xFF059669)},
      {'label': 'Private', 'icon': Icons.lock, 'color': Color(0xFFEA580C)},
      {'label': 'Solo', 'icon': Icons.person, 'color': Color(0xFF0EA5E9)},
      {'label': 'Quick', 'icon': Icons.flash_on, 'color': Color(0xFFF59E0B)},
      {
        'label': 'Marathon',
        'icon': Icons.directions_run,
        'color': Color(0xFF7C3AED),
      },
    ];

    return Row(
      children: filterOptions.map((filter) {
        return _buildFilterChip(
          filter: filter,
          isSelected: controller.selectedRaceType.value == filter['label'],
          count: _getRaceTypeCount(filter['label'] as String),
          onTap: () {
            controller.selectedRaceType.value = filter['label'] as String;
            _animateFilterChange();
          },
        );
      }).toList(),
    );
  }

  Widget _buildDistanceFilters() {
    final filterOptions = [
      {
        'label': 'Short',
        'icon': Icons.directions_walk,
        'color': Color(0xFF10B981),
      },
      {
        'label': 'Medium',
        'icon': Icons.directions_run,
        'color': Color(0xFFF59E0B),
      },
      {'label': 'Long', 'icon': Icons.terrain, 'color': Color(0xFFEF4444)},
    ];

    return Row(
      children: filterOptions.map((filter) {
        return _buildFilterChip(
          filter: filter,
          isSelected: controller.selectedDistance.value == filter['label'],
          count: _getDistanceCount(filter['label'] as String),
          onTap: () {
            controller.selectedDistance.value = filter['label'] as String;
            _animateFilterChange();
          },
        );
      }).toList(),
    );
  }

  Widget _buildGenderFilters() {
    final filterOptions = [
      {'label': 'Male', 'icon': Icons.male, 'color': Color(0xFF3B82F6)},
      {'label': 'Female', 'icon': Icons.female, 'color': Color(0xFFEC4899)},
      {'label': 'Any', 'icon': Icons.group, 'color': Color(0xFF8B5CF6)},
    ];

    return Row(
      children: filterOptions.map((filter) {
        return _buildFilterChip(
          filter: filter,
          isSelected: controller.selectedGender.value == filter['label'],
          count: _getGenderCount(filter['label'] as String),
          onTap: () {
            controller.selectedGender.value = filter['label'] as String;
            _animateFilterChange();
          },
        );
      }).toList(),
    );
  }

  Widget _buildFilterChip({
    required Map<String, dynamic> filter,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (filter['color'] as Color).withValues(alpha: 0.1)
                  : Colors.white,
              border: Border.all(
                color: isSelected
                    ? (filter['color'] as Color)
                    : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (filter['color'] as Color).withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  filter['icon'] as IconData,
                  size: 16,
                  color: isSelected
                      ? (filter['color'] as Color)
                      : Colors.grey[600],
                ),
                SizedBox(width: 6),
                Text(
                  '${filter['label']} ($count)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (filter['color'] as Color)
                        : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _animateFilterChange() {
    _cardAnimationController.reset();
    _cardAnimationController.forward();
  }

  int _getRaceTypeCount(String type) {
    switch (type) {
      case 'All':
        return controller.allCount.value;
      case 'Public':
        return controller.publicCount.value;
      case 'Private':
        return controller.privateCount.value;
      case 'Marathon':
        return controller.marathonCount.value;
      case 'Solo':
        return controller.soloCount.value;
      case 'Quick':
        return controller.quickCount.value;
      default:
        return 0;
    }
  }

  int _getDistanceCount(String distance) {
    switch (distance) {
      case 'Short':
        return controller.shortDistanceCount.value;
      case 'Medium':
        return controller.mediumDistanceCount.value;
      case 'Long':
        return controller.longDistanceCount.value;
      default:
        return 0;
    }
  }

  int _getGenderCount(String gender) {
    switch (gender) {
      case 'Male':
        return controller.maleCount.value;
      case 'Female':
        return controller.femaleCount.value;
      case 'Any':
        return controller.anyGenderCount.value;
      default:
        return 0;
    }
  }

  Widget _buildAnimatedRaceCard(race, int index) {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        // Limit the animation delay to prevent cards from disappearing
        final animationDelay = (index * 0.05).clamp(
          0.0,
          0.8,
        ); // Reduced delay and capped at 0.8
        final totalAnimationValue = _cardAnimationController.value;

        // Calculate the progress for this specific card
        double rawAnimationValue;
        if (totalAnimationValue <= animationDelay) {
          rawAnimationValue = 0.0;
        } else {
          // Normalize the animation value for this card
          rawAnimationValue =
              ((totalAnimationValue - animationDelay) / (1.0 - animationDelay))
                  .clamp(0.0, 1.0);
        }

        final animationValue = Curves.easeOutBack
            .transform(rawAnimationValue)
            .clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, 30 * (1 - animationValue)),
          // Reduced translation distance
          child: Opacity(
            opacity: animationValue.clamp(0.3, 1.0),
            // Minimum opacity of 0.3 to ensure cards are always visible
            child: Transform.scale(
              scale: (0.95 + (0.05 * animationValue)).clamp(0.95, 1.0),
              // Ensure scale is always valid
              child: RaceCardWidget(race: race),
            ),
          ),
        );
      },
    );
  }
}
