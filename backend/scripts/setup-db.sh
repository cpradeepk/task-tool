#!/bin/bash

echo "🔧 Setting up PostgreSQL database..."

# Check if PostgreSQL is running
if ! brew services list | grep -q "postgresql@17.*started"; then
    echo "Starting PostgreSQL 17..."
    brew services start postgresql@17
    sleep 3
fi

# Create database and user using psql
psql postgres << EOF
-- Create postgres user if it doesn't exist
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postgres') THEN
        CREATE USER postgres WITH SUPERUSER;
    END IF;
END
\$\$;

-- Create database if it doesn't exist
SELECT 'CREATE DATABASE task_management OWNER postgres'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'task_management')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE task_management TO postgres;

\q
EOF

echo "✅ Database setup complete!"
echo "📊 Testing connection..."

# Test the connection
if psql -h localhost -p 5432 -U postgres -d task_management -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Database connection successful!"
else
    echo "❌ Database connection failed"
    exit 1
fi