# Firestore Security Rules for Admin Panel

## Overview
This document provides recommended Firestore security rules to protect admin operations and ensure only authorized admin users can access sensitive data.

---

## Complete Firestore Rules

Below are the recommended security rules for your `firestore.rules` file. These rules ensure:
- Admin role verification for admin operations
- User can only access their own data
- Public data is readable by authenticated users
- Write operations are properly restricted

### firestore.rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper function to check if user is authenticated
    function isSignedIn() {
      return request.auth != null;
    }

    // Helper function to check if user is admin
    function isAdmin() {
      return isSignedIn() &&
             get(/databases/$(database)/documents/user_profiles/$(request.auth.uid)).data.role == 'admin';
    }

    // Helper function to check if user is accessing their own data
    function isOwner(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }

    // ==========================================
    // USER PROFILES
    // ==========================================
    match /user_profiles/{userId} {
      // Users can read their own profile
      // Admins can read all profiles
      allow read: if isOwner(userId) || isAdmin();

      // Users can create their own profile on signup
      allow create: if isSignedIn() &&
                      request.auth.uid == userId &&
                      request.resource.data.role == null; // Prevent self-promotion to admin

      // Users can update their own profile
      // Admins can update any profile
      allow update: if isOwner(userId) || isAdmin();

      // Only admins can delete profiles
      allow delete: if isAdmin();
    }

    // ==========================================
    // RACES
    // ==========================================
    match /races/{raceId} {
      // Anyone authenticated can read races
      allow read: if isSignedIn();

      // Users can create races (subject to subscription limits checked in app)
      allow create: if isSignedIn();

      // Race creator or admin can update
      allow update: if isSignedIn() &&
                      (resource.data.createdBy == request.auth.uid || isAdmin());

      // Only creator or admin can delete
      allow delete: if isSignedIn() &&
                      (resource.data.createdBy == request.auth.uid || isAdmin());
    }

    // ==========================================
    // RACE PARTICIPANTS
    // ==========================================
    match /race_participants/{raceId}/participants/{userId} {
      // Participants can read their own data
      // Admins can read all participant data
      // Race participants can see other participants
      allow read: if isSignedIn() &&
                    (isOwner(userId) || isAdmin());

      // Users can join races (create participant entry)
      allow create: if isSignedIn() && request.auth.uid == userId;

      // Participants can update their own data
      // Admins can update any participant data
      allow update: if isSignedIn() &&
                      (isOwner(userId) || isAdmin());

      // Participants can leave races (delete their entry)
      // Admins can remove participants
      allow delete: if isSignedIn() &&
                      (isOwner(userId) || isAdmin());
    }

    // ==========================================
    // USER RACES
    // ==========================================
    match /user_races/{userId}/races/{raceId} {
      // Users can read their own races
      // Admins can read all user races
      allow read: if isOwner(userId) || isAdmin();

      // Users can add races they join
      allow create: if isOwner(userId);

      // Users can update their race status
      // Admins can update any user's races
      allow update: if isOwner(userId) || isAdmin();

      // Users can delete their race entries
      // Admins can delete any user's races
      allow delete: if isOwner(userId) || isAdmin();
    }

    // ==========================================
    // LEADERBOARDS
    // ==========================================
    match /leaderboards/{seasonId} {
      // Everyone can read leaderboards
      allow read: if isSignedIn();

      // Only admins can create/update/delete leaderboards
      allow write: if isAdmin();
    }

    // ==========================================
    // MARATHONS
    // ==========================================
    match /marathons/{marathonId} {
      // Everyone can read marathons
      allow read: if isSignedIn();

      // Only admins can create/update/delete marathons
      allow create, update, delete: if isAdmin();
    }

    // ==========================================
    // SEASONS
    // ==========================================
    match /seasons/{seasonId} {
      // Everyone can read seasons
      allow read: if isSignedIn();

      // Only admins can manage seasons
      allow write: if isAdmin();
    }

    // ==========================================
    // NOTIFICATIONS
    // ==========================================
    match /notifications/{userId}/user_notifications/{notificationId} {
      // Users can read their own notifications
      // Admins can read all notifications
      allow read: if isOwner(userId) || isAdmin();

      // System and admins can create notifications
      allow create: if isAdmin();

      // Users can update (mark as read) their own notifications
      // Admins can update any notification
      allow update: if isOwner(userId) || isAdmin();

      // Users can delete their own notifications
      // Admins can delete any notification
      allow delete: if isOwner(userId) || isAdmin();
    }

    // ==========================================
    // RACE INVITES
    // ==========================================
    match /race_invites/{inviteId} {
      // Users can read invites sent to them
      // Admins can read all invites
      allow read: if isSignedIn() &&
                    (resource.data.invitedUserId == request.auth.uid ||
                     resource.data.inviterId == request.auth.uid ||
                     isAdmin());

      // Users can create invites
      allow create: if isSignedIn() &&
                      request.resource.data.inviterId == request.auth.uid;

      // Invited users can update (accept/decline)
      // Inviter can update
      // Admins can update
      allow update: if isSignedIn() &&
                      (resource.data.invitedUserId == request.auth.uid ||
                       resource.data.inviterId == request.auth.uid ||
                       isAdmin());

      // Inviter or admin can delete
      allow delete: if isSignedIn() &&
                      (resource.data.inviterId == request.auth.uid ||
                       isAdmin());
    }

    // ==========================================
    // SUBSCRIPTIONS (If implemented)
    // ==========================================
    match /subscriptions/{userId} {
      // Users can read their own subscription
      // Admins can read all subscriptions
      allow read: if isOwner(userId) || isAdmin();

      // System creates subscriptions
      // Admins can create subscriptions
      allow create: if isAdmin();

      // System updates subscriptions
      // Admins can update subscriptions
      allow update: if isAdmin();

      // Only admins can delete subscriptions
      allow delete: if isAdmin();
    }

    // ==========================================
    // ADMIN LOGS (Future Implementation)
    // ==========================================
    match /admin_logs/{logId} {
      // Only admins can read logs
      allow read: if isAdmin();

      // Only system can create logs (via Cloud Functions)
      allow create: if isAdmin();

      // No one can update or delete logs (immutable audit trail)
      allow update, delete: if false;
    }

    // ==========================================
    // SYSTEM SETTINGS (Future Implementation)
    // ==========================================
    match /system_settings/{settingId} {
      // Everyone can read public settings
      allow read: if isSignedIn();

      // Only admins can modify settings
      allow write: if isAdmin();
    }

    // ==========================================
    // DEFAULT DENY
    // ==========================================
    // Deny all other access by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## How to Apply These Rules

