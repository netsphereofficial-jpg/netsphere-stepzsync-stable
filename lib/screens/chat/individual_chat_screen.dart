import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_models.dart';

class IndividualChatScreen extends StatefulWidget {
  const IndividualChatScreen({super.key});

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen>
    with TickerProviderStateMixin {
  final ChatController controller = Get.find<ChatController>();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  late ChatRoom chatRoom;
  late String otherParticipantName;
  late String? otherParticipantPicture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  ChatMessage? replyToMessage;

  @override
  void initState() {
    super.initState();
    chatRoom = Get.arguments as ChatRoom;
    final currentUserId = controller.currentUserId!;
    otherParticipantName = chatRoom.getOtherParticipantName(currentUserId);
    otherParticipantPicture = chatRoom.getOtherParticipantProfilePicture(currentUserId);

    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    controller.openChat(chatRoom);
    _animationController.forward();

    // Auto scroll to bottom when new messages arrive
    ever(controller.messages, (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    _animationController.dispose();
    controller.closeChat();
    super.dispose();
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Reply bar if replying to a message
            _buildReplyBar(),
            // Messages list
            Expanded(child: _buildMessagesList()),
            // Message input
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Get.back(),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
                      image: NetworkImage(otherParticipantPicture!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: otherParticipantPicture == null
                ? Icon(
                    Icons.person,
                    color: AppColors.appColor,
                    size: 20,
                  )
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherParticipantName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Active now',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'delete':
                _showDeleteChatDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Delete Chat',
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          icon: Icon(Icons.more_vert, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildReplyBar() {
    if (replyToMessage == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.appColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.appColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: AppColors.appColor, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${replyToMessage!.senderName}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.appColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  replyToMessage!.message,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => replyToMessage = null),
            icon: Icon(Icons.close, color: Colors.grey[600], size: 16),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Obx(() {
      if (controller.isLoadingMessages.value && controller.messages.isEmpty) {
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

      if (controller.messages.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.appColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: AppColors.appColor,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Start the conversation',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Say hello to $otherParticipantName!',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: scrollController,
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: controller.messages.length,
        itemBuilder: (context, index) {
          final message = controller.messages[index];
          return _buildMessageBubble(message, index);
        },
      );
    });
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isMe = message.senderId == controller.currentUserId;
    final showAvatar = !isMe &&
        (index == 0 || controller.messages[index - 1].senderId != message.senderId);

    // Check if we need to show timestamp
    final showTimestamp = index == 0 ||
        message.timestamp.difference(controller.messages[index - 1].timestamp).inMinutes > 5;

    return Column(
      children: [
        if (showTimestamp) _buildTimestampDivider(message.timestamp),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(isMe ? 20 * (1 - value) : -20 * (1 - value), 0),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMe && showAvatar) _buildAvatar(message),
                      if (!isMe && !showAvatar) SizedBox(width: 32),
                      Flexible(
                        child: GestureDetector(
                          onLongPress: () => _showMessageOptions(message),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                // Reply indicator if this message is a reply
                                if (message.replyToMessage != null)
                                  _buildReplyIndicator(message),
                                // Message bubble
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isMe
                                        ? LinearGradient(
                                            colors: [
                                              AppColors.appColor,
                                              AppColors.appColor.withValues(alpha: 0.8),
                                            ],
                                          )
                                        : LinearGradient(
                                            colors: [
                                              Colors.white,
                                              Colors.grey[50]!,
                                            ],
                                          ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                      bottomLeft: Radius.circular(isMe ? 18 : 6),
                                      bottomRight: Radius.circular(isMe ? 6 : 18),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                    border: !isMe
                                        ? Border.all(
                                            color: Colors.grey.withValues(alpha: 0.2),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    message.message,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: isMe ? Colors.white : Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                // Message time
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: 4,
                                    left: isMe ? 0 : 8,
                                    right: isMe ? 8 : 0,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat.jm().format(message.timestamp),
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      if (isMe) ...[
                                        SizedBox(width: 4),
                                        Icon(
                                          message.isRead
                                              ? Icons.done_all
                                              : Icons.done,
                                          size: 12,
                                          color: message.isRead
                                              ? AppColors.appColor
                                              : Colors.grey[400],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvatar(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(right: 8, bottom: 20),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.appColor.withValues(alpha: 0.2),
            AppColors.appColor.withValues(alpha: 0.1),
          ],
        ),
        image: message.senderProfilePicture != null
            ? DecorationImage(
                image: NetworkImage(message.senderProfilePicture!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: message.senderProfilePicture == null
          ? Icon(
              Icons.person,
              color: AppColors.appColor,
              size: 12,
            )
          : null,
    );
  }

  Widget _buildTimestampDivider(DateTime timestamp) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatDateDivider(timestamp),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: message.senderId == controller.currentUserId
                ? Colors.white.withValues(alpha: 0.5)
                : AppColors.appColor.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Text(
        message.replyToMessage!,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (text) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: 12),
            Obx(() => GestureDetector(
              onTap: controller.isSendingMessage.value ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.appColor,
                      AppColors.appColor.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.appColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: controller.isSendingMessage.value
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _formatDateDivider(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat.EEEE().format(timestamp);
    } else {
      return DateFormat.yMMMd().format(timestamp);
    }
  }

  void _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    messageController.clear();

    await controller.sendMessage(
      text,
      replyToMessageId: replyToMessage?.id,
      replyToMessage: replyToMessage?.message,
    );

    // Clear reply state
    if (replyToMessage != null) {
      setState(() => replyToMessage = null);
    }

    // Scroll to bottom
    _scrollToBottom();
  }

  void _showMessageOptions(ChatMessage message) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.reply, color: AppColors.appColor),
              title: Text(
                'Reply',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Get.back();
                setState(() => replyToMessage = message);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: Colors.blue),
              title: Text(
                'Copy',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.message));
                Get.back();
                Get.snackbar('Copied', 'Message copied to clipboard');
              },
            ),
            if (message.senderId == controller.currentUserId)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Delete',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Get.back();
                  _deleteMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _deleteMessage(ChatMessage message) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Delete Message',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this message?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              if (message.id != null) {
                controller.deleteMessage(message.id!);
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteChatDialog() {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Delete Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this entire conversation? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteChatRoom(chatRoom.id!);
              Get.back(); // Close chat screen
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}