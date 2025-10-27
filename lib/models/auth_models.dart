enum AuthMode {
  login,
  signup,
  forgotPassword,
}

enum AuthType {
  email,
  mobile,
}

class AuthResult {
  final bool success;
  final String? message;
  final String? error;
  final dynamic data;
  
  AuthResult({
    required this.success,
    this.message,
    this.error,
    this.data,
  });
  
  factory AuthResult.success({String? message, dynamic data}) {
    return AuthResult(
      success: true,
      message: message,
      data: data,
    );
  }
  
  factory AuthResult.failure({required String error}) {
    return AuthResult(
      success: false,
      error: error,
    );
  }
}

class AuthCredentials {
  final String? email;
  final String? mobile;
  final String? password;
  final String? countryCode;
  
  AuthCredentials({
    this.email,
    this.mobile,
    this.password,
    this.countryCode,
  });
  
  bool get isEmailAuth => email != null && email!.isNotEmpty;
  bool get isMobileAuth => mobile != null && mobile!.isNotEmpty;
  
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'mobile': mobile,
      'password': password,
      'countryCode': countryCode,
    };
  }
}