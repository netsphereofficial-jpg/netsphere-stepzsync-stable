import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/season_model.dart';

/// Premium dropdown widget for selecting a season
class SeasonDropdown extends StatelessWidget {
  final Season? selectedSeason;
  final List<Season> seasons;
  final Function(Season?) onSeasonChanged;
  final bool isLoading;

  const SeasonDropdown({
    super.key,
    required this.selectedSeason,
    required this.seasons,
    required this.onSeasonChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 100,
          height: 20,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
      );
    }

    if (seasons.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No Seasons',
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<Season>(
        value: selectedSeason,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 24),
        dropdownColor: const Color(0xFF2759FF),
        borderRadius: BorderRadius.circular(12),
        isDense: true,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        items: seasons.map((season) {
          return DropdownMenuItem<Season>(
            value: season,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (season.isCurrent) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF39FF14),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  season.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: season.isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: onSeasonChanged,
      ),
    );
  }
}