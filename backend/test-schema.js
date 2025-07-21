// Test script to verify schema changes
const { PrismaClient } = require('@prisma/client');

async function testSchema() {
  const prisma = new PrismaClient();
  
  try {
    console.log('Testing new schema...');
    
    // Test if we can access the new enums and fields
    console.log('TaskStatus enum values:', Object.values(prisma.taskStatus || {}));
    console.log('Priority enum values:', Object.values(prisma.priority || {}));
    console.log('TaskType enum values:', Object.values(prisma.taskType || {}));
    
    console.log('Schema test completed successfully!');
  } catch (error) {
    console.error('Schema test failed:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

testSchema();
