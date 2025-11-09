import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionPlanType {
  free,
  premium1,
  premium2,
  lifetime,
}

enum SubscriptionStatus {
  active,
  inactive,
  expired,
  cancelled,
}

class SubscriptionFeature {
  final String title;
  final bool isAvailable;
  final String? limitText;

  const SubscriptionFeature({
    required this.title,
    required this.isAvailable,
    this.limitText,
  });

  factory SubscriptionFeature.available(String title) {
    return SubscriptionFeature(title: title, isAvailable: true);
  }

  factory SubscriptionFeature.unavailable(String title) {
    return SubscriptionFeature(title: title, isAvailable: false);
  }

  factory SubscriptionFeature.limited(String title, String limitText) {
    return SubscriptionFeature(
      title: title,
      isAvailable: true,
      limitText: limitText,
    );
  }
}

class SubscriptionPlan {
  final SubscriptionPlanType type;
  final String name;
  final String subtitle;
  final String emoji;
  final String? price;
  final String? originalPrice;
  final String? billingPeriod;
  final String badge;
  final List<SubscriptionFeature> features;
  final bool isPopular;
  final bool isCurrent;
  final String? googlePlayProductId;
  final String? appleProductId;

  const SubscriptionPlan({
    required this.type,
    required this.name,
    required this.subtitle,
    required this.emoji,
    this.price,
    this.originalPrice,
    this.billingPeriod,
    required this.badge,
    required this.features,
    this.isPopular = false,
    this.isCurrent = false,
    this.googlePlayProductId,
    this.appleProductId,
  });

