#!/usr/bin/env node

/**
 * SwargFood Task Management - Admin User Creation Script
 * Creates an admin user for the system with proper permissions
 */

const { PrismaClient } = require('@prisma/client');
const readline = require('readline');

const prisma = new PrismaClient();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function createAdminUser() {
  console.log('🔧 SwargFood Task Management - Admin User Setup');
  console.log('================================================\n');

  try {
    // Get admin user details
    const email = await question('Enter admin email address: ');
    const name = await question('Enter admin full name: ');
    const shortName = await question('Enter admin short name (optional): ');

    if (!email || !name) {
      console.log('❌ Email and name are required!');
      process.exit(1);
    }

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email }
    });

    if (existingUser) {
      console.log(`\n⚠️  User with email ${email} already exists.`);
      const updateExisting = await question('Do you want to update this user to admin? (y/N): ');
      
      if (updateExisting.toLowerCase() === 'y' || updateExisting.toLowerCase() === 'yes') {
        const updatedUser = await prisma.user.update({
          where: { email },
          data: {
            isAdmin: true,
            role: 'ADMIN',
            isActive: true,
            name: name,
            shortName: shortName || null,
            updatedAt: new Date()
          }
        });

        console.log('\n✅ User updated successfully!');
        console.log(`📧 Email: ${updatedUser.email}`);
        console.log(`👤 Name: ${updatedUser.name}`);
        console.log(`🔑 Admin: ${updatedUser.isAdmin}`);
        console.log(`📋 Role: ${updatedUser.role}`);
      } else {
        console.log('❌ Admin user creation cancelled.');
      }
    } else {
      // Create new admin user
      const newUser = await prisma.user.create({
        data: {
          email,
          name,
          shortName: shortName || null,
          isAdmin: true,
          role: 'ADMIN',
          isActive: true,
          lastLoginAt: new Date(),
          preferences: {
            theme: 'dark',
            notifications: true,
            language: 'en'
          }
        }
      });

      console.log('\n✅ Admin user created successfully!');
      console.log(`📧 Email: ${newUser.email}`);
      console.log(`👤 Name: ${newUser.name}`);
      console.log(`🔑 Admin: ${newUser.isAdmin}`);
      console.log(`📋 Role: ${newUser.role}`);
      console.log(`🆔 ID: ${newUser.id}`);
    }

    console.log('\n📝 Next Steps:');
    console.log('1. The admin user can now log in using Google OAuth');
    console.log('2. Make sure the Google OAuth is configured with the correct email domain');
    console.log('3. The admin will have full access to all system features');

  } catch (error) {
    console.error('❌ Error creating admin user:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
    rl.close();
  }
}

// Handle script execution
if (require.main === module) {
  createAdminUser();
}

module.exports = { createAdminUser };
