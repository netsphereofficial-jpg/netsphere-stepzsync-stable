import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Filter options for leaderboard
enum LeaderboardFilter {
  friends,
  global,
}

/// Premium toggle widget for switching between Friends and Global leaderboard views
class FilterToggle extends StatelessWidget {
  final LeaderboardFilter selectedFilter;
  final Function(LeaderboardFilter) onFilterChanged;

  const FilterToggle({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterButton(
            filter: LeaderboardFilter.friends,
            label: 'Friends',
            icon: Icons.people_rounded,
          ),
          _buildFilterButton(
            filter: LeaderboardFilter.global,
            label: 'Global',
            icon: Icons.public_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required LeaderboardFilter filter,
    required String label,
    required IconData icon,
  }) {
    final isSelected = selectedFilter == filter;

    return Expanded(
      child: GestureDetector(
        onTap: () => onFilterChanged(filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF2759FF) : Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isSelected ? const Color(0xFF2759FF) : Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}