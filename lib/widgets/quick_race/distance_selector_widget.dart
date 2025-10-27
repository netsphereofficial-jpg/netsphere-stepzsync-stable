import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';

class DistanceSelectorWidget extends StatelessWidget {
  final double selectedDistance;
  final Function(double) onChanged;

  const DistanceSelectorWidget({
    super.key,
    required this.selectedDistance,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final distances = [
      {'value': 1.0, 'label': '1 KM', 'icon': Icons.directions_walk, 'color': Color(0xFF10B981)},
      {'value': 2.0, 'label': '2 KM', 'icon': Icons.directions_run, 'color': Color(0xFF3B82F6)},
      {'value': 5.0, 'label': '5 KM', 'icon': Icons.run_circle, 'color': Color(0xFFF59E0B)},
      {'value': 7.0, 'label': '7 KM', 'icon': Icons.terrain, 'color': Color(0xFFEF4444)},
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
              Icon(Icons.route, color: AppColors.appColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Distance',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Distance chips - Single row
          Row(
            children: distances.map((distance) {
              final isSelected = selectedDistance == distance['value'];

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: distance != distances.last ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => onChanged(distance['value'] as double),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (distance['color'] as Color).withValues(alpha: 0.15)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? (distance['color'] as Color)
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            distance['icon'] as IconData,
                            color: isSelected
                                ? (distance['color'] as Color)
                                : Colors.grey[600],
                            size: 18,
                          ),
                          SizedBox(height: 4),
                          Text(
                            distance['label'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? (distance['color'] as Color)
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
