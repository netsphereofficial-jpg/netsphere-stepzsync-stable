# StepzSync Admin Panel - Access Guide

## Overview
This document provides instructions for accessing and managing the StepzSync admin panel.

## Admin Panel Features

### Current Implementation ✅
- **Web-Only Access**: Admin panel is exclusively available on web platform
- **Secure Authentication**: Firebase Authentication with admin role verification
- **Role-Based Access**: Users must have 'admin' role in Firestore to access
- **Dashboard Layout**: Professional sidebar navigation with blank dashboard ready for expansion
- **Design System**: Uses app's existing design system for consistent UI/UX

### Planned Features 🚧
- User Management
- Race Management
- Analytics & Reports
- Settings & Configuration

---

## Accessing the Admin Panel

### Prerequisites
1. Admin account created in Firebase Authentication
2. Admin role set in Firestore user document
3. Web browser (admin panel is web-only)

### Access URL
When running locally:
```
http://localhost:[PORT]/#/admin-login
```

When deployed:
```
https://your-domain.com/#/admin-login
```

---

## Creating Admin Accounts

### Step 1: Create Firebase Auth Account

You can create admin accounts in two ways:

#### Option A: Using Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `stepzsync-750f9`
3. Navigate to **Authentication** → **Users**
4. Click **Add User**
5. Enter admin email and password
6. Note the UID of the created user

#### Option B: Using the App (Recommended)
1. Run the app: `flutter run -d chrome`
2. Use Flutter DevTools or add temporary code to create admin account programmatically

### Step 2: Set Admin Role in Firestore

You need to add the `role: 'admin'` field to the user's Firestore document.

#### Method 1: Using Firebase Console (Manual)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `stepzsync-750f9`
3. Navigate to **Firestore Database**
4. Open collection: `user_profiles`
5. Find the document with the user's UID
6. Click **Edit** and add field:
   - Field: `role`
   - Type: `string`
   - Value: `admin`
7. Save the document

#### Method 2: Using AdminAuthService (Programmatic)

Add this temporary code in your app (e.g., in a button callback):

```dart
import 'package:stepzsync/services/admin/admin_auth_service.dart';

// Replace with actual user UID
String userUid = 'YOUR_USER_UID_HERE';

// Set admin role
bool success = await AdminAuthService.setAdminRole(userUid);

if (success) {
  print('✅ Admin role set successfully');
} else {
  print('❌ Failed to set admin role');
}
```

**Important:** Remove this code after setting up your admin accounts to prevent unauthorized access.

---

## Default Admin Credentials

### Generated Admin Account

**Email:** `admin@stepzsync.com`
**Password:** *(Generated during setup - Check console output or set manually)*

**Note:** You'll need to manually set this up following the steps above.

---

## Admin Panel Structure

### Navigation
```
├── Dashboard (Home)
│   ├── Welcome card
│   ├── Quick stats (Coming Soon)
│   └── Recent activity (Coming Soon)
│
├── Users (Coming Soon)
│   ├── User list
│   ├── User details
│   └── Role management
│
├── Races (Coming Soon)
│   ├── Active races
│   ├── Race history
│   └── Race analytics
│
├── Analytics (Coming Soon)
│   ├── User metrics
│   ├── Race statistics
│   └── Engagement reports
│
└── Settings (Coming Soon)
    ├── System settings
    ├── Admin management
    └── App configuration
```

---

## Security Features

### 1. Platform Restriction
- Admin panel **only works on web**
- Mobile app users are automatically redirected

### 2. Authentication Guards
- Firebase Authentication required
- Admin role verification on every page load
- Automatic redirect on unauthorized access

### 3. Role Verification
- Firestore-based role checking
- Real-time admin status validation
- Automatic sign-out for non-admin users

### 4. Middleware Protection
- GetX middleware on all admin routes
- Pre-route authentication checks
- Session management

---

## Troubleshooting

### "Access Denied" Error
**Problem:** User is authenticated but sees "Access Denied" message

**Solutions:**
1. Verify the user has `role: 'admin'` in Firestore `user_profiles/{uid}` document
2. Check the role field is exactly `'admin'` (case-sensitive)
3. Sign out and sign in again to refresh authentication state

### Can't Access on Mobile
**Problem:** Trying to access admin panel on mobile app

**Solution:** Admin panel is web-only by design. Use a web browser to access at:
- Development: `http://localhost:PORT/#/admin-login`
- Production: `https://your-domain.com/#/admin-login`

### Firebase Auth Errors
**Problem:** Firebase authentication errors during login

**Solutions:**
1. Verify email/password are correct
2. Check Firebase project is `stepzsync-750f9`
3. Ensure Firebase is initialized in the app
4. Check Firebase Console for user account status

### Role Not Being Recognized
**Problem:** Admin role set but still can't access

**Solutions:**
1. Verify Firestore document path: `user_profiles/{uid}`
2. Check field name is exactly `role` (lowercase)
3. Verify value is exactly `'admin'` (lowercase)
4. Clear browser cache and sign in again
5. Check Firestore security rules allow reading the role field

---

## Development Workflow

### Running Admin Panel Locally

1. **Start the app in web mode:**
   ```bash
   cd /Users/nikhil/StudioProjects/stepzsync_latest
   flutter run -d chrome
   ```

2. **Navigate to admin login:**
   - Open browser to: `http://localhost:[PORT]/#/admin-login`
   - Or manually navigate using the URL bar

3. **Sign in with admin credentials**

### Building for Production

```bash
# Build web version
flutter build web

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

---

## Firebase Firestore Structure

### User Profile Document
```
Collection: user_profiles
Document ID: {user_uid}

Fields:
{
  "email": "admin@stepzsync.com",
  "fullName": "Admin User",
  "role": "admin",              ← Admin role field
  "profileCompleted": true,
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  // ... other profile fields
}
```

---

## Security Rules Recommendations

See `FIRESTORE_SECURITY_RULES.md` for complete Firestore security rules that protect admin operations.

Key rules:
- Only admins can read/write admin-specific collections
- Role verification on all admin operations
- Audit logging for admin actions

---

## Next Steps for Development

### Phase 1: Core Admin Features
- [ ] User management interface
- [ ] User search and filtering
- [ ] User role management
- [ ] User statistics

### Phase 2: Race Management
- [ ] View all races (active, scheduled, completed)
- [ ] Create/edit/delete races
- [ ] Monitor live races
- [ ] Race analytics

### Phase 3: Analytics Dashboard
- [ ] User growth metrics
- [ ] Engagement statistics
- [ ] Race completion rates
- [ ] Revenue analytics (if applicable)

### Phase 4: Advanced Features
- [ ] System logs viewer
- [ ] Notification management
- [ ] Content moderation
- [ ] Settings configuration

---

## Support & Contact

For issues with admin panel access or setup:
1. Check this documentation first
2. Review Firebase Console for authentication/Firestore issues
3. Check application logs for error messages

---

## Change Log

### Version 1.0.0 (Current)
- ✅ Basic admin authentication
- ✅ Web-only routing with platform checks
- ✅ Admin role verification
- ✅ Blank dashboard with sidebar navigation
- ✅ Login screen with design system
- ✅ Logout functionality

### Upcoming
- User management features
- Race management features
- Analytics and reporting

---

**Last Updated:** January 2025
**Admin Panel Version:** 1.0.0
