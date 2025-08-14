import knexPkg from 'knex';
import { Model } from 'objection';
import 'dotenv/config';

const useSsl = String(process.env.PG_SSL || 'false') === 'true';
const knex = knexPkg({
  client: 'pg',
  connection: {
    host: process.env.PG_HOST,
    port: Number(process.env.PG_PORT || 5432),
    user: process.env.PG_USER,
    password: process.env.PG_PASSWORD,
    database: process.env.PG_DATABASE,
    ssl: useSsl ? { rejectUnauthorized: false } : undefined
  },
  pool: { min: 0, max: 10 }
});

Model.knex(knex);

export { knex, Model };

