# Admin Panel - Quick Start Guide

## 🚀 3-Step Setup

### Step 1: Create Admin Account in Firebase
1. Go to https://console.firebase.google.com/
2. Select project: **stepzsync-750f9**
3. Navigate to **Authentication** → **Users**
4. Click **Add User**
5. Enter:
   - Email: `admin@stepzsync.com`
   - Password: `Admin@123` (or your preferred secure password)
6. Click **Add User**

### Step 2: Run Admin Panel
```bash
flutter run -t lib/admin_main.dart -d chrome
```

### Step 3: Login
1. Enter the credentials you created
2. Click **Sign In**
3. **The admin profile will be automatically created!**

---

## ✅ What Happens Automatically

When you log in for the first time:
- ✅ Admin profile is created in Firestore
- ✅ `role: 'admin'` field is set automatically
- ✅ You're redirected to the dashboard
- ✅ Full admin access granted

---

## 🎯 That's It!

No manual Firestore setup needed. Just:
1. Create Firebase Auth user
2. Run admin panel
3. Login

The system handles everything else automatically!

---

## 🐛 Troubleshooting

### "Access Denied" message
**Solution:** Refresh the page after login (Cmd+R or Ctrl+R)

### "User not found"
**Solution:** Double-check the email in Firebase Authentication console

### White screen
**Solution:** Check browser console for errors, verify Firebase is initialized

---

## 📝 Default Credentials (if you used suggestion)
```
Email: admin@stepzsync.com
Password: Admin@123
```

Change the password after first login for security!

---

**Need help?** Check `ADMIN_PANEL_SETUP.md` for detailed documentation.
