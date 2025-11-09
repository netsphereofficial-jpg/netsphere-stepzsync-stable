# StepZSync - Signed APK Build Guide

## Quick Reference
This guide contains all the information needed to build properly signed release APKs for the StepZSync application.

---

## Project Configuration

### Package Details
- **Package Name**: `com.health.stepzsync.stepzsync`
- **Application ID**: `com.health.stepzsync.stepzsync`
- **Firebase Project ID**: `stepzsync-750f9`

---

## Keystore Information

### Keystore Location & Credentials
- **Keystore Path**: `/Users/nikhil/Desktop/Security/Keystores/stepzsync-upload-keystore.jks`
- **Key Alias**: `upload`
- **Store Password**: `StepZSync2025!Secure`
- **Key Password**: `StepZSync2025!Secure`

### Certificate Details
- **Owner**: CN=Netsphere Technologies, OU=Mobile, O=Netsphere Technologies, L=Unknown, ST=Unknown, C=US
- **Valid Until**: March 19, 2053
- **Certificate Type**: Self-signed
- **Algorithm**: SHA256withRSA

### SHA Fingerprints
- **SHA1**: `11:2B:34:8D:95:E6:B8:A8:F1:C5:2C:0E:12:E4:A8:2C:A3:88:71:E0`
- **SHA256**: `83:A8:02:41:BA:83:FD:F9:D3:32:A3:08:AC:18:87:5A:BB:F2:09:7D:DF:6D:8F:F8:00:C3:79:0C:CC:D0:04:44`

**IMPORTANT**: The SHA1 fingerprint matches the certificate hash in `google-services.json` (line 30)

---

## Build Configuration Files

### 1. key.properties Location
**Path**: `/Users/nikhil/StudioProjects/netsphere-stepzsync-stable/android/key.properties`

**Content**:
```properties
storePassword=StepZSync2025!Secure
keyPassword=StepZSync2025!Secure
keyAlias=upload
storeFile=/Users/nikhil/Desktop/Security/Keystores/stepzsync-upload-keystore.jks
```

### 2. build.gradle.kts Configuration
**Path**: `/Users/nikhil/StudioProjects/netsphere-stepzsync-stable/android/app/build.gradle.kts`

The signing configuration is already set up in lines 48-71:
- Reads key.properties file
- Creates release signing config
- Applies to release build type
- Enables ProGuard/R8 optimization (minification + resource shrinking)

### 3. google-services.json
**Path**: `/Users/nikhil/StudioProjects/netsphere-stepzsync-stable/android/app/google-services.json`

Contains Firebase configuration with SHA certificate hashes that must match the keystore.

---

## Building Signed APKs

### Method 1: Flutter Build (Recommended for universal APK)
```bash
cd /Users/nikhil/StudioProjects/netsphere-stepzsync-stable
flutter clean
flutter build apk --release
```

**Output**: `build/app/outputs/flutter-apk/app-release.apk` (~105 MB)

### Method 2: Flutter Build (Split APKs by ABI)
```bash
cd /Users/nikhil/StudioProjects/netsphere-stepzsync-stable
flutter clean
flutter build apk --release --split-per-abi
```

**Output**:
- `app-arm64-v8a-release.apk` (~46 MB) - Modern 64-bit ARM devices
- `app-armeabi-v7a-release.apk` (~43 MB) - Older 32-bit ARM devices
- `app-x86_64-release.apk` (~48 MB) - x86_64 devices/emulators

### Method 3: App Bundle (Recommended for Play Store)
```bash
cd /Users/nikhil/StudioProjects/netsphere-stepzsync-stable
flutter clean
flutter build appbundle --release
```

**Output**: `build/app/outputs/bundle/release/app-release.aab` (~73 MB)

---

## Manual Signing (If Needed)

If the APK is built unsigned, manually sign it using jarsigner:

```bash
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore /Users/nikhil/Desktop/Security/Keystores/stepzsync-upload-keystore.jks \
  -storepass "StepZSync2025!Secure" \
  -keypass "StepZSync2025!Secure" \
  /path/to/app-release.apk \
  upload
```

---

## Verification Commands

### Verify APK is Signed
```bash
jarsigner -verify /path/to/app-release.apk
```

**Expected Output**: `jar verified.` (with warnings about self-signed cert, which is normal)

### Extract SHA1 Fingerprint from APK
```bash
unzip -p /path/to/app-release.apk META-INF/UPLOAD.RSA | keytool -printcert | grep "SHA1:"
```

**Expected Output**: `SHA1: 11:2B:34:8D:95:E6:B8:A8:F1:C5:2C:0E:12:E4:A8:2C:A3:88:71:E0`

### Verify Keystore SHA1
```bash
keytool -list -v -keystore /Users/nikhil/Desktop/Security/Keystores/stepzsync-upload-keystore.jks \
  -storepass "StepZSync2025!Secure" -alias upload | grep "SHA1:"
```

