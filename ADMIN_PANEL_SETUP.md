# StepzSync Admin Panel - Setup Guide

## Overview
The StepzSync Admin Panel is a **completely separate Flutter web application** that runs independently from the main mobile app. It provides a clean, professional interface for managing your application.

---

## ✨ Features

### Current Implementation
- ✅ **Standalone Web App** - Separate entry point (`admin_main.dart`)
- ✅ **Beautiful Login Screen** - Professional gradient design
- ✅ **Modern Dashboard** - Sidebar navigation with clean layout
- ✅ **Admin Role Verification** - Firestore-based role checking
- ✅ **Secure Authentication** - Firebase Authentication
- ✅ **Responsive Design** - Professional UI with Material Design 3

### Coming Soon
- 🚧 User Management
- 🚧 Race Management
- 🚧 Analytics Dashboard
- 🚧 Settings & Configuration

---

## 🚀 Running the Admin Panel

### Method 1: Run Admin Panel Directly (Recommended)

```bash
# Navigate to project directory
cd /Users/nikhil/StudioProjects/stepzsync_latest

# Run admin panel on web
flutter run -t lib/admin_main.dart -d chrome
```

This will:
- Start the admin panel as a completely separate app
- Open in Chrome browser
- No interference with the main mobile app

### Method 2: Build for Production

```bash
# Build admin panel for deployment
flutter build web -t lib/admin_main.dart --web-renderer html

# Deploy to Firebase Hosting (optional)
firebase deploy --only hosting
```

---

## 🔐 Admin Account Setup

### Step 1: Create Firebase Auth Account

1. **Open Firebase Console:**
   - Go to: https://console.firebase.google.com/
   - Select project: `stepzsync-750f9`

2. **Create Admin User:**
   - Navigate to **Authentication** → **Users**
   - Click **Add User**
   - Email: `admin@stepzsync.com` (or your preferred email)
   - Password: Choose a secure password
   - Click **Add User**
   - **Copy the UID** of the created user

### Step 2: Set Admin Role in Firestore

1. **Open Firestore Database:**
   - In Firebase Console, go to **Firestore Database**

2. **Create/Update User Profile:**
   - Find collection: `user_profiles`
   - Create or edit document with ID = **your user's UID**
   - Add the following fields:

```json
{
  "email": "admin@stepzsync.com",
  "fullName": "Admin User",
  "role": "admin",              ← IMPORTANT: This field makes the user an admin
  "profileCompleted": true,
  "createdAt": (current timestamp),
  "updatedAt": (current timestamp)
}
```

### Step 3: Sign In

1. Run the admin panel:
   ```bash
   flutter run -t lib/admin_main.dart -d chrome
   ```

2. Navigate to the login screen (opens automatically)

3. Enter your admin credentials:
   - Email: `admin@stepzsync.com`
   - Password: (the password you set)

4. Click **Sign In**

5. You should see the admin dashboard! 🎉

---

## 📁 Project Structure

```
lib/
├── admin_main.dart                          ← Admin panel entry point
├── main.dart                                ← Main mobile app entry point
├── screens/admin/
│   ├── simple_admin_login.dart             ← Admin login screen
│   └── admin_dashboard_screen.dart         ← Admin dashboard
├── services/admin/
│   └── admin_auth_service.dart             ← Admin role verification
└── ...
```

---

## 🎨 UI Components

### Login Screen
- Gradient background with brand colors
- Clean card-based form
- Email/password fields
- Loading states
- Error handling

### Dashboard
- **Sidebar Navigation:**
  - Dashboard
  - Users (Coming Soon)
  - Races (Coming Soon)
  - Analytics (Coming Soon)
  - Settings (Coming Soon)
  - Logout button

- **Top Bar:**
  - Page title
  - Admin info badge with avatar

- **Main Content:**
  - Welcome banner
  - Feature cards
  - Grid layout

---

## 🔒 Security

### Admin Role Verification
The admin panel automatically:
1. Checks if user is authenticated
2. Verifies user has `role: 'admin'` in Firestore
3. Redirects non-admin users with error message
4. Signs out unauthorized users

