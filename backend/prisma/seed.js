const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  // Create demo user (Google OAuth style)
  const demoUser = await prisma.user.upsert({
    where: { email: 'demo@example.com' },
    update: {},
    create: {
      email: 'demo@example.com',
      name: 'Demo User',
      shortName: 'Demo',
      phone: '+1234567890',
      isAdmin: false,
      isActive: true,
      lastLoginAt: new Date(),
      preferences: {
        theme: 'light',
        notifications: true,
        language: 'en'
      }
    },
  });

  // Create admin user
  const adminUser = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {
      isAdmin: true,
      role: 'ADMIN',
      isActive: true
    },
    create: {
      email: 'admin@example.com',
      name: 'Admin User',
      shortName: 'Admin',
      isAdmin: true,
      role: 'ADMIN',
      isActive: true,
      lastLoginAt: new Date(),
      preferences: {
        theme: 'dark',
        notifications: true,
        language: 'en'
      }
    },
  });

  // Create SwargFood admin user (update with actual admin email)
  const swargfoodAdmin = await prisma.user.upsert({
    where: { email: 'mailcpk@gmail.com' },
    update: {
      isAdmin: true,
      role: 'ADMIN',
      isActive: true
    },
    create: {
      email: 'mailcpk@gmail.com',
      name: 'SwargFood Admin',
      shortName: 'Admin',
      isAdmin: true,
      role: 'ADMIN',
      isActive: true,
      lastLoginAt: new Date(),
      preferences: {
        theme: 'dark',
        notifications: true,
        language: 'en'
      }
    },
  });

  console.log('Demo user created:', demoUser);
  console.log('Admin user created:', adminUser);
  console.log('SwargFood admin created:', swargfoodAdmin);

  console.log('\n🔧 Admin Users Summary:');
  console.log(`📧 Generic Admin: ${adminUser.email} (${adminUser.role})`);
  console.log(`📧 SwargFood Admin: ${swargfoodAdmin.email} (${swargfoodAdmin.role})`);
  console.log('\n📝 Next Steps:');
  console.log('1. Update the SwargFood admin email in seed.js if needed');
  console.log('2. Configure Google OAuth with the admin email domain');
  console.log('3. Run: npm run admin:create to create additional admin users');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