**Expected Output**: `SHA1: 11:2B:34:8D:95:E6:B8:A8:F1:C5:2C:0E:12:E4:A8:2C:A3:88:71:E0`

---

## Troubleshooting

### Issue: APK built unsigned
**Solution**: Ensure `key.properties` exists in the android directory with correct keystore path

### Issue: SHA fingerprint mismatch with Firebase
**Solution**:
1. Extract SHA1 from signed APK using verification commands above
2. Update Firebase console with the correct SHA1 fingerprint
3. Download new `google-services.json` and replace in `android/app/`

### Issue: Build fails with Gradle error
**Solution**:
1. Run `flutter clean`
2. Delete `android/.gradle` directory
3. Rebuild

### Issue: Keystore not found
**Solution**: Verify keystore exists at `/Users/nikhil/Desktop/Security/Keystores/stepzsync-upload-keystore.jks`
- Backup location: `/Volumes/Macintiosh/Backup_2025-11-04/projects/StudioProjects/netsphere-stepzsync-stable/android/key.properties`

---

## "App Not Installed - Package Appears Invalid" Error

This error occurs when users try to install your APK on their devices. Here are the most common causes and solutions:

### Diagnostic Steps

#### 1. Check Installation Error via ADB
If you have access to the device:
```bash
# Enable USB debugging on the device
# Connect device via USB

# Check device is connected
adb devices

# Install APK and see detailed error
adb install -r /path/to/app-release.apk

# Monitor installation logs
adb logcat | grep -i "package\|install"
```

**Common error codes**:
- `INSTALL_FAILED_UPDATE_INCOMPATIBLE`: Signature mismatch with existing app
- `INSTALL_FAILED_NO_MATCHING_ABIS`: Wrong architecture (ARM vs x86)
- `INSTALL_PARSE_FAILED_NO_CERTIFICATES`: Missing or corrupted signatures
- `INSTALL_FAILED_OLDER_SDK`: Device Android version too old (< Android 8.0)

#### 2. Check Device Architecture
```bash
# Find out device architecture
adb shell getprop ro.product.cpu.abi

# Results:
# "arm64-v8a" → Use app-arm64-v8a-release.apk (most modern phones)
# "armeabi-v7a" → Use app-armeabi-v7a-release.apk (older phones)
# "x86_64" → Use app-x86_64-release.apk (emulators/tablets)
```

### Solution 1: Complete Uninstallation (Most Common Fix)

**Problem**: Previous version still exists in device (possibly in work profile or other user)

**Fix on Device**:
1. Settings > Apps > StepZSync > Uninstall
2. If available: Tap menu (3 dots) > "Uninstall for all users"
3. Restart device
4. Install new APK

**Fix via ADB**:
```bash
# Uninstall completely (all users)
adb uninstall com.health.stepzsync.stepzsync

# Clear package manager cache
adb shell pm clear com.android.packageinstaller
adb shell pm clear com.google.android.packageinstaller

# Reboot device
adb reboot

# After reboot, install
adb install /path/to/app-release.apk
```

### Solution 2: Use Universal APK Instead of Split APK

**Problem**: User installed wrong architecture APK (e.g., ARM64 APK on ARM32 device)

**Fix**: Always distribute the **universal APK** for general use:
```bash
# Build universal APK (works on all devices)
flutter build apk --release

# Distribute: build/app/outputs/flutter-apk/app-release.apk
```

Only use split APKs when you can determine the user's device architecture or for Play Store uploads.

### Solution 3: Disable Play Protect

**Problem**: Google Play Protect blocking installation of unknown apps

**Fix on Device**:
1. Open Google Play Store
2. Tap profile icon > Play Protect
3. Tap Settings (gear icon)
4. Toggle off "Scan apps with Play Protect"
5. Install the APK
6. Re-enable Play Protect after installation

### Solution 4: Enable Installation from Unknown Sources

**Problem**: Device security settings blocking APK installation

**Fix on Device (Android 8.0+)**:
1. When installation is blocked, tap "Settings"
2. Enable "Allow from this source"
3. Go back and install again

**Manual Method**:
1. Settings > Security (or Apps & notifications)
2. Find "Install unknown apps"
3. Select the browser/file manager you're using
4. Enable "Allow from this source"

### Solution 5: Verify APK is Not Corrupted

**Problem**: APK file corrupted during download/transfer

**Fix**:
```bash
# Verify APK signature is intact
jarsigner -verify /path/to/app-release.apk

# Should show "jar verified."
# If it shows "jar is unsigned" or errors, rebuild the APK
```

**Prevent corruption**:
- Upload to Google Drive, Dropbox, or Firebase Hosting (NOT WhatsApp)
- Verify file size after download matches original
- Use file checksum verification if distributing widely

### Solution 6: Check Signature Schemes (UPDATED)

