-- =====================================================
-- Margadarshi Task Management System - Database Migration
-- Phase 3 & 4 Enhancement Features
-- =====================================================

-- Add support team columns to tasks table
ALTER TABLE tasks ADD COLUMN support_team JSON;
ALTER TABLE tasks ADD COLUMN warning_count INTEGER DEFAULT 0;
ALTER TABLE tasks ADD COLUMN last_warning_date TIMESTAMP;
ALTER TABLE tasks ADD COLUMN task_id_formatted TEXT;

-- Add indexes for tasks table
CREATE INDEX idx_tasks_support_team ON tasks USING GIN (support_team);
CREATE INDEX idx_tasks_warning_count ON tasks (warning_count);
CREATE INDEX idx_tasks_formatted_id ON tasks (task_id_formatted);

-- Create task_support junction table
CREATE TABLE task_support (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    employee_id VARCHAR(50) NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    added_by VARCHAR(50),
    role TEXT DEFAULT 'support',
    is_active BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_task_support_task_id ON task_support (task_id);
CREATE INDEX idx_task_support_employee_id ON task_support (employee_id);
CREATE INDEX idx_task_support_active ON task_support (is_active);
CREATE UNIQUE INDEX unique_task_employee_support ON task_support (task_id, employee_id);

-- Create task_history table
CREATE TABLE task_history (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    changed_by VARCHAR(50) NOT NULL,
    change_type VARCHAR(50) NOT NULL,
    old_values JSON,
    new_values JSON,
    comment TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_task_history_task_id ON task_history (task_id);
CREATE INDEX idx_task_history_changed_by ON task_history (changed_by);
CREATE INDEX idx_task_history_change_type ON task_history (change_type);
CREATE INDEX idx_task_history_changed_at ON task_history (changed_at);

-- Create task_comments table
CREATE TABLE task_comments (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    author_id VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    attachments JSON,
    is_internal BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_task_comments_task_id ON task_comments (task_id);
CREATE INDEX idx_task_comments_author_id ON task_comments (author_id);
CREATE INDEX idx_task_comments_created_at ON task_comments (created_at);
CREATE INDEX idx_task_comments_deleted_at ON task_comments (deleted_at);

-- Add user management columns to users table
ALTER TABLE users ADD COLUMN warning_count INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN last_warning_date TIMESTAMP;
ALTER TABLE users ADD COLUMN manager_id VARCHAR(50);
ALTER TABLE users ADD COLUMN hire_date DATE;
ALTER TABLE users ADD COLUMN employee_photo TEXT;

CREATE INDEX idx_users_manager_id ON users (manager_id);
CREATE INDEX idx_users_warning_count ON users (warning_count);

-- Create user_warnings table
CREATE TABLE user_warnings (
    id SERIAL PRIMARY KEY,
    employee_id VARCHAR(50) NOT NULL,
    warning_type VARCHAR(50) NOT NULL,
    description TEXT,
    issued_by VARCHAR(50),
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP,
    resolved_by VARCHAR(50),
    resolution_notes TEXT
);

CREATE INDEX idx_user_warnings_employee_id ON user_warnings (employee_id);
CREATE INDEX idx_user_warnings_type ON user_warnings (warning_type);
CREATE INDEX idx_user_warnings_issued_at ON user_warnings (issued_at);
CREATE INDEX idx_user_warnings_resolved ON user_warnings (resolved);

-- Create task_templates table
CREATE TABLE task_templates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    template_data JSON NOT NULL,
    category VARCHAR(100),
    created_by VARCHAR(50) NOT NULL,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_task_templates_name ON task_templates (name);
CREATE INDEX idx_task_templates_category ON task_templates (category);
CREATE INDEX idx_task_templates_created_by ON task_templates (created_by);
CREATE INDEX idx_task_templates_public ON task_templates (is_public);
CREATE INDEX idx_task_templates_deleted_at ON task_templates (deleted_at);

-- Create leaves table
CREATE TABLE leaves (
    id SERIAL PRIMARY KEY,
    employee_id VARCHAR(50) NOT NULL,
    leave_type VARCHAR(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    approved_by VARCHAR(50),
    approved_at TIMESTAMP,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_leaves_employee_id ON leaves (employee_id);
CREATE INDEX idx_leaves_status ON leaves (status);
CREATE INDEX idx_leaves_start_date ON leaves (start_date);
CREATE INDEX idx_leaves_end_date ON leaves (end_date);

-- Create wfh_requests table
CREATE TABLE wfh_requests (
    id SERIAL PRIMARY KEY,
    employee_id VARCHAR(50) NOT NULL,
    date DATE NOT NULL,
    reason TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    approved_by VARCHAR(50),
    approved_at TIMESTAMP,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_wfh_requests_employee_id ON wfh_requests (employee_id);
CREATE INDEX idx_wfh_requests_date ON wfh_requests (date);
CREATE INDEX idx_wfh_requests_status ON wfh_requests (status);

-- Update existing tasks with formatted IDs
-- This will be handled by the application or a separate script
-- due to the complexity of generating sequential IDs

-- Insert sample task templates
INSERT INTO task_templates (name, description, template_data, category, created_by, is_public) VALUES
('Bug Fix Template', 'Standard template for bug fixing tasks', 
 '{"title": "Fix: [Bug Description]", "description": "## Bug Description\n\n## Steps to Reproduce\n\n## Expected Behavior\n\n## Actual Behavior\n\n## Solution", "priority": "High", "status": "Yet to Start"}', 
 'Development', 'system', true),
('Feature Development', 'Template for new feature development', 
 '{"title": "Feature: [Feature Name]", "description": "## Feature Requirements\n\n## Acceptance Criteria\n\n## Technical Notes\n\n## Testing Requirements", "priority": "Medium", "status": "Yet to Start"}', 
 'Development', 'system', true),
('Code Review', 'Template for code review tasks', 
 '{"title": "Review: [Component/Feature]", "description": "## Review Checklist\n- [ ] Code quality\n- [ ] Performance\n- [ ] Security\n- [ ] Documentation\n- [ ] Tests", "priority": "Medium", "status": "Yet to Start"}', 
 'Quality Assurance', 'system', true);

-- Create a function to generate formatted task IDs
CREATE OR REPLACE FUNCTION generate_task_id()
RETURNS TRIGGER AS $$
DECLARE
    task_date DATE;
    date_str TEXT;
    next_num INTEGER;
    formatted_id TEXT;
BEGIN
    -- Get the creation date
    task_date := COALESCE(NEW.created_at::DATE, CURRENT_DATE);
    date_str := TO_CHAR(task_date, 'YYYYMMDD');
    
    -- Get the next number for this date
    SELECT COALESCE(MAX(CAST(SUBSTRING(task_id_formatted FROM 'JSR-' || date_str || '-(.*)') AS INTEGER)), 0) + 1
    INTO next_num
    FROM tasks 
    WHERE task_id_formatted LIKE 'JSR-' || date_str || '-%';
    
    -- Generate the formatted ID
    formatted_id := 'JSR-' || date_str || '-' || LPAD(next_num::TEXT, 3, '0');
    
    -- Set the formatted ID
    NEW.task_id_formatted := formatted_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic task ID generation
CREATE TRIGGER trigger_generate_task_id
    BEFORE INSERT ON tasks
    FOR EACH ROW
    WHEN (NEW.task_id_formatted IS NULL)
    EXECUTE FUNCTION generate_task_id();

-- Update existing tasks with formatted IDs (run this after the trigger is created)
DO $$
DECLARE
    task_record RECORD;
    task_date DATE;
    date_str TEXT;
    next_num INTEGER;
    formatted_id TEXT;
BEGIN
    FOR task_record IN SELECT id, created_at FROM tasks WHERE task_id_formatted IS NULL ORDER BY created_at, id LOOP
        task_date := task_record.created_at::DATE;
        date_str := TO_CHAR(task_date, 'YYYYMMDD');
        
        SELECT COALESCE(MAX(CAST(SUBSTRING(task_id_formatted FROM 'JSR-' || date_str || '-(.*)') AS INTEGER)), 0) + 1
        INTO next_num
        FROM tasks 
        WHERE task_id_formatted LIKE 'JSR-' || date_str || '-%';
        
        formatted_id := 'JSR-' || date_str || '-' || LPAD(next_num::TEXT, 3, '0');
        
        UPDATE tasks SET task_id_formatted = formatted_id WHERE id = task_record.id;
    END LOOP;
END $$;

-- Add some sample leave types if they don't exist
-- This can be handled by the application

COMMIT;
