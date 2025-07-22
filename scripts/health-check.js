#!/usr/bin/env node

/**
 * Health Check Script for Task Management Tool
 * This script checks the health of all application components
 */

const http = require('http');
const https = require('https');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const config = {
  backend: {
    host: process.env.BACKEND_HOST || 'localhost',
    port: process.env.BACKEND_PORT || 3000,
    protocol: process.env.BACKEND_PROTOCOL || 'http'
  },
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    name: process.env.DB_NAME || 'taskmanagement'
  },
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
  }
};

// Colors for output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

function colorize(text, color) {
  return `${colors[color]}${text}${colors.reset}`;
}

function log(message, color = 'reset') {
  console.log(colorize(message, color));
}

function logSuccess(message) {
  log(`✅ ${message}`, 'green');
}

function logError(message) {
  log(`❌ ${message}`, 'red');
}

function logWarning(message) {
  log(`⚠️  ${message}`, 'yellow');
}

function logInfo(message) {
  log(`ℹ️  ${message}`, 'blue');
}

// Health check functions
async function checkBackendHealth() {
  return new Promise((resolve) => {
    const protocol = config.backend.protocol === 'https' ? https : http;
    const url = `${config.backend.protocol}://${config.backend.host}:${config.backend.port}/health`;
    
    const req = protocol.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          logSuccess('Backend API is healthy');
          resolve(true);
        } else {
          logError(`Backend API returned status ${res.statusCode}`);
          resolve(false);
        }
      });
    });
    
    req.on('error', (error) => {
      logError(`Backend API connection failed: ${error.message}`);
      resolve(false);
    });
    
    req.setTimeout(5000, () => {
      logError('Backend API health check timed out');
      req.destroy();
      resolve(false);
    });
  });
}

async function checkDatabaseHealth() {
  return new Promise((resolve) => {
    const command = `pg_isready -h ${config.database.host} -p ${config.database.port} -d ${config.database.name}`;
    
    exec(command, (error, stdout, stderr) => {
      if (error) {
        logError(`Database connection failed: ${error.message}`);
        resolve(false);
      } else {
        logSuccess('Database is healthy');
        resolve(true);
      }
    });
  });
}

async function checkRedisHealth() {
  return new Promise((resolve) => {
    const command = `redis-cli -h ${config.redis.host} -p ${config.redis.port} ping`;
    
    exec(command, (error, stdout, stderr) => {
      if (error) {
        logWarning(`Redis connection failed: ${error.message}`);
        resolve(false);
      } else if (stdout.trim() === 'PONG') {
        logSuccess('Redis is healthy');
        resolve(true);
      } else {
        logWarning('Redis ping failed');
        resolve(false);
      }
    });
  });
}

async function checkFileSystem() {
  const uploadsDir = path.join(__dirname, '..', 'backend', 'uploads');
  const logsDir = path.join(__dirname, '..', 'backend', 'logs');
  
  try {
    // Check uploads directory
    if (fs.existsSync(uploadsDir)) {
      const stats = fs.statSync(uploadsDir);
      if (stats.isDirectory()) {
        logSuccess('Uploads directory is accessible');
      } else {
        logError('Uploads path exists but is not a directory');
        return false;
      }
    } else {
      logWarning('Uploads directory does not exist');
    }
    
    // Check logs directory
    if (fs.existsSync(logsDir)) {
      const stats = fs.statSync(logsDir);
      if (stats.isDirectory()) {
        logSuccess('Logs directory is accessible');
      } else {
        logError('Logs path exists but is not a directory');
        return false;
      }
    } else {
      logWarning('Logs directory does not exist');
    }
    
    return true;
  } catch (error) {
    logError(`File system check failed: ${error.message}`);
    return false;
  }
}

