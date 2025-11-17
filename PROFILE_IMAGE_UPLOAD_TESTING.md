# Profile Image Upload - Advanced Edge Case Testing Guide

## Overview
This document provides comprehensive testing scenarios for the robust profile image upload system with optimistic UI, retry logic, network recovery, and persistent upload queue.

## Features Implemented

### 1. **Optimistic UI** ✅
- Image displays instantly when selected from gallery/camera
- Upload happens in background
- User sees immediate feedback

### 2. **Network Recovery** ✅
- Automatic detection of network loss
- Pauses upload during network interruption
- Auto-resumes when network is restored
- Shows "Waiting for network..." status

### 3. **Retry Logic** ✅
- Automatic retry on failed uploads (up to 3 attempts)
- Exponential backoff (3s, 6s, 9s delays)
- Shows "Retrying... (Attempt X/3)" status
- Orange indicator during retry

### 4. **Persistent Upload Queue** ✅
- Saves pending upload to SharedPreferences
- Survives app restart/kill
- Resumes upload automatically on next app launch
- Cleanup on success or cancellation

### 5. **User-Friendly Error Handling** ✅
- Clear error messages for different failure types
- Distinguishes between recoverable and unrecoverable errors
- Keeps local image visible during retries
- Reverts to previous state on permanent failure

## Testing Scenarios

### Test 1: Normal Upload (Happy Path)
**Steps:**
1. Open profile screen
2. Tap edit icon on profile picture
3. Select image from gallery or take photo with camera
4. Observe image appears instantly
5. Watch small progress indicator in bottom-right corner
6. Navigate to home screen

**Expected Results:**
- ✅ Image shows immediately after selection
- ✅ Progress indicator appears (0-100%)
- ✅ Progress indicator disappears when complete
- ✅ Image appears on home screen without refresh
- ✅ No error messages
- ✅ Upload completes in 2-3 seconds

---

### Test 2: Navigation Away During Upload
**Steps:**
1. Start uploading a large image (>2MB)
2. Immediately navigate to home screen (while uploading)
3. Wait 5 seconds
4. Navigate back to profile screen

**Expected Results:**
- ✅ Upload continues in background
- ✅ New image appears on profile when returning
- ✅ Upload completes even when not on profile screen
- ✅ No errors or crashes

---

### Test 3: App Kill During Upload
**Steps:**
1. Start uploading an image
2. Immediately force-kill the app (swipe away from task manager)
3. Wait 3 seconds
4. Reopen the app
5. Navigate to profile screen

**Expected Results:**
- ✅ Upload resumes automatically on app restart
- ✅ Profile image updates to new image (may take a few seconds)
- ✅ No duplicate uploads
- ✅ No errors

---

### Test 4: Network Interruption - WiFi Off
**Steps:**
1. Ensure WiFi is on
2. Start uploading an image
3. Immediately turn off WiFi
4. Observe status message
5. Wait 5 seconds
6. Turn WiFi back on

**Expected Results:**
- ✅ Shows "Waiting for network..." message immediately
- ✅ Shows info snackbar: "Upload paused. Will resume automatically when connected."
- ✅ Local image remains visible
- ✅ Upload resumes automatically when WiFi reconnects
- ✅ Upload completes successfully
- ✅ No error messages

---

### Test 5: Network Interruption - Airplane Mode
**Steps:**
1. Start uploading an image
2. Enable airplane mode during upload
3. Wait 10 seconds (observe UI)
4. Disable airplane mode

**Expected Results:**
- ✅ Detects network loss immediately
- ✅ Shows network waiting status
- ✅ Local image stays visible
- ✅ Upload resumes when network returns
- ✅ Completes successfully

---

### Test 6: Weak/Intermittent Network
**Steps:**
1. Use iOS Network Link Conditioner or Android Network Throttling
2. Set to "Very Bad Network" or "3G Slow"
3. Upload an image
4. Observe retry behavior

**Expected Results:**
- ✅ Upload may fail first attempt
- ✅ Shows "Retrying... (Attempt 1/3)" with orange indicator
- ✅ Exponential backoff delays between retries
- ✅ Eventually succeeds if network stabilizes
- ✅ Local image remains visible during all retries

---

### Test 7: Permanent Network Failure (No Retry Success)
**Steps:**
1. Turn off all network (WiFi + Cellular)
2. Start uploading an image
3. Keep network off for 30+ seconds
4. Wait for all retry attempts to fail

