import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../controllers/chat_controller.dart';
import '../../core/models/race_data_model.dart';
import '../../models/race_chat_models.dart';
import 'race_chat_message_widget.dart';

class RaceChatBottomSheet extends StatefulWidget {
  final RaceData raceModel;

  const RaceChatBottomSheet({super.key, required this.raceModel});

  @override
  State<RaceChatBottomSheet> createState() => _RaceChatBottomSheetState();
}

class _RaceChatBottomSheetState extends State<RaceChatBottomSheet>
    with TickerProviderStateMixin {
  final ChatController chatController = Get.find<ChatController>();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  RaceChatMessage? replyToMessage;
  bool _isInitialized = false;
  final RxBool _hasText = false.obs;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0.0, 1.0),
      end: Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _initializeRaceChat();
    _animationController.forward();

    // Listen to text changes
    messageController.addListener(() {
      _hasText.value = messageController.text.trim().isNotEmpty;
    });

    // Auto scroll to bottom when new messages arrive
    ever(chatController.raceMessages, (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    });
  }

  Future<void> _initializeRaceChat() async {
    try {
      final raceChatRoom = await chatController.createOrGetRaceChatRoom(widget.raceModel);
      if (raceChatRoom != null && mounted) {
        chatController.openRaceChat(raceChatRoom);
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing race chat: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    _animationController.dispose();
    chatController.closeRaceChat();
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
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                _buildHeader(),
                // Divider
                Divider(height: 1, color: Colors.grey[200]),
                // Messages list
                Expanded(child: _buildMessagesList()),
                // Reply bar
                _buildReplyBar(),
                // Message input
                _buildMessageInput(),
              ],
            ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          // Race chat icon
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.appColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              color: AppColors.appColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),

          // Title and participants count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.raceModel.title ?? 'Race Chat',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Obx(() {
                  final participantCount = chatController.currentRaceChatRoom.value?.participantIds.length ?? 0;
                  return Text(
                    '$participantCount participant${participantCount != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  );
                }),
              ],
            ),
          ),

          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.keyboard_arrow_down, size: 28),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (!_isInitialized) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.appColor),
        ),
      );
    }

    return Obx(() {
      if (!_isInitialized || (chatController.isLoadingRaceMessages.value && chatController.raceMessages.isEmpty)) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.appColor),
              ),
              SizedBox(height: 16),
              Text(
                _isInitialized ? 'Loading messages...' : 'Setting up chat...',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      if (chatController.raceMessages.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: Colors.grey[300],
              ),
              SizedBox(height: 16),
              Text(
                'No messages yet',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Start the conversation with your race participants!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: chatController.raceMessages.length,
        itemBuilder: (context, index) {
          final message = chatController.raceMessages[index];
          final isCurrentUser = message.senderId == chatController.currentUserId;

          return RaceChatMessageWidget(
            message: message,
            isCurrentUser: isCurrentUser,
            onReply: (message) {
              setState(() {
                replyToMessage = message;
              });
            },
          );
        },
      );
    });
  }

  Widget _buildReplyBar() {
    if (replyToMessage == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.appColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
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
            onPressed: () {
              setState(() {
                replyToMessage = null;
              });
            },
            icon: Icon(Icons.close, size: 20),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
            Expanded(
              child: Container(
                constraints: BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: messageController,
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
              ),
            ),
            SizedBox(width: 12),
            Obx(() {
              final canSend = _hasText.value && !chatController.isSendingRaceMessage.value;
              return GestureDetector(
                onTap: canSend ? _sendMessage : null,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: canSend ? AppColors.appColor : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: chatController.isSendingRaceMessage.value
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              );
            }),
          ],
        ),
    );
  }

  Future<void> _sendMessage() async {
    final message = messageController.text.trim();
    if (message.isEmpty || chatController.isSendingRaceMessage.value) return;

    // Clear the input immediately for better UX
    messageController.clear();

    // Vibrate for feedback
    HapticFeedback.lightImpact();

    // Send the message
    await chatController.sendRaceMessage(
      message,
      replyToMessageId: replyToMessage?.id,
      replyToMessage: replyToMessage?.message,
    );

    // Clear reply if it exists
    if (replyToMessage != null) {
      setState(() {
        replyToMessage = null;
      });
    }
  }
}