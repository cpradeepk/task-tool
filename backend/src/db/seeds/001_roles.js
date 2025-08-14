export async function seed(knex) {
  await knex('user_roles').del();
  await knex('roles').del();
  const roles = ['Admin', 'Project Manager', 'Team Member'];
  for (const name of roles) {
    await knex('roles').insert({ name });
  }
}

