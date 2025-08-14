import cron from 'node-cron';
import { enqueueDailySummaries } from './daily_summary.js';

export function startCron() {
  // Run at 08:00 server time daily
  cron.schedule('0 8 * * *', async () => {
    try { await enqueueDailySummaries(); } catch (e) { console.error('Daily summary enqueue failed', e); }
  });
}

