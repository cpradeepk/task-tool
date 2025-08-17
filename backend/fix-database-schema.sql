-- Fix Database Schema for Task Tool
-- Run this to add missing columns and fix schema issues

-- Add missing columns to users table if they don't exist
DO $$ 
BEGIN
    -- Add updated_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='updated_at') THEN
        ALTER TABLE users ADD COLUMN updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
    END IF;
    
    -- Add pin_hash column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pin_hash') THEN
        ALTER TABLE users ADD COLUMN pin_hash VARCHAR(255);
    END IF;
    
    -- Add pin_created_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pin_created_at') THEN
        ALTER TABLE users ADD COLUMN pin_created_at TIMESTAMPTZ;
    END IF;
    
    -- Add pin_last_used column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pin_last_used') THEN
        ALTER TABLE users ADD COLUMN pin_last_used TIMESTAMPTZ;
    END IF;
    
    -- Add pin_attempts column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pin_attempts') THEN
        ALTER TABLE users ADD COLUMN pin_attempts INTEGER DEFAULT 0;
    END IF;
    
    -- Add pin_locked_until column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pin_locked_until') THEN
        ALTER TABLE users ADD COLUMN pin_locked_until TIMESTAMPTZ;
    END IF;
END $$;

-- Add missing columns to tasks table if they don't exist
DO $$ 
BEGIN
    -- Add assigned_to column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='assigned_to') THEN
        ALTER TABLE tasks ADD COLUMN assigned_to INTEGER;
    END IF;
    
    -- Add updated_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='updated_at') THEN
        ALTER TABLE tasks ADD COLUMN updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
    END IF;
    
    -- Add module_id column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='module_id') THEN
        ALTER TABLE tasks ADD COLUMN module_id INTEGER;
    END IF;
    
    -- Add status column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='status') THEN
        ALTER TABLE tasks ADD COLUMN status VARCHAR(50) DEFAULT 'Open';
    END IF;
    
    -- Add priority column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='priority') THEN
        ALTER TABLE tasks ADD COLUMN priority VARCHAR(20) DEFAULT 'Medium';
    END IF;
    
    -- Add estimated_hours column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='estimated_hours') THEN
        ALTER TABLE tasks ADD COLUMN estimated_hours INTEGER;
    END IF;
    
    -- Add actual_hours column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='actual_hours') THEN
        ALTER TABLE tasks ADD COLUMN actual_hours INTEGER;
    END IF;
    
    -- Add due_date column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='due_date') THEN
        ALTER TABLE tasks ADD COLUMN due_date DATE;
    END IF;
    
    -- Add completed_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='completed_at') THEN
        ALTER TABLE tasks ADD COLUMN completed_at TIMESTAMPTZ;
    END IF;
    
    -- Add created_by column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tasks' AND column_name='created_by') THEN
        ALTER TABLE tasks ADD COLUMN created_by INTEGER;
    END IF;
END $$;

-- Create projects table if it doesn't exist
CREATE TABLE IF NOT EXISTS projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    start_date DATE,
    end_date DATE,
    status VARCHAR(50) DEFAULT 'Active',
    created_by INTEGER,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create modules table if it doesn't exist
CREATE TABLE IF NOT EXISTS modules (
    id SERIAL PRIMARY KEY,
    project_id INTEGER,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create notes table if it doesn't exist
CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    category VARCHAR(50) DEFAULT 'Work',
    tags TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create chat_channels table if it doesn't exist
CREATE TABLE IF NOT EXISTS chat_channels (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    type VARCHAR(20) DEFAULT 'public',
    created_by INTEGER,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create chat_messages table if it doesn't exist
CREATE TABLE IF NOT EXISTS chat_messages (
    id SERIAL PRIMARY KEY,
    channel_id INTEGER,
    user_id INTEGER,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create notifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    type VARCHAR(50),
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert default chat channels if they don't exist
INSERT INTO chat_channels (name, description, type) 
SELECT 'General', 'General discussion', 'public'
WHERE NOT EXISTS (SELECT 1 FROM chat_channels WHERE name = 'General');

INSERT INTO chat_channels (name, description, type) 
SELECT 'Development', 'Development team chat', 'public'
WHERE NOT EXISTS (SELECT 1 FROM chat_channels WHERE name = 'Development');

INSERT INTO chat_channels (name, description, type) 
SELECT 'Announcements', 'Company announcements', 'public'
WHERE NOT EXISTS (SELECT 1 FROM chat_channels WHERE name = 'Announcements');

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_channel_id ON chat_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- Update existing records to have default values where needed
UPDATE tasks SET status = 'Open' WHERE status IS NULL;
UPDATE tasks SET priority = 'Medium' WHERE priority IS NULL;
UPDATE users SET pin_attempts = 0 WHERE pin_attempts IS NULL;

COMMIT;
