import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/race_chat_models.dart';

class RaceChatMessageWidget extends StatelessWidget {
  final RaceChatMessage message;
  final bool isCurrentUser;
  final Function(RaceChatMessage)? onReply;

  const RaceChatMessageWidget({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            _buildAvatar(),
            SizedBox(width: 8),
          ],

          Flexible(
            child: GestureDetector(
              onLongPress: onReply != null ? () => onReply!(message) : null,
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Sender name (only for other users)
                  if (!isCurrentUser)
                    Padding(
                      padding: EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        message.senderName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.appColor,
                        ),
                      ),
                    ),

                  // Reply indicator
                  if (message.replyToMessage != null)
                    _buildReplyIndicator(),

                  // Message bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? AppColors.appColor
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(18).copyWith(
                        bottomRight: isCurrentUser
                            ? Radius.circular(4)
                            : Radius.circular(18),
                        bottomLeft: !isCurrentUser
                            ? Radius.circular(4)
                            : Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.message,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isCurrentUser ? Colors.white : Colors.black87,
                            height: 1.3,
                          ),
                        ),

                        SizedBox(height: 4),

                        // Timestamp
                        Text(
                          _formatTime(message.timestamp),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isCurrentUser
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isCurrentUser) ...[
            SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.appColor.withValues(alpha: 0.1),
      ),
      child: message.senderProfilePicture != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                message.senderProfilePicture!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
              ),
            )
          : _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.appColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Text(
          message.senderName.isNotEmpty
              ? message.senderName.substring(0, 1).toUpperCase()
              : '?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.appColor,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      margin: EdgeInsets.only(
        bottom: 4,
        left: isCurrentUser ? 0 : 12,
        right: isCurrentUser ? 12 : 0,
      ),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replying to:',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 2),
          Text(
            message.replyToMessage ?? '',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    } else if (difference.inHours > 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}