import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_colors.dart';
import '../../../core/models/race_data_model.dart';
import '../../../screens/race_map/race_map_screen.dart';
import '../../../services/race_bot_service.dart';
import '../../../widgets/common/custom_app_bar.dart';

class QuickRaceWaitingRoomScreen extends StatefulWidget {
  final String raceId;
  final RaceData raceData;
  final int maxParticipants;
  final double raceDistance; // in km

  const QuickRaceWaitingRoomScreen({
    super.key,
    required this.raceId,
    required this.raceData,
    required this.maxParticipants,
    required this.raceDistance,
  });

  @override
  State<QuickRaceWaitingRoomScreen> createState() => _QuickRaceWaitingRoomScreenState();
}

class _QuickRaceWaitingRoomScreenState extends State<QuickRaceWaitingRoomScreen>
    with TickerProviderStateMixin {
  // Countdown timer
  late int _remainingSeconds;
  Timer? _countdownTimer;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  // Participants stream
  StreamSubscription? _participantsSubscription;
  List<Participant> _participants = [];

  // Flags
  bool _hasNavigated = false;
  bool _botsAdded = false;
  bool _raceFilled = false; // Track if race is already filled to prevent duplicate triggers

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 30; // 30 second countdown

    log('[WAITING_ROOM] Initializing waiting room for race: ${widget.raceId}');

    // Initialize animation controllers
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
      value: 1.0,
    );

    // Start countdown timer
    _startCountdown();

    // Listen to participants
    _listenToParticipants();
  }

  void _startCountdown() {
    log('[WAITING_ROOM] Starting countdown timer');
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      log('[WAITING_ROOM] Countdown: $_remainingSeconds seconds remaining');

      // Fill bots at 5 seconds if slots are still empty
      if (_remainingSeconds == 5 && !_botsAdded) {
        _fillBotsIfNeeded();
      }

      // When timer reaches 0, wait a moment then navigate
      if (_remainingSeconds <= 0) {
        timer.cancel();
        // Add 2 second delay to let users see all bots that joined
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            _navigateToRaceMap();
          }
        });
      }
    });
  }

  void _listenToParticipants() {
    log('[WAITING_ROOM] Setting up participant listener');
    _participantsSubscription = FirebaseFirestore.instance
        .collection('races')
        .doc(widget.raceId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        _participants = snapshot.docs
            .map((doc) => Participant.fromFirestore(doc))
            .toList();
      });

      log('[WAITING_ROOM] Participants updated: ${_participants.length}/${widget.maxParticipants}');

      // Check if race is now filled
      if (_participants.length == widget.maxParticipants && !_raceFilled && !_hasNavigated) {
        log('[WAITING_ROOM] Race is now filled! Starting auto-countdown...');
        _raceFilled = true;
        _onRaceFilled();
      }
    }, onError: (error) {
      log('[WAITING_ROOM] Error listening to participants: $error');
    });
  }

  void _onRaceFilled() {
    log('[WAITING_ROOM] All slots filled! Cancelling countdown and starting race in 3 seconds...');

    // Cancel the existing countdown timer
    _countdownTimer?.cancel();

    // Set remaining seconds to 3 for the "Get Ready" countdown
    setState(() {
      _remainingSeconds = 3;
    });

    // Start a new 3-second countdown
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      log('[WAITING_ROOM] Get ready countdown: $_remainingSeconds seconds');

      // Navigate when countdown reaches 0
      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (mounted) {
          _navigateToRaceMap();
        }
      }
    });
  }

  Future<void> _fillBotsIfNeeded() async {
    if (_botsAdded) return;

    final slotsToFill = widget.maxParticipants - _participants.length;
    if (slotsToFill <= 0) return;

    _botsAdded = true;
    log('[WAITING_ROOM] Adding $slotsToFill bots to fill empty slots (5 seconds remaining)...');

    try {
      // Ensure RaceBotService is instantiated (lazy singleton)
      RaceBotService botService;
      if (Get.isRegistered<RaceBotService>()) {
        botService = Get.find<RaceBotService>();
        log('[WAITING_ROOM] Found existing RaceBotService instance');
      } else {
        botService = Get.put<RaceBotService>(RaceBotService());
        log('[WAITING_ROOM] Created new RaceBotService instance');
      }

      await botService.addBotsToRace(
        raceId: widget.raceId,
        botCount: slotsToFill,
        raceDistance: widget.raceDistance * 1000, // Convert km to meters
      );

      // Start bot simulation
      await botService.startBotSimulation(widget.raceId);

      log('[WAITING_ROOM] Bots added and simulation started successfully');
    } catch (e) {
      log('[WAITING_ROOM] Error adding bots: $e');
    }
  }

  void _navigateToRaceMap() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    log('[WAITING_ROOM] Navigating to Race Map Screen');

    // Clean up
    _participantsSubscription?.cancel();
    _countdownTimer?.cancel();

    // Navigate to race map with fade animation
    Get.off(
      () => RaceMapScreen(
        raceModel: widget.raceData,
        role: UserRole.participant,
      ),
      transition: Transition.fadeIn,
      duration: Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    log('[WAITING_ROOM] Disposing waiting room screen');
    _countdownTimer?.cancel();
    _participantsSubscription?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('[WAITING_ROOM] Building screen');
    final filledSlots = _participants.length;
    final emptySlots = widget.maxParticipants - filledSlots;
    final progress = filledSlots / widget.maxParticipants;

    return PopScope(
      canPop: false, // Prevent back navigation during waiting
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: CustomAppBar(
          title: "Finding Racers...",
          isBack: true, // Disable back button
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(height: 12),

                // Main countdown timer
                _buildCountdownTimer(),

                SizedBox(height: 24),

                // Participants grid
                _buildParticipantsHeader(filledSlots),

                SizedBox(height: 16),

                // Progress indicator
                _buildProgressBar(progress),

                SizedBox(height: 20),

                // Participant slots grid
                Expanded(
                  child: _buildParticipantGrid(filledSlots, emptySlots),
                ),

                SizedBox(height: 16),

                // Race info
                _buildRaceInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownTimer() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.appColor,
                  AppColors.appColor.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.appColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_remainingSeconds',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'sec',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantsHeader(int filledSlots) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people, color: AppColors.appColor, size: 24),
        SizedBox(width: 8),
        Text(
          'Racers',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        SizedBox(width: 12),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.appColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.appColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Text(
            '$filledSlots / ${widget.maxParticipants}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.appColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    String statusText;
    if (_remainingSeconds <= 0) {
      statusText = 'Starting race...';
    } else if (progress == 1.0) {
      statusText = 'All slots filled! Get ready...';
    } else {
      statusText = 'Waiting for racers to join...';
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.appColor),
          ),
        ),
        SizedBox(height: 8),
        Text(
          statusText,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _remainingSeconds <= 0
                ? AppColors.appColor
                : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantGrid(int filledSlots, int emptySlots) {
    return GridView.builder(
      physics: BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.maxParticipants,
      itemBuilder: (context, index) {
        if (index < _participants.length) {
          // Filled slot
          return _buildFilledSlot(_participants[index]);
        } else {
          // Empty slot
          return _buildEmptySlot();
        }
      },
    );
  }

  Widget _buildFilledSlot(Participant participant) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade50,
                  Colors.green.shade100,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.shade300,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.appColor,
                        AppColors.appColor.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      participant.userName.isNotEmpty
                          ? participant.userName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),

                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        participant.userName.isNotEmpty
                            ? participant.userName
                            : 'Racer',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Ready',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Check icon
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          // Empty avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
            ),
            child: Icon(
              Icons.person_outline,
              color: Colors.grey.shade500,
              size: 20,
            ),
          ),
          SizedBox(width: 10),

          // Waiting text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Waiting...',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  'Empty',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Hourglass icon
          Icon(
            Icons.hourglass_empty,
            color: Colors.grey.shade400,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildRaceInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.appColor.withValues(alpha: 0.1),
            AppColors.appColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.appColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            icon: Icons.directions_run,
            label: 'Distance',
            value: '${widget.raceDistance.toStringAsFixed(1)} km',
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.appColor.withValues(alpha: 0.2),
          ),
          _buildInfoItem(
            icon: Icons.timer,
            label: 'Duration',
            value: '${widget.raceData.durationMins ?? 5} mins',
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.appColor.withValues(alpha: 0.2),
          ),
          _buildInfoItem(
            icon: Icons.flash_on,
            label: 'Type',
            value: 'Quick Race',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.appColor, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}