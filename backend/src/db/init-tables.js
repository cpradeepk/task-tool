import { knex } from './index.js';

export async function initializeTables() {
  try {
    console.log('Initializing database tables...');

    // Create users table
    const usersExists = await knex.schema.hasTable('users');
    if (!usersExists) {
      await knex.schema.createTable('users', (table) => {
        table.increments('id').primary();
        table.string('email').unique().notNullable();
        table.string('pin_hash');
        table.timestamp('pin_created_at');
        table.timestamp('pin_last_used');
        table.integer('pin_attempts').defaultTo(0);
        table.timestamp('pin_locked_until');
        table.string('first_name');
        table.string('last_name');
        table.string('phone');
        table.string('department');
        table.string('job_title');
        table.text('bio');
        table.string('timezone').defaultTo('UTC');
        table.string('language').defaultTo('English');
        table.boolean('email_notifications').defaultTo(true);
        table.boolean('push_notifications').defaultTo(false);
        table.timestamps(true, true);
      });
      console.log('Created users table');
    }

    // Create projects table
    const projectsExists = await knex.schema.hasTable('projects');
    if (!projectsExists) {
      await knex.schema.createTable('projects', (table) => {
        table.increments('id').primary();
        table.string('name').notNullable();
        table.text('description');
        table.date('start_date');
        table.date('end_date');
        table.string('status').defaultTo('Active');
        table.integer('created_by').references('id').inTable('users');
        table.timestamps(true, true);
      });
      console.log('Created projects table');
    }

    // Create modules table
    const modulesExists = await knex.schema.hasTable('modules');
    if (!modulesExists) {
      await knex.schema.createTable('modules', (table) => {
        table.increments('id').primary();
        table.integer('project_id').references('id').inTable('projects').onDelete('CASCADE');
        table.string('name').notNullable();
        table.text('description');
        table.integer('order_index').defaultTo(0);
        table.timestamps(true, true);
      });
      console.log('Created modules table');
    }

    // Create tasks table
    const tasksExists = await knex.schema.hasTable('tasks');
    if (!tasksExists) {
      await knex.schema.createTable('tasks', (table) => {
        table.increments('id').primary();
        table.integer('module_id').references('id').inTable('modules').onDelete('CASCADE');
        table.string('title').notNullable();
        table.text('description');
        table.string('status').defaultTo('Open');
        table.string('priority').defaultTo('Medium');
        table.integer('assigned_to').references('id').inTable('users');
        table.integer('estimated_hours');
        table.integer('actual_hours');
        table.date('due_date');
        table.timestamp('completed_at');
        table.integer('created_by').references('id').inTable('users');
        table.timestamps(true, true);
      });
      console.log('Created tasks table');
    }

    // Create roles table
    const rolesExists = await knex.schema.hasTable('roles');
    if (!rolesExists) {
      await knex.schema.createTable('roles', (table) => {
        table.increments('id').primary();
        table.string('name').unique().notNullable();
        table.text('description');
        table.text('permissions');
        table.timestamps(true, true);
      });
      console.log('Created roles table');

      // Insert default roles
      await knex('roles').insert([
        {
          name: 'Admin',
          description: 'Full system access',
          permissions: JSON.stringify(['*']),
        },
        {
          name: 'Manager',
          description: 'Project management access',
          permissions: JSON.stringify(['projects.*', 'tasks.*', 'reports.read']),
        },
        {
          name: 'User',
          description: 'Basic user access',
          permissions: JSON.stringify(['tasks.read', 'tasks.update', 'profile.*']),
        },
      ]);
      console.log('Inserted default roles');
    }

    // Create user_roles table
    const userRolesExists = await knex.schema.hasTable('user_roles');
    if (!userRolesExists) {
      await knex.schema.createTable('user_roles', (table) => {
        table.increments('id').primary();
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.integer('role_id').references('id').inTable('roles').onDelete('CASCADE');
        table.timestamp('assigned_at').defaultTo(knex.fn.now());
        table.unique(['user_id', 'role_id']);
      });
      console.log('Created user_roles table');
    }

    // Create notes table
    const notesExists = await knex.schema.hasTable('notes');
    if (!notesExists) {
      await knex.schema.createTable('notes', (table) => {
        table.increments('id').primary();
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.string('title').notNullable();
        table.text('content');
        table.string('category').defaultTo('Work');
        table.text('tags');
        table.timestamps(true, true);
      });
      console.log('Created notes table');
    }

    // Create chat_channels table
    const chatChannelsExists = await knex.schema.hasTable('chat_channels');
    if (!chatChannelsExists) {
      await knex.schema.createTable('chat_channels', (table) => {
        table.increments('id').primary();
        table.string('name').notNullable().unique();
        table.text('description');
        table.string('type').defaultTo('public');
        table.integer('created_by').references('id').inTable('users');
        table.boolean('is_archived').defaultTo(false);
        table.timestamps(true, true);
      });
      console.log('Created chat_channels table');

      // Insert default channels
      await knex('chat_channels').insert([
        {
          name: 'General',
          description: 'General discussion',
          type: 'public',
        },
        {
          name: 'Development',
          description: 'Development team chat',
          type: 'public',
        },
        {
          name: 'Announcements',
          description: 'Company announcements',
          type: 'public',
        },
      ]);
      console.log('Inserted default chat channels');
    }

    // Create channel_members table
    const channelMembersExists = await knex.schema.hasTable('channel_members');
    if (!channelMembersExists) {
      await knex.schema.createTable('channel_members', (table) => {
        table.increments('id').primary();
        table.integer('channel_id').references('id').inTable('chat_channels').onDelete('CASCADE');
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.string('role').defaultTo('member');
        table.timestamp('joined_at').defaultTo(knex.fn.now());
        table.unique(['channel_id', 'user_id']);
      });
      console.log('Created channel_members table');
    }

    // Create chat_messages table
    const chatMessagesExists = await knex.schema.hasTable('chat_messages');
    if (!chatMessagesExists) {
      await knex.schema.createTable('chat_messages', (table) => {
        table.increments('id').primary();
        table.integer('channel_id').references('id').inTable('chat_channels').onDelete('CASCADE');
        table.integer('user_id').references('id').inTable('users');
        table.text('content').notNullable();
        table.string('type').defaultTo('text');
        table.timestamp('edited_at');
        table.timestamps(true, true);
      });
      console.log('Created chat_messages table');
    }

    // Create notifications table
    const notificationsExists = await knex.schema.hasTable('notifications');
    if (!notificationsExists) {
      await knex.schema.createTable('notifications', (table) => {
        table.increments('id').primary();
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.string('title').notNullable();
        table.text('message');
        table.string('type');
        table.json('data');
        table.boolean('read').defaultTo(false);
        table.timestamp('read_at');
        table.timestamps(true, true);
      });
      console.log('Created notifications table');
    }

    // Create file_uploads table
    const fileUploadsExists = await knex.schema.hasTable('file_uploads');
    if (!fileUploadsExists) {
      await knex.schema.createTable('file_uploads', (table) => {
        table.increments('id').primary();
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.string('original_name').notNullable();
        table.string('filename').notNullable();
        table.string('file_path').notNullable();
        table.string('file_url').notNullable();
        table.string('mime_type');
        table.integer('file_size');
        table.string('storage_type').defaultTo('local');
        table.string('category').defaultTo('general');
        table.text('description');
        table.integer('task_id').references('id').inTable('tasks').onDelete('SET NULL');
        table.integer('project_id').references('id').inTable('projects').onDelete('SET NULL');
        table.timestamps(true, true);
      });
      console.log('Created file_uploads table');
    }

    console.log('Database initialization complete!');
  } catch (error) {
    console.error('Error initializing database:', error);
    throw error;
  }
}

// Run initialization if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  initializeTables()
    .then(() => {
      console.log('Database setup completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Database setup failed:', error);
      process.exit(1);
    });
}
