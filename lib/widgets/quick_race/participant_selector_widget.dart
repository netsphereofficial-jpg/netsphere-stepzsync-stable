import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';

class ParticipantSelectorWidget extends StatelessWidget {
  final int selectedCount;
  final Function(int) onChanged;

  const ParticipantSelectorWidget({
    super.key,
    required this.selectedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final participants = [
      {'value': 2, 'label': '2', 'icon': Icons.people, 'color': Color(0xFF10B981)},
      {'value': 4, 'label': '4', 'icon': Icons.group, 'color': Color(0xFF3B82F6)},
      {'value': 5, 'label': '5', 'icon': Icons.groups, 'color': Color(0xFFF59E0B)},
    ];

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.appColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.appColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group, color: AppColors.appColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Participants',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Participant chips - Single row
          Row(
            children: participants.map((participant) {
              final isSelected = selectedCount == participant['value'];

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: participant != participants.last ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => onChanged(participant['value'] as int),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (participant['color'] as Color).withValues(alpha: 0.15)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? (participant['color'] as Color)
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            participant['icon'] as IconData,
                            color: isSelected
                                ? (participant['color'] as Color)
                                : Colors.grey[600],
                            size: 18,
                          ),
                          SizedBox(height: 4),
                          Text(
                            participant['label'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? (participant['color'] as Color)
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
