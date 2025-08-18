/**
 * Migration: Merge user_profile table into users table
 * This migration safely merges all columns from user_profiles into users table
 * and migrates existing data without loss.
 */

export async function up(knex) {
  console.log('Starting user_profile to users table merge migration...');

  // Step 1: Add user_profile columns to users table
  await knex.schema.alterTable('users', (table) => {
    // Profile information columns
    table.string('name').nullable();
    table.string('short_name').nullable();
    table.string('telegram').nullable();
    table.string('whatsapp').nullable();
    
    // UI/Theme preferences
    table.string('theme').defaultTo('light');
    table.string('accent_color').defaultTo('#64b5f6');
    table.string('font').nullable();
    table.string('avatar_url').nullable();
    
    // Note: phone column already exists in users table from init-tables.js
    // so we don't add it again
  });
  
  console.log('Added user_profile columns to users table');

  // Step 2: Check if user_profiles table exists and migrate data
  const hasUserProfilesTable = await knex.schema.hasTable('user_profiles');
  
  if (hasUserProfilesTable) {
    console.log('Found user_profiles table, migrating data...');
    
    // Get all user profiles
    const userProfiles = await knex('user_profiles').select('*');
    
    console.log(`Found ${userProfiles.length} user profiles to migrate`);
    
    // Migrate each user profile to users table
    for (const profile of userProfiles) {
      await knex('users')
        .where('id', profile.user_id)
        .update({
          name: profile.name,
          short_name: profile.short_name,
          phone: profile.phone, // Update existing phone column if different
          telegram: profile.telegram,
          whatsapp: profile.whatsapp,
          theme: profile.theme,
          accent_color: profile.accent_color,
          font: profile.font,
          avatar_url: profile.avatar_url,
          updated_at: knex.fn.now()
        });
    }
    
    console.log('Successfully migrated all user profile data');
    
    // Step 3: Drop the user_profiles table
    await knex.schema.dropTableIfExists('user_profiles');
    console.log('Dropped user_profiles table');
  } else {
    console.log('user_profiles table does not exist, skipping data migration');
  }
  
  console.log('User profile merge migration completed successfully');
}

export async function down(knex) {
  console.log('Rolling back user_profile merge migration...');
  
  // Step 1: Recreate user_profiles table
  await knex.schema.createTable('user_profiles', (table) => {
    table.integer('user_id').primary().references('id').inTable('users').onDelete('CASCADE');
    table.string('name');
    table.string('short_name');
    table.string('phone');
    table.string('telegram');
    table.string('whatsapp');
    table.string('theme').defaultTo('light');
    table.string('accent_color').defaultTo('#64b5f6');
    table.string('font');
    table.string('avatar_url');
    table.timestamp('updated_at').defaultTo(knex.fn.now());
  });
  
  console.log('Recreated user_profiles table');
  
  // Step 2: Migrate data back from users to user_profiles
  const users = await knex('users')
    .select('id', 'name', 'short_name', 'phone', 'telegram', 'whatsapp', 
            'theme', 'accent_color', 'font', 'avatar_url')
    .whereNotNull('name'); // Only migrate users that have profile data
  
  console.log(`Migrating ${users.length} user profiles back to user_profiles table`);
  
  for (const user of users) {
    await knex('user_profiles').insert({
      user_id: user.id,
      name: user.name,
      short_name: user.short_name,
      phone: user.phone,
      telegram: user.telegram,
      whatsapp: user.whatsapp,
      theme: user.theme || 'light',
      accent_color: user.accent_color || '#64b5f6',
      font: user.font,
      avatar_url: user.avatar_url
    });
  }
  
  // Step 3: Remove the added columns from users table
  await knex.schema.alterTable('users', (table) => {
    table.dropColumn('name');
    table.dropColumn('short_name');
    table.dropColumn('telegram');
    table.dropColumn('whatsapp');
    table.dropColumn('theme');
    table.dropColumn('accent_color');
    table.dropColumn('font');
    table.dropColumn('avatar_url');
    // Note: We keep the phone column as it was originally in users table
  });
  
  console.log('Rollback completed successfully');
}
