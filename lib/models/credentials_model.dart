class CredentialsModel {
  final String userId;
  final String email;
  final String accesstoken;
  final String refreshToken;
  final String membershipId;
  final String mobileNumber;
  final String loginPlatform;
  final bool isProfileCompleted;

  CredentialsModel({
    required this.userId,
    required this.email,
    required this.accesstoken,
    required this.refreshToken,
    required this.membershipId,
    required this.mobileNumber,
    required this.loginPlatform,
    required this.isProfileCompleted,
  });

  factory CredentialsModel.fromMap(Map<String, dynamic> map) {
    return CredentialsModel(
      userId: map['userIdC'] ?? '',
      email: map['emailIdC'] ?? '',
      accesstoken: map['accessTokenC'] ?? '',
      refreshToken: map['refreshTokenC'] ?? '',
      membershipId: map['membershipIdC'] ?? '',
      mobileNumber: map['mobileNumberC'] ?? '',
      loginPlatform: map['loginPlatformC'] ?? '',
      isProfileCompleted: (map['isProfileCompletedC'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userIdC': userId,
      'emailIdC': email,
      'accessTokenC': accesstoken,
      'refreshTokenC': refreshToken,
      'membershipIdC': membershipId,
      'mobileNumberC': mobileNumber,
      'loginPlatformC': loginPlatform,
      'isProfileCompletedC': isProfileCompleted ? 1 : 0,
    };
  }

  factory CredentialsModel.fromFirebaseUser({
    required String userId,
    required String email,
    String? accessToken,
    String? refreshToken,
    String membershipId = "1",
    String mobileNumber = "",
    String loginPlatform = "firebase",
    bool isProfileCompleted = false,
  }) {
    return CredentialsModel(
      userId: userId,
      email: email,
      accesstoken: accessToken ?? '',
      refreshToken: refreshToken ?? '',
      membershipId: membershipId,
      mobileNumber: mobileNumber,
      loginPlatform: loginPlatform,
      isProfileCompleted: isProfileCompleted,
    );
  }

  CredentialsModel copyWith({
    String? userId,
    String? email,
    String? accesstoken,
    String? refreshToken,
    String? membershipId,
    String? mobileNumber,
    String? loginPlatform,
    bool? isProfileCompleted,
  }) {
    return CredentialsModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      accesstoken: accesstoken ?? this.accesstoken,
      refreshToken: refreshToken ?? this.refreshToken,
      membershipId: membershipId ?? this.membershipId,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      loginPlatform: loginPlatform ?? this.loginPlatform,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
    );
  }

  @override
  String toString() {
    return 'CredentialsModel(userId: $userId, email: $email, loginPlatform: $loginPlatform, isProfileCompleted: $isProfileCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CredentialsModel &&
      other.userId == userId &&
      other.email == email &&
      other.accesstoken == accesstoken &&
      other.refreshToken == refreshToken &&
      other.membershipId == membershipId &&
      other.mobileNumber == mobileNumber &&
      other.loginPlatform == loginPlatform &&
      other.isProfileCompleted == isProfileCompleted;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
      email.hashCode ^
      accesstoken.hashCode ^
      refreshToken.hashCode ^
      membershipId.hashCode ^
      mobileNumber.hashCode ^
      loginPlatform.hashCode ^
      isProfileCompleted.hashCode;
  }
}