  static List<SubscriptionPlan> getAllPlans() {
    return [
      // Free Plan
      SubscriptionPlan(
        type: SubscriptionPlanType.free,
        name: "Free Plan",
        subtitle: "City Access",
        emoji: "🆓",
        badge: "FREE",
        isCurrent: true, // This would be determined dynamically
        features: [
          SubscriptionFeature.limited("City-only races", "City only"),
          SubscriptionFeature.limited("Join races", "Up to 3 races"),
          SubscriptionFeature.limited("Create races", "Up to 2 races"),
          SubscriptionFeature.unavailable("No marathons"),
          SubscriptionFeature.limited("Basic statistics", "distance, time, HR, calories"),
          SubscriptionFeature.available("Basic BPM tracking"),
          SubscriptionFeature.available("Basic calories & effort data"),
          SubscriptionFeature.available("Basic breathing mode"),
          SubscriptionFeature.available("Basic event notifications"),
          SubscriptionFeature.available("Add/remove/search friends"),
          SubscriptionFeature.limited("Basic 1-on-1 chat", "no history"),
          SubscriptionFeature.unavailable("No leaderboards"),
          SubscriptionFeature.unavailable("No Hall of Fame"),
          SubscriptionFeature.available("Basic race invites"),
        ],
      ),

      // Premium 1 Plan
      SubscriptionPlan(
        type: SubscriptionPlanType.premium1,
        name: "Premium 1",
        subtitle: "Country Access",
        emoji: "⭐",
        price: "\$9.99",
        originalPrice: "\$14.99",
        billingPeriod: "/month",
        badge: "POPULAR",
        isPopular: true,
        googlePlayProductId: "premium_1_monthly",
        appleProductId: "premium_1_monthly",
        features: [
          SubscriptionFeature.limited("City + Country races", "Country level"),
          SubscriptionFeature.limited("Join races", "Up to 7 races"),
          SubscriptionFeature.limited("Create races", "Up to 7 races"),
          SubscriptionFeature.available("Local/Country marathons"),
          SubscriptionFeature.available("Advanced statistics + filters"),
          SubscriptionFeature.available("Heart-rate zones + recovery insights"),
          SubscriptionFeature.available("Detailed calorie & effort analysis"),
          SubscriptionFeature.available("Full breathing pack (relax, focus, recovery)"),
          SubscriptionFeature.available("Custom reminders (hydration, pacing, countdowns)"),
          SubscriptionFeature.available("Compare stats with friends locally"),
          SubscriptionFeature.available("Same chat as free"),
          SubscriptionFeature.available("Local/Country leaderboards"),
          SubscriptionFeature.unavailable("No Hall of Fame"),
          SubscriptionFeature.available("Country-level race invites"),
        ],
      ),

      // Premium 2 Plan
      SubscriptionPlan(
        type: SubscriptionPlanType.premium2,
        name: "Premium 2",
        subtitle: "World/Elite Access",
        emoji: "🏆",
        price: "\$19.99",
        originalPrice: "\$29.99",
        billingPeriod: "/month",
        badge: "BEST VALUE",
        googlePlayProductId: "premium_2_monthly",
        appleProductId: "premium_2_monthly",
        features: [
          SubscriptionFeature.available("Global races (worldwide)"),
          SubscriptionFeature.limited("Join races", "Up to 20 races"),
          SubscriptionFeature.limited("Create races", "Up to 20 races"),
          SubscriptionFeature.limited("International marathons", "up to 20"),
          SubscriptionFeature.available("Advanced statistics + global comparison"),
          SubscriptionFeature.available("Full heart-rate analysis + effort scoring"),
          SubscriptionFeature.available("Global calorie & effort benchmarks"),
          SubscriptionFeature.available("Elite breathing pack + custom rhythms"),
          SubscriptionFeature.available("Advanced scheduling + marathon reminders"),
          SubscriptionFeature.available("Full friend insights + global challenge history"),
          SubscriptionFeature.available("Advanced chat (group chat, delete/archive, history)"),
          SubscriptionFeature.available("Global/regional/age-group leaderboards"),
          SubscriptionFeature.available("Hall of Fame (badges & achievements showcase)"),
          SubscriptionFeature.available("Exclusive global invites + team battles"),
        ],
      ),

      // Lifetime Plan - Christmas Special
      SubscriptionPlan(
        type: SubscriptionPlanType.lifetime,
        name: "Lifetime Premium",
        subtitle: "One-Time Payment",
        emoji: "⭐",
        price: "\$299",
        originalPrice: "\$600",
        billingPeriod: "one-time",
        badge: "CHRISTMAS SPECIAL",
        googlePlayProductId: "lifetime_premium",
        appleProductId: "lifetime_premium",
        features: [
          SubscriptionFeature.available("🌍 All Premium 2 features"),
          SubscriptionFeature.available("♾️ Lifetime access - pay once, use forever"),
          SubscriptionFeature.available("🎄 50% OFF Christmas Special"),
          SubscriptionFeature.available("🚫 No monthly fees ever"),
          SubscriptionFeature.available("⚡ Priority customer support"),
          SubscriptionFeature.available("🎁 Exclusive lifetime member badge"),
          SubscriptionFeature.available("🔓 All future premium features included"),
        ],
      ),
    ];
  }

  static SubscriptionPlan getFreePlan() {
    return getAllPlans().firstWhere((plan) => plan.type == SubscriptionPlanType.free);
  }

  static SubscriptionPlan getPremium1Plan() {
    return getAllPlans().firstWhere((plan) => plan.type == SubscriptionPlanType.premium1);
  }

  static SubscriptionPlan getPremium2Plan() {
    return getAllPlans().firstWhere((plan) => plan.type == SubscriptionPlanType.premium2);
  }

  static SubscriptionPlan getLifetimePlan() {
    return getAllPlans().firstWhere((plan) => plan.type == SubscriptionPlanType.lifetime);
  }
}

class UserSubscription {
  final SubscriptionPlanType currentPlan;
  final SubscriptionStatus status;
  final DateTime? expiryDate;
  final DateTime? purchaseDate;
  final String? transactionId;
  final String? originalTransactionId;
  final String? purchaseToken;
  final String? platform;
  final bool autoRenew;
  final DateTime? lastValidated;
  final Map<String, dynamic> features;

  const UserSubscription({
    required this.currentPlan,
    required this.status,
    this.expiryDate,
    this.purchaseDate,
    this.transactionId,
    this.originalTransactionId,
    this.purchaseToken,
    this.platform,
    this.autoRenew = false,
    this.lastValidated,
    this.features = const {},
  });

