# Creating Admin Accounts - Instructions

Since we can't create accounts programmatically without service account credentials, here are the **manual steps** to create the admin accounts:

## Option 1: Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com/project/stepzsync-750f9/authentication/users)
2. Click **"Add user"**
3. Enter the details from the table below
4. Click **"Add user"**

### Admin Accounts to Create:

#### RUPESH's Team:
| Email | Password |
|-------|----------|
| rupesh.admin1@stepzsync.com | Rupesh@Admin2025#1 |
| rupesh.admin2@stepzsync.com | Rupesh@Admin2025#2 |
| rupesh.admin3@stepzsync.com | Rupesh@Admin2025#3 |
| rupesh.admin4@stepzsync.com | Rupesh@Admin2025#4 |
| rupesh.admin5@stepzsync.com | Rupesh@Admin2025#5 |

#### NISHANT's Team:
| Email | Password |
|-------|----------|
| nishant.admin1@stepzsync.com | Nishant@Admin2025#1 |
| nishant.admin2@stepzsync.com | Nishant@Admin2025#2 |
| nishant.admin3@stepzsync.com | Nishant@Admin2025#3 |
| nishant.admin4@stepzsync.com | Nishant@Admin2025#4 |
| nishant.admin5@stepzsync.com | Nishant@Admin2025#5 |

---

## Option 2: Use My Script (Requires Service Account Key)

If you have a Firebase service account key:

1. Download your service account key from Firebase Console:
   - Go to Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save as `serviceAccountKey.json` in project root

2. Run the script:
   ```bash
   cd functions/functions
   node create_admins.js
   ```

---

## ✅ After Creating Accounts

Once accounts are created in Firebase Authentication, you can **login immediately** at:

**https://stepzsync-750f9.web.app**

Use any of the emails and passwords from the tables above!

---

## 📋 Summary

- **Total Accounts**: 10 (5 for Rupesh, 5 for Nishant)
- **All emails end with**: `@stepzsync.com`
- **Password Pattern**: `Name@Admin2025#Number`
- **Admin Panel URL**: https://stepzsync-750f9.web.app

The admin panel is ready - just create these accounts in Firebase Console and start using them!