**Expected Results:**
- ✅ Shows "Retrying... (Attempt 1/3)"
- ✅ Shows "Retrying... (Attempt 2/3)"
- ✅ Shows "Retrying... (Attempt 3/3)"
- ✅ After 3 failed attempts, shows error: "Upload failed after 3 attempts"
- ✅ Reverts to previous profile picture
- ✅ Local image is removed

---

### Test 8: Multiple Rapid Image Changes
**Steps:**
1. Upload image A
2. Before upload completes, upload image B
3. Before B completes, upload image C

**Expected Results:**
- ✅ Each new upload cancels/replaces previous pending upload
- ✅ Only the latest image (C) uploads
- ✅ No duplicate uploads
- ✅ No memory leaks
- ✅ Final image is C

---

### Test 9: Large Image Upload (>5MB)
**Steps:**
1. Try to upload an image larger than 5MB
2. Observe behavior

**Expected Results:**
- ✅ Shows error: "Image size must be less than 5MB. Current size: X.XXmb"
- ✅ Upload is rejected immediately
- ✅ No upload attempt made
- ✅ User can select a different image

---

### Test 10: Authentication Error
**Steps:**
1. Sign in to app
2. In parallel, sign out from Firebase Console
3. Try uploading profile image

**Expected Results:**
- ✅ Shows error: "User not authenticated"
- ✅ No upload attempt made
- ✅ Local image is removed
- ✅ No crashes

---

### Test 11: Camera Permission Denied
**Steps:**
1. Tap edit icon
2. Select "Take Photo"
3. Deny camera permission when prompted

**Expected Results:**
- ✅ Shows error: "Camera permission is required to take photos"
- ✅ Does not crash
- ✅ Can try again and grant permission

---

### Test 12: Camera Permission Permanently Denied
**Steps:**
1. Deny camera permission twice (permanently denied)
2. Tap edit icon
3. Select "Take Photo"

**Expected Results:**
- ✅ Shows error: "Camera permission is required. Please enable it in Settings."
- ✅ Opens app settings when user taps prompt
- ✅ User can enable permission in settings

---

### Test 13: Storage Permission Denied (Gallery)
**Steps:**
1. Tap edit icon
2. Select "Choose from Gallery"
3. Deny photo library permission

**Expected Results:**
- ✅ Shows appropriate permission error
- ✅ User can retry and grant permission
- ✅ No crashes

---

### Test 14: Image Compression
**Steps:**
1. Upload a high-resolution image (4K or higher)
2. Observe upload speed and final file size

**Expected Results:**
- ✅ Image is compressed before upload
- ✅ Upload completes in 2-3 seconds
- ✅ Image quality remains good (512x512, 75% quality)
- ✅ File size reduced by ~70-80%

---

### Test 15: Cache Invalidation
**Steps:**
1. Upload new profile image
2. Wait for completion
3. Check home screen
4. Force close and reopen app
5. Check both profile and home screens

**Expected Results:**
- ✅ New image shows on home screen immediately
- ✅ After app restart, new image persists
- ✅ No old cached images shown
- ✅ Cache-busting timestamp added to URLs

---

### Test 16: Firestore Update Failure
**Steps:**
1. Upload an image
2. Simulate Firestore permission error (disable Firestore temporarily)
3. Observe behavior

**Expected Results:**
- ✅ Image uploads to Storage successfully
- ✅ Firestore update fails
- ✅ Shows error: "Failed to update profile"
- ✅ Retry logic kicks in
- ✅ Eventually shows failure after retries

---

### Test 17: Concurrent Uploads from Multiple Devices
**Steps:**
1. Sign in on Device A
2. Sign in on Device B with same account
3. Upload different images on both devices simultaneously

**Expected Results:**
- ✅ Both uploads succeed
- ✅ Last upload wins (expected behavior)
- ✅ Both devices sync to show same final image
- ✅ No race conditions or crashes

---

### Test 18: Background Upload Cleanup
**Steps:**
1. Upload 10 images consecutively
2. Check Firebase Storage for old images

**Expected Results:**
- ✅ Old images are deleted asynchronously
- ✅ Storage doesn't accumulate all 10 images
- ✅ Only 1-3 most recent images remain
- ✅ Cleanup happens in background

---

### Test 19: Low Memory Scenario
**Steps:**
1. Open many apps to reduce available memory
2. Upload a large image in your app

