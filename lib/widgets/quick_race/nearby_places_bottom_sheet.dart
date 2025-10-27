import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../models/place_model.dart';
import '../../services/places_service.dart';

class NearbyPlacesBottomSheet extends StatefulWidget {
  final LocationCategory category;
  final double userLatitude;
  final double userLongitude;
  final Function(PlaceResult) onPlaceSelected;

  const NearbyPlacesBottomSheet({
    super.key,
    required this.category,
    required this.userLatitude,
    required this.userLongitude,
    required this.onPlaceSelected,
  });

  @override
  State<NearbyPlacesBottomSheet> createState() => _NearbyPlacesBottomSheetState();
}

class _NearbyPlacesBottomSheetState extends State<NearbyPlacesBottomSheet> {
  final PlacesService _placesService = PlacesService();
  List<PlaceResult> _places = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
  }

  Future<void> _loadNearbyPlaces() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final places = await _placesService.getPlacesByCategory(
        latitude: widget.userLatitude,
        longitude: widget.userLongitude,
        category: widget.category,
        radius: 5000, // 5km radius
        maxResults: 10,
      );

      setState(() {
        _places = places;
        _isLoading = false;
        if (places.isEmpty) {
          _errorMessage = 'No ${widget.category.displayName.toLowerCase()} found nearby';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load nearby places';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.category.icon,
                    color: widget.category.color,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category.displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        widget.category.description,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // Content
          Flexible(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: widget.category.color,
            ),
            SizedBox(height: 16),
            Text(
              'Finding nearby places...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            TextButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              onPressed: _loadNearbyPlaces,
              style: TextButton.styleFrom(
                foregroundColor: widget.category.color,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(vertical: 12),
      itemCount: _places.length,
      separatorBuilder: (context, index) => Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        return _buildPlaceItem(_places[index]);
      },
    );
  }

  Widget _buildPlaceItem(PlaceResult place) {
    return InkWell(
      onTap: () {
        widget.onPlaceSelected(place);
        Navigator.pop(context);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.category.icon,
                color: widget.category.color,
                size: 24,
              ),
            ),

            SizedBox(width: 14),

            // Place info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    place.formattedAddress,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the bottom sheet
Future<PlaceResult?> showNearbyPlacesBottomSheet({
  required BuildContext context,
  required LocationCategory category,
  required double userLatitude,
  required double userLongitude,
}) {
  return showModalBottomSheet<PlaceResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => NearbyPlacesBottomSheet(
        category: category,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        onPlaceSelected: (place) => Navigator.pop(context, place),
      ),
    ),
  );
}
