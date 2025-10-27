import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/assets/icons.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_models.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../friends/friends_screen.dart';
import 'individual_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  final ChatController controller = Get.put(ChatController());
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffE8E8F8),
      appBar: CustomAppBar(
        title: "Messages",
        backgroundColor: Colors.white,
        titleColor: AppColors.appColor,
        showGradient: false,
        titleStyle: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.appColor,
        ),
        actions: [
          // Plus button to navigate to Friends & Social screen
          Container(
            margin: EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.neonYellow,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.black,
                  size: 20,
                ),
              ),
              onPressed: () => Get.to(() => FriendsScreen()),
            ),
          ),
          Obx(() => controller.totalUnreadMessages > 0
              ? Container(
                  margin: EdgeInsets.only(right: 16),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${controller.totalUnreadMessages}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
              : SizedBox.shrink()),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          _buildTabBar(),
          // Tab Bar View
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRecentChatsTab(),
                  _buildFriendsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.appColor,
              AppColors.appColor.withValues(alpha: 0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.appColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        tabs: [
          Tab(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 16),
                  SizedBox(width: 6),
                  Text('Recent'),
                ],
              ),
            ),
          ),
          Tab(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 16),
                  SizedBox(width: 6),
                  Text('Friends'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChatsTab() {
    return RefreshIndicator(
      onRefresh: controller.refreshChats,
      color: AppColors.appColor,
      child: Obx(() {
        if (controller.isLoading.value && controller.chatRooms.isEmpty) {
          return _buildLoadingState();
        }

        if (controller.chatRooms.isEmpty) {
          return _buildEmptyChatsState();
        }

        return ListView.builder(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: controller.chatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = controller.chatRooms[index];
            return _buildChatRoomCard(chatRoom, index);
          },
        );
      }),
    );
  }

  Widget _buildFriendsTab() {
    return RefreshIndicator(
      onRefresh: controller.refreshChats,
      color: AppColors.appColor,
      child: Obx(() {
        if (controller.isLoading.value && controller.friends.isEmpty) {
          return _buildLoadingState();
        }

        if (controller.friends.isEmpty) {
          return _buildEmptyFriendsState();
        }

        return ListView.builder(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: controller.friends.length,
          itemBuilder: (context, index) {
            final friend = controller.friends[index];
            return _buildFriendCard(friend, index);
          },
        );
      }),
    );
  }

  Widget _buildChatRoomCard(ChatRoom chatRoom, int index) {
    final currentUserId = controller.currentUserId!;
    final otherParticipantName = chatRoom.getOtherParticipantName(currentUserId);
    final otherParticipantPicture = chatRoom.getOtherParticipantProfilePicture(currentUserId);
    final unreadCount = chatRoom.getUnreadCount(currentUserId);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: unreadCount > 0
                      ? AppColors.appColor.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.1),
                  width: unreadCount > 0 ? 2 : 1,
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.appColor.withValues(alpha: 0.2),
                            AppColors.appColor.withValues(alpha: 0.1),
                          ],
                        ),
                        image: otherParticipantPicture != null
                            ? DecorationImage(
                                image: NetworkImage(otherParticipantPicture),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: otherParticipantPicture == null
                          ? Icon(
                              Icons.person,
                              color: AppColors.appColor,
                              size: 28,
                            )
                          : null,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  otherParticipantName,
                  style: GoogleFonts.poppins(
                    fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                subtitle: chatRoom.lastMessage != null
                    ? Text(
                        chatRoom.lastMessage!,
                        style: GoogleFonts.poppins(
                          color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                          fontSize: 14,
                          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        'Tap to start chatting',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (chatRoom.lastMessageTimestamp != null)
                      Text(
                        _formatTime(chatRoom.lastMessageTimestamp!),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: unreadCount > 0 ? AppColors.appColor : Colors.grey[500],
                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ],
                ),
                onTap: () => _openChat(chatRoom),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendCard(friend, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.appColor.withValues(alpha: 0.2),
                        AppColors.appColor.withValues(alpha: 0.1),
                      ],
                    ),
                    image: friend.friendProfilePicture != null
                        ? DecorationImage(
                            image: NetworkImage(friend.friendProfilePicture!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: friend.friendProfilePicture == null
                      ? Icon(
                          Icons.person,
                          color: AppColors.appColor,
                          size: 28,
                        )
                      : null,
                ),
                title: Text(
                  friend.friendName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                subtitle: friend.friendUsername != null
                    ? Text(
                        '@${friend.friendUsername}',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      )
                    : Text(
                        'Tap to start chatting',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                trailing: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.appColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.appColor,
                    size: 20,
                  ),
                ),
                onTap: () => _startChatWithFriend(friend),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.appColor),
          SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.appColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.appColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Messages Yet',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Start a conversation with your friends!\nSwitch to the Friends tab to begin chatting.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _tabController.animateTo(1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'View Friends',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFriendsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.appColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              IconPaths.friendsIcon,
              height: 64,
              width: 64,
              colorFilter: ColorFilter.mode(
                AppColors.appColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Friends Yet',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Add friends to start chatting!\nGo to the Friends screen to connect with people.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // Navigate to friends screen - check if route exists
              try {
                Get.toNamed('/friends');
              } catch (e) {
                // Fallback navigation
                Get.offAllNamed('/main');
                // Wait a moment then navigate to friends tab
                Future.delayed(Duration(milliseconds: 500), () {
                  // This would need to be handled by your main navigation controller
                  // For now, show a message to the user
                  Get.snackbar(
                    'Navigation',
                    'Go to Friends tab to add friends',
                    backgroundColor: AppColors.appColor,
                    colorText: Colors.white,
                  );
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Find Friends',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(timestamp);
    } else {
      return DateFormat.MMMd().format(timestamp);
    }
  }

  void _openChat(ChatRoom chatRoom) {
    Get.to(
      () => IndividualChatScreen(),
      arguments: chatRoom,
      transition: Transition.rightToLeftWithFade,
    );
  }

  Future<void> _startChatWithFriend(friend) async {
    final chatRoom = await controller.createOrGetChatRoom(
      friend.friendId,
      friend.friendName,
      friend.friendProfilePicture,
    );

    if (chatRoom != null) {
      _openChat(chatRoom);
    }
  }
}