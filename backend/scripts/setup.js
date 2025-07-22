#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function setup() {
  console.log('🚀 Task Management Tool - Backend Setup');
  console.log('=====================================\n');

  try {
    // Check if .env file exists
    const envPath = path.join(__dirname, '..', '.env');
    const envExamplePath = path.join(__dirname, '..', '.env.example');

    if (!fs.existsSync(envPath)) {
      console.log('📝 Creating .env file from template...');
      fs.copyFileSync(envExamplePath, envPath);
      console.log('✅ .env file created\n');
    } else {
      console.log('⚠️  .env file already exists\n');
    }

    // Database setup
    console.log('🗄️  Database Configuration');
    console.log('==========================');
    
    const dbUrl = await question('Enter your PostgreSQL database URL (or press Enter for default): ');
    if (dbUrl.trim()) {
      updateEnvFile(envPath, 'DATABASE_URL', `"${dbUrl}"`);
    }

    // JWT secrets
    console.log('\n🔐 Security Configuration');
    console.log('=========================');
    
    const generateSecret = () => require('crypto').randomBytes(32).toString('hex');
    
    const jwtSecret = await question('Enter JWT secret (or press Enter to generate): ');
    if (jwtSecret.trim()) {
      updateEnvFile(envPath, 'JWT_SECRET', `"${jwtSecret}"`);
    } else {
      updateEnvFile(envPath, 'JWT_SECRET', `"${generateSecret()}"`);
      console.log('✅ Generated JWT secret');
    }

    const refreshSecret = await question('Enter JWT refresh secret (or press Enter to generate): ');
    if (refreshSecret.trim()) {
      updateEnvFile(envPath, 'JWT_REFRESH_SECRET', `"${refreshSecret}"`);
    } else {
      updateEnvFile(envPath, 'JWT_REFRESH_SECRET', `"${generateSecret()}"`);
      console.log('✅ Generated JWT refresh secret');
    }

    // Google OAuth
    console.log('\n🔑 Google OAuth Configuration');
    console.log('=============================');
    
    const googleClientId = await question('Enter Google OAuth Client ID: ');
    if (googleClientId.trim()) {
      updateEnvFile(envPath, 'GOOGLE_CLIENT_ID', `"${googleClientId}"`);
    }

    const googleClientSecret = await question('Enter Google OAuth Client Secret: ');
    if (googleClientSecret.trim()) {
      updateEnvFile(envPath, 'GOOGLE_CLIENT_SECRET', `"${googleClientSecret}"`);
    }

    // Server configuration
    console.log('\n🌐 Server Configuration');
    console.log('=======================');
    
    const port = await question('Enter server port (default: 3000): ');
    if (port.trim()) {
      updateEnvFile(envPath, 'PORT', port);
    }

    const frontendUrl = await question('Enter frontend URL (default: http://localhost:3001): ');
    if (frontendUrl.trim()) {
      updateEnvFile(envPath, 'FRONTEND_URL', `"${frontendUrl}"`);
      updateEnvFile(envPath, 'CORS_ORIGIN', `"${frontendUrl}"`);
      updateEnvFile(envPath, 'SOCKET_CORS_ORIGIN', `"${frontendUrl}"`);
    }

    // Install dependencies
    console.log('\n📦 Installing dependencies...');
    execSync('npm install', { stdio: 'inherit' });
    console.log('✅ Dependencies installed');

    // Generate Prisma client
    console.log('\n🔧 Generating Prisma client...');
    execSync('npm run generate', { stdio: 'inherit' });
    console.log('✅ Prisma client generated');

    // Database migration
    console.log('\n🗄️  Setting up database...');
    const runMigration = await question('Do you want to run database migrations now? (y/N): ');
    
    if (runMigration.toLowerCase() === 'y' || runMigration.toLowerCase() === 'yes') {
      try {
        execSync('npm run migrate', { stdio: 'inherit' });
        console.log('✅ Database migrations completed');

        const seedDb = await question('Do you want to seed the database with sample data? (y/N): ');
        if (seedDb.toLowerCase() === 'y' || seedDb.toLowerCase() === 'yes') {
          execSync('npm run db:seed', { stdio: 'inherit' });
          console.log('✅ Database seeded with sample data');
        }
      } catch (error) {
        console.log('⚠️  Migration failed. You can run it manually later with: npm run migrate');
      }
    }

    // Create upload directory
    console.log('\n📁 Creating upload directory...');
    const uploadDir = path.join(__dirname, '..', 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
      fs.mkdirSync(path.join(uploadDir, 'tasks'), { recursive: true });
      fs.mkdirSync(path.join(uploadDir, 'chat'), { recursive: true });
      fs.mkdirSync(path.join(uploadDir, 'projects'), { recursive: true });
      console.log('✅ Upload directories created');
    } else {
      console.log('✅ Upload directory already exists');
    }

    // Create logs directory
    console.log('\n📋 Creating logs directory...');
    const logsDir = path.join(__dirname, '..', 'logs');
    if (!fs.existsSync(logsDir)) {
      fs.mkdirSync(logsDir, { recursive: true });
      console.log('✅ Logs directory created');
    } else {
      console.log('✅ Logs directory already exists');
    }

    console.log('\n🎉 Setup completed successfully!');
    console.log('\nNext steps:');
    console.log('1. Review and update the .env file with your specific configuration');
    console.log('2. Set up your PostgreSQL database');
    console.log('3. Configure Google OAuth in Google Cloud Console');
    console.log('4. Run "npm run dev" to start the development server');
    console.log('\nFor more information, check the README.md file.');

  } catch (error) {
    console.error('❌ Setup failed:', error.message);
    process.exit(1);
  } finally {
    rl.close();
  }
}

function updateEnvFile(envPath, key, value) {
  let envContent = fs.readFileSync(envPath, 'utf8');
  const regex = new RegExp(`^${key}=.*$`, 'm');
  
  if (regex.test(envContent)) {
    envContent = envContent.replace(regex, `${key}=${value}`);
  } else {
    envContent += `\n${key}=${value}`;
  }
  
  fs.writeFileSync(envPath, envContent);
}

// Run setup if this file is executed directly
if (require.main === module) {
  setup().catch(console.error);
}

module.exports = { setup };
