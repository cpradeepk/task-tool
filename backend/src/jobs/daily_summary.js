import { Queue } from 'bullmq';
import { knex } from '../db/index.js';
import { initEmail } from '../services/email.js';

const email = initEmail();
const emailQueue = new Queue('email', { connection: process.env.REDIS_URL || 'redis://localhost:6379' });

export async function enqueueDailySummaries() {
  const users = await knex('users').where({ active: true }).select('id','email');
  for (const u of users) {
    await emailQueue.add('send', await buildDailySummaryJob(u.id, u.email), { removeOnComplete: true, attempts: 3, backoff: { type: 'exponential', delay: 10000 } });
  }
}

async function buildDailySummaryJob(userId, emailAddress) {
  // Overdue and today
  const today = new Date();
  const todayISO = today.toISOString().substring(0,10);
  const overdue = await knex('tasks')
    .join('task_assignments','task_assignments.task_id','tasks.id')
    .where('task_assignments.user_id', userId)
    .whereNull('end_date')
    .whereNotNull('planned_end_date')
    .where('planned_end_date','<', todayISO)
    .select('tasks.title');
  const todayTasks = await knex('tasks')
    .join('task_assignments','task_assignments.task_id','tasks.id')
    .where('task_assignments.user_id', userId)
    .where('planned_end_date', todayISO)
    .select('tasks.title');

  const html = `<h3>Daily Summary</h3>
  <p>Overdue:</p>
  <ul>${overdue.map(t=>`<li>${t.title}</li>`).join('')}</ul>
  <p>Today:</p>
  <ul>${todayTasks.map(t=>`<li>${t.title}</li>`).join('')}</ul>`;

  return { to: emailAddress, subject: 'Task Tool Daily Summary', html };
}

