import pkg from 'bullmq';
const { Queue, Worker, QueueScheduler } = pkg;
import 'dotenv/config';

const connection = process.env.REDIS_URL || 'redis://localhost:6379';

export const emailQueue = new Queue('email', { connection });
new QueueScheduler('email', { connection });

export function startWorkers({ emailHandler } = {}) {
  if (emailHandler) {
    new Worker('email', emailHandler, { connection });
  }
}

