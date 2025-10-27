import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/assets/icons.dart';
import '../../controllers/friends_controller.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_text_field.dart';
import 'friends_list_tab.dart';
import 'friend_requests_tab.dart';
import 'user_search_tab.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FriendsController());

    return Scaffold(
      backgroundColor: Color(0xffE8E8F8),
      appBar: CustomAppBar(
        title: "Friends & Social",
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
        onBackClick: () => Get.back(),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            child: RoundedTextField(
              controller: controller.searchController,
              hintText: 'Search by name or username...',
              suffixIcon: Obx(() {
                if (controller.isSearching.value) {
                  return IconButton(
                    onPressed: controller.clearSearch,
                    icon: const Icon(Icons.clear, color: Colors.grey),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: SvgPicture.asset(
                      IconPaths.searchicon,
                      height: 20,
                      width: 20,
                      colorFilter: ColorFilter.mode(
                        Colors.grey[600]!,
                        BlendMode.srcIn,
                      ),
                    ),
                  );
                }
              }),
            ),
          ),

          // Tab Bar or Search Results
          Expanded(
            child: Obx(() {
              if (controller.isSearching.value) {
                return UserSearchTab();
              } else {
                return _buildTabView(controller);
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTabView(FriendsController controller) {
    return Column(
      children: [
        // Tab Headers
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Obx(() => Row(
            children: [
              _buildTab(
                'Friends',
                controller.friendsCount,
                0,
                controller.selectedTabIndex.value,
                controller.changeTab,
              ),
              _buildTab(
                'Received',
                controller.receivedRequestsCount,
                1,
                controller.selectedTabIndex.value,
                controller.changeTab,
              ),
              _buildTab(
                'Sent',
                controller.sentRequestsCount,
                2,
                controller.selectedTabIndex.value,
                controller.changeTab,
              ),
            ],
          )),
        ),

        const SizedBox(height: 16),

        // Tab Content
        Expanded(
          child: PageView(
            controller: controller.pageController,
            onPageChanged: controller.onPageChanged,
            children: [
              FriendsListTab(),
              FriendRequestsTab(isReceived: true),
              FriendRequestsTab(isReceived: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(
    String title,
    int count,
    int index,
    int selectedIndex,
    Function(int) onTap,
  ) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.appColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : AppColors.appColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.appColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}