### Firebase Security Rules
Add these rules to `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper function to check if user is admin
    function isAdmin() {
      return request.auth != null &&
             get(/databases/$(database)/documents/user_profiles/$(request.auth.uid)).data.role == 'admin';
    }

    // User profiles - admins can read all
    match /user_profiles/{userId} {
      allow read: if request.auth.uid == userId || isAdmin();
      allow write: if request.auth.uid == userId || isAdmin();
    }

    // Add more admin-protected collections as needed
  }
}
```

---

## 🛠️ Development Workflow

### 1. Running Both Apps Simultaneously

**Terminal 1 - Main App:**
```bash
flutter run -d chrome
# or
flutter run -d ios
```

**Terminal 2 - Admin Panel:**
```bash
flutter run -t lib/admin_main.dart -d chrome
```

Both apps can run at the same time without conflicts!

### 2. Hot Reload
Works normally with both apps:
- Press `r` to hot reload
- Press `R` to hot restart
- Press `q` to quit

### 3. Adding New Admin Features

To add a new admin feature (e.g., User Management):

1. **Create the screen:**
   ```dart
   // lib/screens/admin/user_management_screen.dart
   class UserManagementScreen extends StatelessWidget {
     // ...
   }
   ```

2. **Add route in admin_main.dart:**
   ```dart
   GetPage(
     name: '/admin-users',
     page: () => const UserManagementScreen(),
   ),
   ```

3. **Update dashboard navigation:**
   - Remove `badge: 'Soon'` from the Users menu item
   - Add navigation to the new screen

---

## 🐛 Troubleshooting

### Issue: "Access Denied" after login

**Solution:**
1. Verify in Firestore that your user document has:
   - Field name: `role` (lowercase)
   - Field value: `admin` (lowercase)
   - Document ID matches your Firebase Auth UID

2. Sign out and sign in again

### Issue: Can't find admin_main.dart

**Solution:**
Make sure you're in the correct directory:
```bash
pwd
# Should show: /Users/nikhil/StudioProjects/stepzsync_latest

ls lib/admin_main.dart
# Should exist
```

### Issue: Firebase not initialized

**Solution:**
The admin panel initializes Firebase automatically. If you see errors:
1. Check `firebase_options.dart` exists
2. Verify Firebase project settings
3. Run `flutter pub get`

### Issue: White screen after login

**Solution:**
1. Check browser console for errors
2. Verify admin role is set correctly in Firestore
3. Try hard refresh (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows)

---

## 📊 Admin Panel vs Main App

| Feature | Main App | Admin Panel |
|---------|----------|-------------|
| Entry Point | `lib/main.dart` | `lib/admin_main.dart` |
| Target Platform | Mobile (iOS/Android) | Web Only |
| Authentication | Email/Phone/Guest | Email Only |
| Role Check | No | Yes (Admin role required) |
| UI Design | Mobile-optimized | Desktop web layout |
| Navigation | Bottom nav + tabs | Sidebar navigation |
| Purpose | User-facing features | Administration |

---

## 🚀 Next Steps

### Phase 1: User Management (Recommended First Feature)
- [ ] View all users
- [ ] Search and filter users
- [ ] View user details
- [ ] Manage user roles
- [ ] Suspend/delete users

### Phase 2: Race Management
- [ ] View all races (active, scheduled, completed)
- [ ] Create new races
- [ ] Monitor live races
- [ ] Cancel/pause races
- [ ] Race analytics

### Phase 3: Analytics Dashboard
- [ ] User growth charts
- [ ] Engagement metrics
- [ ] Race statistics
- [ ] Revenue tracking (if applicable)

### Phase 4: Advanced Features
- [ ] System logs viewer
- [ ] Notification management
- [ ] Content moderation
- [ ] App settings configuration

---

## 📝 Quick Reference

### Run Admin Panel
```bash
flutter run -t lib/admin_main.dart -d chrome
```

### Build for Production
```bash
flutter build web -t lib/admin_main.dart
```

### Default Admin Credentials
```
Email: admin@stepzsync.com
Password: (set during Firebase Auth account creation)
```

### Required Firestore Field
```json
{
  "role": "admin"
}
```

---

## 📞 Support

If you encounter issues:
1. Check this documentation
2. Verify Firebase Console settings
3. Check browser developer console for errors
4. Review Firestore security rules

---

**Last Updated:** January 2025
**Admin Panel Version:** 1.0.0
**Main App Independence:** ✅ Fully Separate
