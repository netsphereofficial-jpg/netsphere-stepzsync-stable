import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String? id;
  final String fullName;
  final String? username;
  final String phoneNumber;
  final String countryCode;
  final String gender;
  final DateTime? dateOfBirth;
  final String location;
  final double height;
  final String heightUnit;
  final double weight;
  final String weightUnit;
  final bool healthKitEnabled;
  final bool profileCompleted;
  final String email;
  final String? profilePicture;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // XP-related fields
  final int? totalXP;
  final int? level;
  final String? country;
  final String? city;
  // FCM notification fields
  final String? fcmToken;
  final DateTime? fcmTokenUpdatedAt;

  UserProfile({
    this.id,
    required this.fullName,
    this.username,
    required this.phoneNumber,
    required this.countryCode,
    required this.gender,
    this.dateOfBirth,
    required this.location,
    required this.height,
    required this.heightUnit,
    required this.weight,
    required this.weightUnit,
    this.healthKitEnabled = false,
    this.profileCompleted = false,
    required this.email,
    this.profilePicture,
    this.createdAt,
    this.updatedAt,
    this.totalXP,
    this.level,
    this.country,
    this.city,
    this.fcmToken,
    this.fcmTokenUpdatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'username': username,
      'usernameLower': username?.toLowerCase(), // For case-insensitive search
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
      'gender': gender,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'location': location,
      'height': height,
      'heightUnit': heightUnit,
      'weight': weight,
      'weightUnit': weightUnit,
      'healthKitEnabled': healthKitEnabled,
      'profileCompleted': profileCompleted,
      'email': email,
      'profilePicture': profilePicture,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'totalXP': totalXP,
      'level': level,
      'country': country,
      'city': city,
      'fcmToken': fcmToken,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json, {String? id}) {
    return UserProfile(
      id: id,
      fullName: json['fullName'] ?? '',
      username: json['username'],
      phoneNumber: json['phoneNumber'] ?? '',
      countryCode: json['countryCode'] ?? '+91',
      gender: json['gender'] ?? '',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      location: json['location'] ?? '',
      height: (json['height'] ?? 0).toDouble(),
      heightUnit: json['heightUnit'] ?? 'cms',
      weight: (json['weight'] ?? 0).toDouble(),
      weightUnit: json['weightUnit'] ?? 'Kgs',
      healthKitEnabled: json['healthKitEnabled'] ?? false,
      profileCompleted: json['profileCompleted'] ?? false,
      email: json['email'] ?? '',
      profilePicture: json['profilePicture'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      totalXP: json['totalXP'],
      level: json['level'],
      country: json['country'],
      city: json['city'],
      fcmToken: json['fcmToken'],
      fcmTokenUpdatedAt: json['fcmTokenUpdatedAt'] != null
          ? DateTime.parse(json['fcmTokenUpdatedAt'])
          : null,
    );
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile.fromJson(data, id: doc.id);
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? username,
    String? phoneNumber,
    String? countryCode,
    String? gender,
    DateTime? dateOfBirth,
    String? location,
    double? height,
    String? heightUnit,
    double? weight,
    String? weightUnit,
    bool? healthKitEnabled,
    bool? profileCompleted,
    String? email,
    String? profilePicture,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalXP,
    int? level,
    String? country,
    String? city,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      location: location ?? this.location,
      height: height ?? this.height,
      heightUnit: heightUnit ?? this.heightUnit,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      healthKitEnabled: healthKitEnabled ?? this.healthKitEnabled,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      email: email ?? this.email,
      profilePicture: profilePicture ?? this.profilePicture,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalXP: totalXP ?? this.totalXP,
      level: level ?? this.level,
      country: country ?? this.country,
      city: city ?? this.city,
      fcmToken: fcmToken ?? this.fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt ?? this.fcmTokenUpdatedAt,
    );
  }
}

enum Gender {
  male('1', 'Male'),
  female('2', 'Female');

  const Gender(this.value, this.label);
  final String value;
  final String label;

  static Gender? fromValue(String value) {
    for (Gender gender in Gender.values) {
      if (gender.value == value) return gender;
    }
    return null;
  }
}

enum HeightUnit {
  cms('cms', 'Cms'),
  inches('inches', 'Inches');

  const HeightUnit(this.value, this.label);
  final String value;
  final String label;

  static HeightUnit fromValue(String value) {
    for (HeightUnit unit in HeightUnit.values) {
      if (unit.value == value) return unit;
    }
    return HeightUnit.cms;
  }
}

enum WeightUnit {
  kgs('Kgs', 'Kgs'),
  lbs('Lbs', 'Lbs');

  const WeightUnit(this.value, this.label);
  final String value;
  final String label;

  static WeightUnit fromValue(String value) {
    for (WeightUnit unit in WeightUnit.values) {
      if (unit.value == value) return unit;
    }
    return WeightUnit.kgs;
  }
}