**Problem**: APK missing v1 signature scheme for older Android versions

**Fix**: As of the latest build, this is now configured automatically with:
- v1 Signing (JAR) - for Android < 7.0
- v2 Signing (Full APK) - for Android 7.0+
- v3 Signing (Key rotation) - for Android 9.0+
- v4 Signing (Streaming) - for Android 11+

All new builds will include all signature schemes for maximum compatibility.

### Solution 7: Test ProGuard Configuration

**Problem**: Code minification causing APK corruption

**Test**:
```bash
# Build without minification
flutter build apk --release --no-shrink

# If this installs successfully, ProGuard rules need fixing
```

**Fix**: Edit `android/app/proguard-rules.pro` to exclude problematic classes

### User Instructions Template

When sharing your APK with users, include these instructions:

```
StepZSync Installation Guide

BEFORE INSTALLING:
1. If StepZSync is already installed, uninstall it completely:
   - Settings > Apps > StepZSync > Uninstall
   - If you see "Uninstall for all users" option, use that
   - Restart your phone

2. Enable installation from unknown sources:
   - The system will prompt you when installing
   - Tap "Settings" and enable "Allow from this source"

INSTALLATION:
1. Download app-release.apk
2. Open the downloaded file
3. Tap "Install"
4. If blocked by Play Protect, tap "Install anyway"

TROUBLESHOOTING:
If you see "App not installed" error:
- Make sure you uninstalled the old version completely
- Restart your phone and try again
- Temporarily disable Play Protect in Play Store settings
- Make sure you have Android 8.0 or higher
- Ensure you have at least 150MB free storage

MINIMUM REQUIREMENTS:
- Android 8.0 (Oreo) or higher
- 100MB free storage
- Internet connection for initial setup

For help, contact: support@netsphere.tech
```

### Quick Troubleshooting Reference

| User Report | Most Likely Cause | Solution |
|------------|------------------|----------|
| "App not installed" on first install | Play Protect or unknown sources | Disable Play Protect, enable unknown sources |
| "App not installed" when updating | Signature mismatch | Uninstall old version completely, restart device |
| "Package appears invalid" | Wrong architecture or corrupted | Use universal APK, re-download |
| Works on some devices, not others | Architecture mismatch | Distribute universal APK instead of split |
| "Not compatible with device" | Android version too old | User needs Android 8.0+, check minSdk |
| Installation succeeds but app crashes | ProGuard issue | Test with --no-shrink flag |

---

## Build Optimization Settings

The release build includes:
- **MinifyEnabled**: true (ProGuard/R8 code shrinking)
- **ShrinkResources**: true (Removes unused resources)
- **ProGuard Rules**: `android/app/proguard-rules.pro`
- **Tree-shaking**: Enabled for assets (MaterialIcons reduced 98.8%)

---

## Output Locations

### APK Files
```
build/app/outputs/flutter-apk/
├── app-release.apk                    # Universal APK (all architectures)
├── app-arm64-v8a-release.apk         # 64-bit ARM
├── app-armeabi-v7a-release.apk       # 32-bit ARM
└── app-x86_64-release.apk            # x86_64
```

### App Bundle
```
build/app/outputs/bundle/release/
└── app-release.aab                    # For Google Play Store
```

---

## Google Play Store Upload Checklist

- [ ] Build signed app bundle: `flutter build appbundle --release`
- [ ] Verify SHA1 matches Firebase console
- [ ] Test on physical device
- [ ] Verify ProGuard rules don't break functionality
- [ ] Check app size is reasonable
- [ ] Upload `app-release.aab` to Play Console
- [ ] Upload deobfuscation file: `build/app/outputs/mapping/release/mapping.txt`

---

## Important Notes

1. **Never commit key.properties or keystore files to version control**
2. **Keep backup of keystore** - Losing it means you cannot update the app on Play Store
3. **SHA1 fingerprint must match** Firebase/Google Services configuration
4. **Certificate validity**: Until 2053-03-19 (self-signed, standard for Android)
5. **Backup location**: `/Volumes/Macintiosh/Backup_2025-11-04/`

---

## Quick Command Reference

```bash
# Clean and build universal signed APK
flutter clean && flutter build apk --release

# Build split APKs
flutter clean && flutter build apk --release --split-per-abi

# Build app bundle for Play Store
flutter clean && flutter build appbundle --release

# Verify signing
jarsigner -verify build/app/outputs/flutter-apk/app-release.apk

# Check SHA1
unzip -p build/app/outputs/flutter-apk/app-release.apk META-INF/UPLOAD.RSA | keytool -printcert | grep "SHA1:"
```

---

**Last Updated**: November 9, 2025
**Project**: StepZSync (Netsphere Technologies)
**Build Tool**: Flutter with Android Gradle Plugin
**Signing Tool**: jarsigner (Java)