async function checkEnvironmentVariables() {
  const requiredVars = [
    'DATABASE_URL',
    'JWT_SECRET',
    'JWT_REFRESH_SECRET',
    'GOOGLE_CLIENT_ID',
    'GOOGLE_CLIENT_SECRET'
  ];
  
  const envFile = path.join(__dirname, '..', 'backend', '.env');
  let envVars = {};
  
  // Load environment variables from .env file
  if (fs.existsSync(envFile)) {
    const envContent = fs.readFileSync(envFile, 'utf8');
    envContent.split('\n').forEach(line => {
      const [key, value] = line.split('=');
      if (key && value) {
        envVars[key.trim()] = value.trim();
      }
    });
  }
  
  // Check process environment variables
  Object.assign(envVars, process.env);
  
  let allPresent = true;
  
  for (const varName of requiredVars) {
    if (envVars[varName]) {
      logSuccess(`${varName} is configured`);
    } else {
      logError(`${varName} is missing`);
      allPresent = false;
    }
  }
  
  return allPresent;
}

async function checkDockerServices() {
  return new Promise((resolve) => {
    exec('docker-compose ps', (error, stdout, stderr) => {
      if (error) {
        logWarning('Docker Compose not available or not running');
        resolve(false);
      } else {
        const lines = stdout.split('\n').filter(line => line.trim());
        const services = lines.slice(1); // Skip header
        
        if (services.length > 0) {
          logInfo('Docker services status:');
          services.forEach(service => {
            const parts = service.split(/\s+/);
            if (parts.length >= 4) {
              const name = parts[0];
              const state = parts[3];
              if (state.includes('Up')) {
                logSuccess(`  ${name}: ${state}`);
              } else {
                logError(`  ${name}: ${state}`);
              }
            }
          });
          resolve(true);
        } else {
          logWarning('No Docker services found');
          resolve(false);
        }
      }
    });
  });
}

async function generateReport() {
  const timestamp = new Date().toISOString();
  const results = {
    timestamp,
    backend: await checkBackendHealth(),
    database: await checkDatabaseHealth(),
    redis: await checkRedisHealth(),
    filesystem: await checkFileSystem(),
    environment: await checkEnvironmentVariables(),
    docker: await checkDockerServices()
  };
  
  // Calculate overall health
  const criticalChecks = ['backend', 'database', 'environment'];
  const criticalPassed = criticalChecks.every(check => results[check]);
  const allPassed = Object.values(results).every(result => result === true || typeof result === 'string');
  
  log('\n' + '='.repeat(50), 'cyan');
  log('HEALTH CHECK SUMMARY', 'cyan');
  log('='.repeat(50), 'cyan');
  
  if (criticalPassed) {
    logSuccess('✅ All critical systems are healthy');
  } else {
    logError('❌ Critical system failures detected');
  }
  
  if (allPassed) {
    logSuccess('✅ All systems are healthy');
  } else {
    logWarning('⚠️  Some non-critical issues detected');
  }
  
  log(`\nTimestamp: ${timestamp}`, 'blue');
  log(`Overall Status: ${criticalPassed ? 'HEALTHY' : 'UNHEALTHY'}`, criticalPassed ? 'green' : 'red');
  
  // Save report to file
  const reportPath = path.join(__dirname, '..', 'health-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(results, null, 2));
  logInfo(`Report saved to: ${reportPath}`);
  
  return criticalPassed;
}

// Main execution
async function main() {
  log('🏥 Starting Health Check...', 'cyan');
  log('');
  
  const isHealthy = await generateReport();
  
  // Exit with appropriate code
  process.exit(isHealthy ? 0 : 1);
}

// Handle command line arguments
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log(`
Task Management Tool - Health Check

Usage: node health-check.js [options]

Options:
  -h, --help     Show this help message

Environment Variables:
  BACKEND_HOST   Backend host (default: localhost)
  BACKEND_PORT   Backend port (default: 3000)
  BACKEND_PROTOCOL Backend protocol (default: http)
  DB_HOST        Database host (default: localhost)
  DB_PORT        Database port (default: 5432)
  DB_NAME        Database name (default: taskmanagement)
  REDIS_HOST     Redis host (default: localhost)
  REDIS_PORT     Redis port (default: 6379)

Examples:
  node health-check.js
  BACKEND_HOST=api.example.com node health-check.js
  `);
  process.exit(0);
}

// Run the health check
main().catch(error => {
  logError(`Health check failed: ${error.message}`);
  process.exit(1);
});