### Method 1: Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `stepzsync-750f9`
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the rules from above
5. Paste into the rules editor
6. Click **Publish**

### Method 2: Firebase CLI

1. Open `firestore.rules` file in your project root
2. Replace contents with the rules above
3. Deploy using Firebase CLI:
   ```bash
   firebase deploy --only firestore:rules
   ```

---

## Testing Security Rules

### Test Admin Access

```javascript
// Test if admin can read all user profiles
match /user_profiles/{userId} {
  // Simulate as admin user
  auth = {uid: "admin_uid"}
  path = /user_profiles/some_other_user_id

  // Should succeed
  allow read: if isAdmin()
}
```

### Test Regular User Access

```javascript
// Test if user can only read own profile
match /user_profiles/{userId} {
  // Simulate as regular user
  auth = {uid: "user123"}
  path = /user_profiles/user123

  // Should succeed
  allow read: if isOwner(userId)
}

// Try to read another user's profile
match /user_profiles/{userId} {
  // Simulate as regular user
  auth = {uid: "user123"}
  path = /user_profiles/user456

  // Should fail
  allow read: if isOwner(userId)
}
```

### Test Role Escalation Prevention

```javascript
// User tries to set themselves as admin
match /user_profiles/{userId} {
  auth = {uid: "user123"}
  request.resource.data.role = "admin"

  // Should fail - users can't self-promote
  allow create: if request.resource.data.role == null
}
```

---

## Security Best Practices

### 1. Admin Role Management
- **Never** allow users to set their own `role` field
- Admin role should only be set:
  - Manually via Firebase Console
  - Via Cloud Functions (server-side)
  - Via secure admin panel by existing admin

### 2. Data Validation
- Always validate data types and required fields
- Use `request.resource.data` to check incoming data
- Prevent null/empty values for critical fields

### 3. Audit Logging
- Log all admin operations to `admin_logs` collection
- Make audit logs immutable (no updates/deletes)
- Include timestamp, admin ID, action, and affected resources

### 4. Rate Limiting
- Implement rate limiting in Cloud Functions
- Prevent abuse of admin operations
- Monitor for suspicious activity

### 5. Testing
- Always test rules in Firebase Console simulator
- Test both success and failure cases
- Verify admin and non-admin scenarios

---

## Example Cloud Function for Admin Operations

For sensitive operations, implement Cloud Functions with admin verification:

```typescript
// Cloud Function example for setting admin role
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const setAdminRole = functions.https.onCall(async (data, context) => {
  // Verify caller is admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore()
    .collection('user_profiles')
    .doc(callerUid)
    .get();

  if (callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Must be admin');
  }

  // Set admin role for target user
  const targetUid = data.userId;
  await admin.firestore()
    .collection('user_profiles')
    .doc(targetUid)
    .update({
      role: 'admin',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

  // Log admin action
  await admin.firestore()
    .collection('admin_logs')
    .add({
      action: 'SET_ADMIN_ROLE',
      performedBy: callerUid,
      targetUser: targetUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

  return { success: true };
});
```

---

## Common Issues and Solutions

### Issue: Admin can't access data after role is set

**Solution:**
1. Verify role field is exactly `'admin'` (lowercase)
2. Check document path is `user_profiles/{uid}`
3. Sign out and sign in again to refresh auth token
4. Test rule in Firebase Console simulator

### Issue: Rules simulator shows "Simulated read denied"

**Solution:**
1. Verify you're testing with correct auth UID
2. Check the helper function `isAdmin()` logic
3. Ensure the test path matches your rules

### Issue: User can set their own admin role

**Solution:**
1. Review create rule for `user_profiles`
2. Ensure `request.resource.data.role == null` check exists
3. Never allow users to set role field directly

---

## Monitoring and Alerts

### Set up Firebase Alerts for:
1. Failed admin access attempts
2. Unauthorized write attempts
3. Unusual admin activity patterns
4. Mass data exports

### Monitor in Firebase Console:
- Navigate to **Firestore** → **Rules** → **Monitor**
- Check denied requests
- Identify potential security issues

---

**Last Updated:** January 2025
**Version:** 1.0.0
