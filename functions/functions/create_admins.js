const admin = require('firebase-admin');

// Initialize with project ID
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'stepzsync-750f9',
    databaseURL: 'https://stepzsync-750f9-default-rtdb.asia-southeast1.firebasedatabase.app'
  });
}

const adminAccounts = [
  // Rupesh Accounts
  { email: 'rupesh.admin1@stepzsync.com', password: 'Rupesh@Admin2025#1', name: 'Rupesh Admin 1', controller: 'rupesh' },
  { email: 'rupesh.admin2@stepzsync.com', password: 'Rupesh@Admin2025#2', name: 'Rupesh Admin 2', controller: 'rupesh' },
  { email: 'rupesh.admin3@stepzsync.com', password: 'Rupesh@Admin2025#3', name: 'Rupesh Admin 3', controller: 'rupesh' },
  { email: 'rupesh.admin4@stepzsync.com', password: 'Rupesh@Admin2025#4', name: 'Rupesh Admin 4', controller: 'rupesh' },
  { email: 'rupesh.admin5@stepzsync.com', password: 'Rupesh@Admin2025#5', name: 'Rupesh Admin 5', controller: 'rupesh' },

  // Nishant Accounts
  { email: 'nishant.admin1@stepzsync.com', password: 'Nishant@Admin2025#1', name: 'Nishant Admin 1', controller: 'nishant' },
  { email: 'nishant.admin2@stepzsync.com', password: 'Nishant@Admin2025#2', name: 'Nishant Admin 2', controller: 'nishant' },
  { email: 'nishant.admin3@stepzsync.com', password: 'Nishant@Admin2025#3', name: 'Nishant Admin 3', controller: 'nishant' },
  { email: 'nishant.admin4@stepzsync.com', password: 'Nishant@Admin2025#4', name: 'Nishant Admin 4', controller: 'nishant' },
  { email: 'nishant.admin5@stepzsync.com', password: 'Nishant@Admin2025#5', name: 'Nishant Admin 5', controller: 'nishant' },
];

async function createAdmins() {
  console.log('Creating admin accounts...\n');

  for (const account of adminAccounts) {
    try {
      const userRecord = await admin.auth().createUser({
        email: account.email,
        password: account.password,
        displayName: account.name,
        emailVerified: true
      });

      await admin.firestore().collection('admins').doc(userRecord.uid).set({
        email: account.email,
        displayName: account.name,
        controller: account.controller,
        role: 'super_admin',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
        permissions: {
          manageUsers: true,
          manageRaces: true,
          viewAnalytics: true,
          manageAdmins: account.controller === 'rupesh',
          systemSettings: account.controller === 'rupesh'
        }
      });

      console.log(`✅ Created: ${account.name} (${account.email})`);
    } catch (error) {
      if (error.code === 'auth/email-already-exists') {
        console.log(`⚠️  Already exists: ${account.email}`);
      } else {
        console.error(`❌ Error creating ${account.email}:`, error.message);
      }
    }
  }

  console.log('\n✅ Done!');
}

createAdmins().then(() => process.exit(0)).catch(err => {
  console.error(err);
  process.exit(1);
});