  bool get isActive => status == SubscriptionStatus.active;
  // bool get isPremium => currentPlan != SubscriptionPlanType.free && isActive;
  bool get isPremium => true;
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    return expiryDate!.difference(DateTime.now()).inDays <= 7;
  }

  factory UserSubscription.free() {
    return const UserSubscription(
      currentPlan: SubscriptionPlanType.free,
      status: SubscriptionStatus.active,
      features: {
        'hasGlobalAccess': false,
        'maxRaces': 3,
        'hasLeaderboards': false,
        'hasHallOfFame': false,
        'hasAdvancedStats': false,
        'hasHeartRateZones': false,
        'hasMarathons': false,
        'hasGroupChat': false,
      },
    );
  }

  /// Create UserSubscription from Firebase document data
  factory UserSubscription.fromFirebaseMap(Map<String, dynamic> map) {
    return UserSubscription(
      currentPlan: _parseSubscriptionPlanType(map['currentPlan'] as String?),
      status: _parseSubscriptionStatus(map['status'] as String?),
      expiryDate: _parseTimestamp(map['expiryDate']),
      purchaseDate: _parseTimestamp(map['purchaseDate']),
      transactionId: map['transactionId'] as String?,
      originalTransactionId: map['originalTransactionId'] as String?,
      purchaseToken: map['purchaseToken'] as String?,
      platform: map['platform'] as String?,
      autoRenew: map['autoRenew'] as bool? ?? false,
      lastValidated: _parseTimestamp(map['lastValidated']),
      features: Map<String, dynamic>.from(map['features'] as Map? ?? {}),
    );
  }

  /// Convert UserSubscription to Firebase document data
  Map<String, dynamic> toFirebaseMap() {
    return {
      'currentPlan': currentPlan.name,
      'status': status.name,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'purchaseDate': purchaseDate != null ? Timestamp.fromDate(purchaseDate!) : null,
      'transactionId': transactionId,
      'originalTransactionId': originalTransactionId,
      'purchaseToken': purchaseToken,
      'platform': platform,
      'autoRenew': autoRenew,
      'lastValidated': lastValidated != null ? Timestamp.fromDate(lastValidated!) : null,
      'features': features,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  /// Parse subscription plan type from string
  static SubscriptionPlanType _parseSubscriptionPlanType(String? planType) {
    switch (planType) {
      case 'premium1':
        return SubscriptionPlanType.premium1;
      case 'premium2':
        return SubscriptionPlanType.premium2;
      case 'lifetime':
        return SubscriptionPlanType.lifetime;
      case 'free':
      default:
        return SubscriptionPlanType.free;
    }
  }

  /// Parse subscription status from string
  static SubscriptionStatus _parseSubscriptionStatus(String? status) {
    switch (status) {
      case 'active':
        return SubscriptionStatus.active;
      case 'inactive':
        return SubscriptionStatus.inactive;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      default:
        return SubscriptionStatus.active;
    }
  }

  /// Parse Firestore Timestamp to DateTime
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is DateTime) {
      return timestamp;
    }
    return null;
  }

  /// Copy with method for updates
  UserSubscription copyWith({
    SubscriptionPlanType? currentPlan,
    SubscriptionStatus? status,
    DateTime? expiryDate,
    DateTime? purchaseDate,
    String? transactionId,
    String? originalTransactionId,
    String? purchaseToken,
    String? platform,
    bool? autoRenew,
    DateTime? lastValidated,
    Map<String, dynamic>? features,
  }) {
    return UserSubscription(
      currentPlan: currentPlan ?? this.currentPlan,
      status: status ?? this.status,
      expiryDate: expiryDate ?? this.expiryDate,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      transactionId: transactionId ?? this.transactionId,
      originalTransactionId: originalTransactionId ?? this.originalTransactionId,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      platform: platform ?? this.platform,
      autoRenew: autoRenew ?? this.autoRenew,
      lastValidated: lastValidated ?? this.lastValidated,
      features: features ?? this.features,
    );
  }

  /// Get feature value by key
  T? getFeature<T>(String key) {
    return features[key] as T?;
  }

  /// Check if has specific feature
  bool hasFeature(String key) {
    return features[key] == true;
  }

  @override
  String toString() {
    return 'UserSubscription(plan: $currentPlan, status: $status, isPremium: $isPremium)';
  }
}