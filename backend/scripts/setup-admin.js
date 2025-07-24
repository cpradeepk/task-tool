#!/usr/bin/env node

/**
 * SwargFood Task Management - Complete Admin Setup Script
 * Sets up the database, creates admin users, and configures the system
 */

const { PrismaClient } = require('@prisma/client');
const { execSync } = require('child_process');
const readline = require('readline');
const fs = require('fs');
const path = require('path');

const prisma = new PrismaClient();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function checkDatabaseConnection() {
  try {
    await prisma.$connect();
    console.log('✅ Database connection successful');
    return true;
  } catch (error) {
    console.log('❌ Database connection failed:', error.message);
    return false;
  }
}

async function runMigrations() {
  try {
    console.log('🔄 Running database migrations...');
    execSync('npx prisma migrate deploy', { stdio: 'inherit' });
    console.log('✅ Database migrations completed');
    return true;
  } catch (error) {
    console.log('❌ Migration failed:', error.message);
    return false;
  }
}

async function seedDatabase() {
  try {
    console.log('🌱 Seeding database with initial data...');
    execSync('npm run db:seed', { stdio: 'inherit' });
    console.log('✅ Database seeding completed');
    return true;
  } catch (error) {
    console.log('❌ Database seeding failed:', error.message);
    return false;
  }
}

async function createCustomAdminUser() {
  console.log('\n👤 Create Additional Admin User');
  console.log('================================');

  const email = await question('Enter admin email address: ');
  const name = await question('Enter admin full name: ');
  const shortName = await question('Enter admin short name (optional): ');

  if (!email || !name) {
    console.log('❌ Email and name are required!');
    return false;
  }

  try {
    const adminUser = await prisma.user.upsert({
      where: { email },
      update: {
        isAdmin: true,
        role: 'ADMIN',
        isActive: true,
        name: name,
        shortName: shortName || null,
        updatedAt: new Date()
      },
      create: {
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

    console.log('✅ Admin user created/updated successfully!');
    console.log(`📧 Email: ${adminUser.email}`);
    console.log(`👤 Name: ${adminUser.name}`);
    console.log(`🔑 Admin: ${adminUser.isAdmin}`);
    console.log(`📋 Role: ${adminUser.role}`);
    return true;
  } catch (error) {
    console.log('❌ Error creating admin user:', error.message);
    return false;
  }
}

async function verifyAdminUsers() {
  try {
    const adminUsers = await prisma.user.findMany({
      where: { isAdmin: true },
      select: { id: true, email: true, name: true, role: true, isActive: true }
    });

    console.log('\n📋 Current Admin Users:');
    console.log('=======================');
    
    if (adminUsers.length === 0) {
      console.log('❌ No admin users found!');
      return false;
    }

    adminUsers.forEach((user, index) => {
      console.log(`${index + 1}. ${user.name} (${user.email})`);
      console.log(`   Role: ${user.role}, Active: ${user.isActive}`);
    });

    return true;
  } catch (error) {
    console.log('❌ Error verifying admin users:', error.message);
    return false;
  }
}

async function checkEnvironmentConfig() {
  const envPath = path.join(__dirname, '../.env');
  
  if (!fs.existsSync(envPath)) {
    console.log('⚠️  .env file not found. Creating from template...');
    const examplePath = path.join(__dirname, '../.env.example');
    if (fs.existsSync(examplePath)) {
      fs.copyFileSync(examplePath, envPath);
      console.log('✅ .env file created from .env.example');
      console.log('📝 Please update the Google OAuth credentials in .env file');
    } else {
      console.log('❌ .env.example file not found');
      return false;
    }
  } else {
    console.log('✅ .env file exists');
  }

  // Check for required environment variables
  require('dotenv').config({ path: envPath });
  
  const requiredVars = ['DATABASE_URL', 'JWT_SECRET', 'GOOGLE_CLIENT_ID'];
  const missingVars = requiredVars.filter(varName => !process.env[varName] || process.env[varName].includes('your-'));
  
  if (missingVars.length > 0) {
    console.log('⚠️  Missing or placeholder environment variables:');
    missingVars.forEach(varName => console.log(`   - ${varName}`));
    console.log('📝 Please update these in your .env file');
    return false;
  }

  console.log('✅ Environment configuration looks good');
  return true;
}

async function main() {
  console.log('🚀 SwargFood Task Management - Complete Admin Setup');
  console.log('===================================================\n');

  try {
    // Step 1: Check environment configuration
    console.log('Step 1: Checking environment configuration...');
    await checkEnvironmentConfig();

    // Step 2: Check database connection
    console.log('\nStep 2: Checking database connection...');
    const dbConnected = await checkDatabaseConnection();
    if (!dbConnected) {
      console.log('❌ Please check your database configuration and try again.');
      process.exit(1);
    }

    // Step 3: Run migrations
    console.log('\nStep 3: Setting up database schema...');
    const migrationsSuccess = await runMigrations();
    if (!migrationsSuccess) {
      console.log('❌ Database migration failed. Please check the error and try again.');
      process.exit(1);
    }

    // Step 4: Seed database
    console.log('\nStep 4: Seeding database with initial data...');
    const seedSuccess = await seedDatabase();
    if (!seedSuccess) {
      console.log('⚠️  Database seeding failed, but continuing...');
    }

    // Step 5: Create additional admin user
    console.log('\nStep 5: Admin user setup...');
    const createCustom = await question('Do you want to create an additional admin user? (y/N): ');
    if (createCustom.toLowerCase() === 'y' || createCustom.toLowerCase() === 'yes') {
      await createCustomAdminUser();
    }

    // Step 6: Verify admin users
    console.log('\nStep 6: Verifying admin users...');
    await verifyAdminUsers();

    // Final instructions
    console.log('\n🎉 Setup completed successfully!');
    console.log('\n📝 Next Steps:');
    console.log('1. Update Google OAuth credentials in .env file');
    console.log('2. Configure Google Cloud Console with correct redirect URIs');
    console.log('3. Test the authentication flow');
    console.log('4. Deploy the updated configuration');

  } catch (error) {
    console.error('❌ Setup failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
    rl.close();
  }
}

// Handle script execution
if (require.main === module) {
  main();
}

module.exports = { main };
