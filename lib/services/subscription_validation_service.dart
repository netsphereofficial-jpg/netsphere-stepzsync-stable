import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription_models.dart';

/// Service for validating subscription purchases with Cloud Functions
/// This service handles server-side receipt validation for security
class SubscriptionValidationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Validate an Apple App Store receipt with server
  /// Returns validated subscription data or throws an error
  Future<Map<String, dynamic>> validateAppleReceipt(String receiptData) async {
    try {
      debugPrint('🍎 Validating Apple receipt with Cloud Function...');

      final callable = _functions.httpsCallable('validateAppleReceipt');
      final result = await callable.call({
        'receiptData': receiptData,
      });

      debugPrint('✅ Apple receipt validated successfully');
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Apple receipt validation failed: ${e.code} - ${e.message}');
      throw SubscriptionValidationException(
        code: e.code,
        message: e.message ?? 'Failed to validate Apple receipt',
        details: e.details,
      );
    } catch (e) {
      debugPrint('❌ Unexpected error validating Apple receipt: $e');
      throw SubscriptionValidationException(
        code: 'unknown',
        message: 'An unexpected error occurred while validating the receipt',
        details: e.toString(),
      );
    }
  }

  /// Validate a Google Play purchase with server
  /// Returns validated subscription data or throws an error
  Future<Map<String, dynamic>> validateGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required String packageName,
  }) async {
    try {
      debugPrint('🤖 Validating Google Play purchase with Cloud Function...');

      final callable = _functions.httpsCallable('validateGooglePlayPurchase');
      final result = await callable.call({
        'productId': productId,
        'purchaseToken': purchaseToken,
        'packageName': packageName,
      });

      debugPrint('✅ Google Play purchase validated successfully');
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Google Play validation failed: ${e.code} - ${e.message}');
      throw SubscriptionValidationException(
        code: e.code,
        message: e.message ?? 'Failed to validate Google Play purchase',
        details: e.details,
      );
    } catch (e) {
      debugPrint('❌ Unexpected error validating Google Play purchase: $e');
      throw SubscriptionValidationException(
        code: 'unknown',
        message: 'An unexpected error occurred while validating the purchase',
        details: e.toString(),
      );
    }
  }

  /// Restore purchases for the current user
  /// Validates existing purchases with the server
  Future<Map<String, dynamic>> restorePurchases({
    required String platform,
    String? receiptData,
    String? purchaseToken,
    String? productId,
    String? packageName,
  }) async {
    try {
      debugPrint('🔄 Restoring purchases with Cloud Function...');

      final callable = _functions.httpsCallable('restorePurchases');
      final result = await callable.call({
        'platform': platform,
        if (receiptData != null) 'receiptData': receiptData,
        if (purchaseToken != null) 'purchaseToken': purchaseToken,
        if (productId != null) 'productId': productId,
        if (packageName != null) 'packageName': packageName,
      });

      debugPrint('✅ Purchases restored successfully');
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Restore purchases failed: ${e.code} - ${e.message}');
      throw SubscriptionValidationException(
        code: e.code,
        message: e.message ?? 'Failed to restore purchases',
        details: e.details,
      );
    } catch (e) {
      debugPrint('❌ Unexpected error restoring purchases: $e');
      throw SubscriptionValidationException(
        code: 'unknown',
        message: 'An unexpected error occurred while restoring purchases',
        details: e.toString(),
      );
    }
  }

  /// Validate a purchase based on platform
  /// This is a convenience method that automatically chooses the right validation method
  Future<Map<String, dynamic>> validatePurchase(PurchaseDetails purchase) async {
    if (Platform.isIOS) {
      // For iOS, use the receipt data from verification data
      final receiptData = purchase.verificationData.serverVerificationData;
      return await validateAppleReceipt(receiptData);
    } else if (Platform.isAndroid) {
      // For Android, use the purchase token
      final purchaseToken = purchase.verificationData.serverVerificationData;
      final productId = purchase.productID;
      // You'll need to configure your package name
      const packageName = 'com.stepzsync.app'; // TODO: Update with your actual package name

      return await validateGooglePlayPurchase(
        productId: productId,
        purchaseToken: purchaseToken,
        packageName: packageName,
      );
    } else {
      throw SubscriptionValidationException(
        code: 'unsupported-platform',
        message: 'Purchase validation is not supported on this platform',
      );
    }
  }
}

/// Exception thrown when subscription validation fails
class SubscriptionValidationException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  SubscriptionValidationException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    return 'SubscriptionValidationException($code): $message${details != null ? ' - $details' : ''}';
  }
}
