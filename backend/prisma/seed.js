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
    update: {},
    create: {
      email: 'admin@example.com',
      name: 'Admin User',
      shortName: 'Admin',
      isAdmin: true,
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
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
