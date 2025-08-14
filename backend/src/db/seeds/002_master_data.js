export async function seed(knex) {
  await knex('priorities').del();
  await knex('statuses').del();
  await knex('task_types').del();
  await knex('project_types').del();

  // Statuses
  const statuses = [
    { name: 'Open', color: '#ffffff' },
    { name: 'In Progress', color: '#ffeb3b' },
    { name: 'Completed', color: '#4caf50' },
    { name: 'Cancelled', color: '#9e9e9e' },
    { name: 'Hold', color: '#795548' },
    { name: 'Delayed', color: '#f44336' },
  ];
  await knex('statuses').insert(statuses);

  // Priorities (Eisenhower + order)
  const priorities = [
    { name: 'Important & Urgent', order: 1, color: '#ff9800', matrix_quadrant: 'IU' },
    { name: 'Important & Not Urgent', order: 2, color: '#ffeb3b', matrix_quadrant: 'IN' },
    { name: 'Not Important & Urgent', order: 3, color: '#ffffff', matrix_quadrant: 'NU' },
    { name: 'Not Important & Not Urgent', order: 4, color: '#ffffff', matrix_quadrant: 'NN' },
  ];
  await knex('priorities').insert(priorities);

  // Task types
  const taskTypes = ['Requirement', 'Design', 'Coding', 'Testing', 'Learning', 'Documentation']
    .map((name) => ({ name }));
  await knex('task_types').insert(taskTypes);

  // Project types (placeholder)
  const projectTypes = ['Default', 'Time-bound', 'Maintenance'].map((name) => ({ name }));
  await knex('project_types').insert(projectTypes);
}