**Expected Results:**
- ✅ Image upload succeeds despite low memory
- ✅ App doesn't crash
- ✅ Compression helps reduce memory usage

---

### Test 20: Dark/Light Mode Switching
**Steps:**
1. Start uploading an image
2. Switch system theme (dark/light mode)
3. Observe UI during upload

**Expected Results:**
- ✅ Upload continues without interruption
- ✅ UI adapts to new theme
- ✅ Progress indicator remains visible
- ✅ No visual glitches

---

## Status Messages Reference

| Status | Message | Color | Icon | Meaning |
|--------|---------|-------|------|---------|
| Uploading | "Uploading... X%" | Blue | Cloud upload | Normal upload in progress |
| Retrying | "Retrying... (Attempt X/3)" | Orange | Loading spinner | Failed, retrying with backoff |
| Network Error | "Waiting for network..." | Blue | Cloud upload | No network, will auto-resume |
| Success | (Hidden) | - | - | Upload completed successfully |
| Failed | "Upload failed after 3 attempts" | Red | - | All retries exhausted |

## Performance Benchmarks

| Scenario | Expected Time | Notes |
|----------|---------------|-------|
| Small image (<500KB) | 1-2 seconds | With compression |
| Medium image (1-2MB) | 2-3 seconds | With compression |
| Large image (3-5MB) | 3-5 seconds | With compression |
| Network recovery | <1 second | From detection to resume |
| Retry delay (1st) | 3 seconds | Exponential backoff |
| Retry delay (2nd) | 6 seconds | Exponential backoff |
| Retry delay (3rd) | 9 seconds | Exponential backoff |

## Code Quality Checks

### ✅ Completed
- [x] No memory leaks (StreamSubscription properly disposed)
- [x] No print statements (using proper error handling)
- [x] Proper error types and messages
- [x] Optimistic UI with fallback
- [x] Network change detection
- [x] Exponential backoff retry
- [x] Persistent upload queue
- [x] Cache invalidation
- [x] Background deletion
- [x] Compression before upload
- [x] Progress tracking
- [x] User-friendly status messages
- [x] Permission handling
- [x] File size validation
- [x] Authentication checks

## Known Limitations

1. **Max Retries**: Limited to 3 attempts to prevent infinite loops
2. **File Size**: Maximum 5MB (configurable in code)
3. **Image Format**: Compressed to JPEG for consistency
4. **Storage Cleanup**: Keeps 3 most recent images (configurable)
5. **Simultaneous Uploads**: Only 1 active upload per user at a time

## Future Enhancements (Optional)

- [ ] Manual retry button for failed uploads
- [ ] Upload queue for multiple images
- [ ] Image cropping before upload
- [ ] Multiple profile picture slots (avatar gallery)
- [ ] Upload analytics/telemetry
- [ ] Pause/resume button for large uploads
- [ ] Upload speed display (KB/s)

## Support & Troubleshooting

### Issue: Upload stuck at 0%
**Solution**: Check network connectivity. Turn WiFi/data off and back on.

### Issue: Old image still showing
**Solution**: Pull-to-refresh on profile screen. Check cache clearing.

### Issue: "User not authenticated" error
**Solution**: Sign out and sign back in. Check Firebase Auth status.

### Issue: Upload fails every time
**Solution**: Check Firebase Storage rules, check file size (<5MB), check network.

### Issue: Image quality looks poor
**Solution**: Adjust compression quality in firebase_storage_service.dart (line 36).

---

**Testing Checklist Summary:**
- [ ] Normal upload (Test 1)
- [ ] Navigation away (Test 2)
- [ ] App kill (Test 3)
- [ ] WiFi off (Test 4)
- [ ] Airplane mode (Test 5)
- [ ] Weak network (Test 6)
- [ ] All retries fail (Test 7)
- [ ] Multiple images (Test 8)
- [ ] Large file (Test 9)
- [ ] Auth error (Test 10)
- [ ] Camera permission (Tests 11-12)
- [ ] Gallery permission (Test 13)
- [ ] Compression (Test 14)
- [ ] Cache (Test 15)
- [ ] Firestore error (Test 16)
- [ ] Concurrent devices (Test 17)
- [ ] Storage cleanup (Test 18)
- [ ] Low memory (Test 19)
- [ ] Theme switching (Test 20)

**All tests should pass for production readiness!** ✅
