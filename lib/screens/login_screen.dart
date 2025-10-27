import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/design_system.dart';
import '../config/assets/icons.dart';
import '../controllers/login/login_controller.dart';
import '../services/preferences_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LoginController _loginCtr = Get.put(LoginController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.screenVertical,
          ),
          child: Obx(() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Heading
                Text(
                  _loginCtr.headerTitle,
                  style: AppTextStyles.heading,
                ),
                SizedBox(height: 8),

                // Subtitle
                Text(
                  _loginCtr.headerSubtitle,
                  style: AppTextStyles.subtitle,
                ),
                SizedBox(height: AppSpacing.sectionSpacing),

                // Email/Phone Field
                AuthTextField(
                  label: _loginCtr.isMobile.value ? 'Phone Number' : 'Email Address',
                  hint: _loginCtr.isMobile.value ? 'Enter your phone number' : 'Enter your email',
                  controller: _loginCtr.isMobile.value ? _loginCtr.mobileCtr : _loginCtr.emailCtr,
                  keyboardType: _loginCtr.isMobile.value
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
                ),
                SizedBox(height: AppSpacing.fieldSpacing),

                // Password Field (conditional)
                if (_loginCtr.showPasswordField) ...[
                  AuthTextField(
                    label: 'Password',
                    hint: 'Enter your password',
                    controller: _loginCtr.passwordCtr,
                    obscureText: _loginCtr.isPasswordObscured(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _loginCtr.isPasswordObscured()
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppDesignColors.label,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _loginCtr.togglePasswordVisibility();
                      },
                    ),
                  ),
                  SizedBox(height: AppSpacing.fieldSpacing),
                ],

                // Confirm Password Field (only in signup mode)
                if (_loginCtr.authMode.value == AuthMode.signup) ...[
                  AuthTextField(
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    controller: _loginCtr.confirmPasswordCtr,
                    obscureText: _loginCtr.isConfirmPasswordObscured(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _loginCtr.isConfirmPasswordObscured()
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppDesignColors.label,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _loginCtr.toggleConfirmPasswordVisibility();
                      },
                    ),
                  ),
                  SizedBox(height: AppSpacing.small),
                ],

                // Forgot Password (only in login mode)
                if (_loginCtr.showForgotPassword)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _loginCtr.switchToForgotPassword();
                      },
                      child: Text(
                        'Forgot Password?',
                        style: AppTextStyles.linkText,
                      ),
                    ),
                  ),

                SizedBox(height: AppSpacing.buttonSpacing),

                // Sign In Button
                AuthButton(
                  text: _loginCtr.submitButtonText,
                  isLoading: _loginCtr.isLoading.value,
                  onPressed: () async{
                    await _requestNotificationPermissionOnce();
                    HapticFeedback.mediumImpact();
                    _loginCtr.signInClick();
                  },
                ),

                // Only show social login in login/signup modes
                if (_loginCtr.authMode.value != AuthMode.forgotPassword) ...[
                  SizedBox(height: AppSpacing.buttonSpacing),

                  // Divider
                  AuthDivider(text: 'or'),

                  SizedBox(height: AppSpacing.buttonSpacing),

                  // Social Login Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SocialLoginButton(
                        logo: SvgPicture.asset(
                          IconPaths.googleLogo,
                          width: 24,
                          height: 24,
                        ),
                        isLoading: _loginCtr.isGoogleLoading.value,
                        onTap: () async{
                          await _requestNotificationPermissionOnce();
                          HapticFeedback.mediumImpact();
                          _loginCtr.signInWithGoogle();
                        },
                      ),
                      if (!kIsWeb && Platform.isIOS) ...[
                        SizedBox(width: AppSpacing.medium),
                        SocialLoginButton(
                          logo: SvgPicture.asset(
                            IconPaths.appleLogo,
                            width: 24,
                            height: 24,
                          ),
                          isLoading: _loginCtr.isAppleLoading.value,
                          onTap: () async{
                            await _requestNotificationPermissionOnce();
                            HapticFeedback.mediumImpact();
                            _loginCtr.signInWithApple();
                          },
                        ),
                      ],
                    ],
                  ),

                  // Guest Mode Button (only in login mode)
                  if (_loginCtr.authMode.value == AuthMode.login) ...[
                    SizedBox(height: AppSpacing.buttonSpacing),
                    GuestButton(
                      text: 'Continue as Guest',
                      isLoading: _loginCtr.isLoading.value,
                      onPressed: () async {
                        await _requestNotificationPermissionOnce();
                        HapticFeedback.mediumImpact();
                        _loginCtr.signInAsGuest();
                      },
                    ),
                  ],
                ],

                Spacer(),

                // Bottom Sign Up Link
                Center(
                  child: BottomActionText(
                    normalText: _loginCtr.bottomText,
                    actionText: _loginCtr.bottomActionText,
                    onActionTap: () async{
                      await _requestNotificationPermissionOnce();
                      HapticFeedback.lightImpact();
                      _loginCtr.handleBottomAction();
                    },
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
  /// Request notification permission once on first home screen load
  Future<void> _requestNotificationPermissionOnce() async {
    try {
      // Skip notification permission for guest users


      final prefs = Get.find<PreferencesService>();
      final hasRequested = await prefs.hasRequestedNotificationPermission();

      if (!hasRequested) {
        print('📱 First home screen load - requesting notification permission...');

        // Small delay to let home screen render first
        await Future.delayed(Duration(milliseconds: 500));

        final status = await Permission.notification.request();
        print('✅ Notification permission: ${status.isGranted ? "Granted" : "Denied"}');

        // Mark as requested so we don't ask again
        await prefs.setHasRequestedNotificationPermission(true);
      } else {
        print('ℹ️ Notification permission already requested');
      }
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
    }
  }
}