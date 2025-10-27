# Payment System Setup Guide

This guide covers the complete setup for in-app purchases on both iOS and Android platforms.

## 🛠 Technical Implementation Status

✅ **Completed:**
- Flutter `in_app_purchase` plugin integration
- Cross-platform payment service architecture
- iOS StoreKit implementation
- Android Google Play Billing implementation
- Purchase stream handling
- Error handling and validation
- UI integration with subscription screen

## 📱 Platform Setup Requirements

### iOS App Store Setup

1. **App Store Connect Configuration:**
   - Create subscription products in App Store Connect
   - Set up subscription groups
   - Configure pricing tiers for different regions
   - Add product IDs that match your subscription plans:
     - `premium_1_monthly` - Premium 1 subscription
     - `premium_2_monthly` - Premium 2 subscription

2. **Product Configuration:**
   ```
   Product ID: premium_1_monthly
   Reference Name: Premium 1 Monthly
   Duration: 1 Month
   Price Tier: (Set according to $9.99)

   Product ID: premium_2_monthly
   Reference Name: Premium 2 Monthly
   Duration: 1 Month
   Price Tier: (Set according to $19.99)
   ```

3. **iOS Capabilities:**
   - Ensure "In-App Purchase" capability is enabled in Xcode
   - Add StoreKit configuration file for testing (optional)

4. **Testing:**
   - Create sandbox test users in App Store Connect
   - Test purchases using TestFlight or simulator

### Android Google Play Setup

1. **Google Play Console Configuration:**
   - Create subscription products in Google Play Console
   - Configure base plans and offers
   - Set up product IDs that match your subscription plans:
     - `premium_1_monthly` - Premium 1 subscription
     - `premium_2_monthly` - Premium 2 subscription

2. **Product Configuration:**
   ```
   Product ID: premium_1_monthly
   Product Name: Premium 1 Monthly
   Billing Period: 1 Month
   Price: $9.99 USD (adjust for other currencies)

   Product ID: premium_2_monthly
   Product Name: Premium 2 Monthly
   Billing Period: 1 Month
   Price: $19.99 USD (adjust for other currencies)
   ```

3. **Android Permissions:**
   ✅ Already added: `com.android.vending.BILLING` permission in AndroidManifest.xml

4. **Testing:**
   - Add test accounts in Google Play Console
   - Create internal test track for testing purchases

## 🔧 Implementation Details

### Payment Service Architecture

```
PaymentServiceFactory
├── IOSPaymentService (StoreKit integration)
├── AndroidPaymentService (Google Play Billing)
└── WebPaymentService (Future implementation)
```

### Purchase Flow

1. User taps "Upgrade" button
2. Subscription controller shows confirmation dialog
3. Payment service initiates platform-specific purchase
4. Purchase result comes through purchase stream
5. Controller processes result and updates UI
6. Purchase completion and receipt validation

### Error Handling

- Network connectivity issues
- Invalid product IDs
- Payment authorization failures
- User cancellation
- Pending purchase states

## 🧪 Testing Guide

### Development Testing

1. **Enable Debug Mode:**
   ```dart
   // In payment service initialization
   if (kDebugMode) {
     print('Payment service running in debug mode');
   }
   ```

2. **Test Product IDs:**
   - Use sandbox/test product IDs during development
   - Switch to production IDs for release builds

3. **Test Scenarios:**
   - Successful purchase
   - User cancellation
   - Network failure
   - Invalid product ID
   - Purchase restoration

### Production Testing

1. **iOS:**
   - Test with TestFlight
   - Use sandbox environment initially
   - Verify receipt validation

2. **Android:**
   - Test with internal testing track
   - Verify purchase acknowledgment
   - Test subscription renewal

## 🚨 Important Security Notes

1. **Server-Side Validation:**
   - Always validate receipts on your server
   - Never trust client-side validation alone
   - Implement webhook endpoints for subscription status changes

2. **Receipt Validation URLs:**
   ```
   iOS Sandbox: https://sandbox.itunes.apple.com/verifyReceipt
   iOS Production: https://buy.itunes.apple.com/verifyReceipt

   Android: Use Google Play Developer API
   ```

3. **Shared Secrets:**
   - Store App Store shared secrets securely
   - Use different secrets for different environments

## 📚 Next Steps

1. **App Store Connect Setup:**
   - Create and configure subscription products
   - Set up pricing for all supported regions
   - Configure subscription groups

2. **Google Play Console Setup:**
   - Create subscription products with matching IDs
   - Configure billing periods and pricing
   - Set up base plans

3. **Server Implementation:**
   - Implement receipt validation endpoints
   - Set up webhook handling for subscription events
   - Create subscription management APIs

4. **Testing:**
   - Thorough testing on both platforms
   - Test all edge cases and error scenarios
   - Validate purchase restoration flows

## 🔗 Useful Resources

- [Flutter In-App Purchase Documentation](https://pub.dev/packages/in_app_purchase)
- [Apple StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [Google Play Billing Documentation](https://developer.android.com/google/play/billing)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer/)

---

*Generated with Claude Code - Payment system implementation ready for production deployment*