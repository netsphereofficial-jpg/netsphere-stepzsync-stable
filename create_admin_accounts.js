const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://stepzsync-750f9-default-rtdb.asia-southeast1.firebasedatabase.app"
});

const db = admin.firestore();
const auth = admin.auth();

// Admin accounts configuration
const adminAccounts = {
  super_controller_rupesh: [
    {
      email: 'rupesh.admin1@stepzsync.com',
      password: 'Rupesh@Admin2025#1',
      displayName: 'Rupesh Admin 1',
      role: 'super_admin',
      controller: 'rupesh'
    },
    {
      email: 'rupesh.admin2@stepzsync.com',
      password: 'Rupesh@Admin2025#2',
      displayName: 'Rupesh Admin 2',
      role: 'super_admin',
      controller: 'rupesh'
    },
    {
      email: 'rupesh.admin3@stepzsync.com',
      password: 'Rupesh@Admin2025#3',
      displayName: 'Rupesh Admin 3',
      role: 'super_admin',
      controller: 'rupesh'
    },
    {
      email: 'rupesh.admin4@stepzsync.com',
      password: 'Rupesh@Admin2025#4',
      displayName: 'Rupesh Admin 4',
      role: 'super_admin',
      controller: 'rupesh'
    },
    {
      email: 'rupesh.admin5@stepzsync.com',
      password: 'Rupesh@Admin2025#5',
      displayName: 'Rupesh Admin 5',
      role: 'super_admin',
      controller: 'rupesh'
    }
  ],
  super_controller_nishant: [
    {
      email: 'nishant.admin1@stepzsync.com',
      password: 'Nishant@Admin2025#1',
      displayName: 'Nishant Admin 1',
      role: 'super_admin',
      controller: 'nishant'
    },
    {
      email: 'nishant.admin2@stepzsync.com',
      password: 'Nishant@Admin2025#2',
      displayName: 'Nishant Admin 2',
      role: 'super_admin',
      controller: 'nishant'
    },
    {
      email: 'nishant.admin3@stepzsync.com',
      password: 'Nishant@Admin2025#3',
      displayName: 'Nishant Admin 3',
      role: 'super_admin',
      controller: 'nishant'
    },
    {
      email: 'nishant.admin4@stepzsync.com',
      password: 'Nishant@Admin2025#4',
      displayName: 'Nishant Admin 4',
      role: 'super_admin',
      controller: 'nishant'
    },
    {
      email: 'nishant.admin5@stepzsync.com',
      password: 'Nishant@Admin2025#5',
      displayName: 'Nishant Admin 5',
      role: 'super_admin',
      controller: 'nishant'
    }
  ]
};

async function createAdminAccounts() {
  console.log('🚀 Starting admin account creation...\n');

  const createdAccounts = [];

  for (const [controller, accounts] of Object.entries(adminAccounts)) {
    console.log(`\n📋 Creating accounts for: ${controller}`);
    console.log('='.repeat(60));

    for (const account of accounts) {
      try {
        // Create Firebase Auth user
        const userRecord = await auth.createUser({
          email: account.email,
          password: account.password,
          displayName: account.displayName,
          emailVerified: true
        });

        // Create admin profile in Firestore
        await db.collection('admins').doc(userRecord.uid).set({
          email: account.email,
          displayName: account.displayName,
          role: account.role,
          controller: account.controller,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isActive: true,
          permissions: {
            manageUsers: true,
            manageRaces: true,
            viewAnalytics: true,
            manageAdmins: controller === 'rupesh', // Only Rupesh can manage admins
            systemSettings: controller === 'rupesh' // Only Rupesh has system settings
          }
        });

        console.log(`✅ Created: ${account.displayName}`);
        console.log(`   Email: ${account.email}`);
        console.log(`   Password: ${account.password}`);
        console.log(`   UID: ${userRecord.uid}\n`);

        createdAccounts.push({
          email: account.email,
          password: account.password,
          displayName: account.displayName,
          controller: account.controller
        });

      } catch (error) {
        if (error.code === 'auth/email-already-exists') {
          console.log(`⚠️  Account already exists: ${account.email}`);
        } else {
          console.error(`❌ Error creating ${account.email}:`, error.message);
        }
      }
    }
  }

  // Generate summary document
  console.log('\n' + '='.repeat(60));
  console.log('📊 ADMIN CREDENTIALS SUMMARY');
  console.log('='.repeat(60));
  console.log('\n🔐 SUPER CONTROLLER RUPESH:');
  console.log('-'.repeat(60));
  createdAccounts
    .filter(acc => acc.controller === 'rupesh')
    .forEach((acc, index) => {
      console.log(`${index + 1}. ${acc.displayName}`);
      console.log(`   Email: ${acc.email}`);
      console.log(`   Password: ${acc.password}\n`);
    });

  console.log('\n🔐 SUPER CONTROLLER NISHANT:');
  console.log('-'.repeat(60));
  createdAccounts
    .filter(acc => acc.controller === 'nishant')
    .forEach((acc, index) => {
      console.log(`${index + 1}. ${acc.displayName}`);
      console.log(`   Email: ${acc.email}`);
      console.log(`   Password: ${acc.password}\n`);
    });

  console.log('='.repeat(60));
  console.log('✅ Admin account creation complete!');
  console.log(`Total accounts created: ${createdAccounts.length}`);
  console.log('\n⚠️  IMPORTANT: Save these credentials securely!');
  console.log('='.repeat(60));

  process.exit(0);
}

// Run the script
createAdminAccounts().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
