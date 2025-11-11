import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service for managing AdMob rewarded video ads
/// Used to gate premium features for free users
class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  bool _isInitialized = false;

  /// Test ad units (replace with your actual ad units in production)
  /// To get real ad units:
  /// 1. Go to https://apps.admob.com/
  /// 2. Create an app
  /// 3. Add a rewarded ad unit
  /// 4. Copy the ad unit IDs
  static String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      // TODO: Replace with your Android rewarded ad unit ID
      return 'ca-app-pub-3940256099942544/5224354917'; // Test ad unit
    } else if (Platform.isIOS) {
      // TODO: Replace with your iOS rewarded ad unit ID
      return 'ca-app-pub-3940256099942544/1712485313'; // Test ad unit
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Initialize AdMob SDK on-demand (lazy initialization)
  /// Called automatically when first needed
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    await MobileAds.instance.initialize();
    _isInitialized = true;
    print('🎬 AdMob SDK initialized (lazy)');
  }

  /// Load a rewarded video ad
  Future<void> loadRewardedAd() async {
    // Ensure AdMob SDK is initialized before loading ads
    await _ensureInitialized();

    if (_isAdLoading || _isAdLoaded) {
      print('⚠️ Ad is already loaded or loading');
      return;
    }

    _isAdLoading = true;
    print('📺 Loading rewarded ad...');

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ Rewarded ad loaded successfully');
          _rewardedAd = ad;
          _isAdLoaded = true;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          _isAdLoaded = false;
        },
      ),
    );
  }

  /// Show rewarded ad and return whether user watched it completely
  /// Returns true if user earned the reward, false otherwise
  Future<bool> showRewardedAd() async {
    if (!_isAdLoaded || _rewardedAd == null) {
      print('⚠️ Rewarded ad is not loaded yet');
      return false;
    }

    // Use Completer to wait for the reward callback
    final completer = Completer<bool>();
    bool adDismissed = false;

    // Set up one-time callbacks for this ad show
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        print('📺 Ad showed full screen content');
      },
      onAdDismissedFullScreenContent: (ad) {
        print('📺 Ad dismissed');
        adDismissed = true;
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;

        // If completer hasn't completed yet, complete with false (user didn't earn reward)
        if (!completer.isCompleted) {
          completer.complete(false);
        }

        // Preload next ad
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('❌ Ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;

        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    // Show the ad
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        print('🎁 User earned reward: ${reward.amount} ${reward.type}');

        // Complete with true when reward is earned
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
    );

    // Wait for either reward or dismissal (with 10 second timeout)
    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ Ad reward callback timed out');
          return false;
        },
      );

      print('✅ showRewardedAd returning: $result');
      return result;
    } catch (e) {
      print('❌ Error waiting for ad reward: $e');
      return false;
    }
  }

  /// Check if an ad is ready to show
  bool get isAdReady => _isAdLoaded && _rewardedAd != null;

  /// Check if an ad is currently loading
  bool get isLoading => _isAdLoading;

  /// Dispose of the current ad
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    _isAdLoading = false;
  }
}
