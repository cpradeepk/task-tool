const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const useSsl = String(process.env.PG_SSL || 'false') === 'true';

module.exports = {
  client: 'pg',
  connection: {
    host: process.env.PG_HOST,
    port: Number(process.env.PG_PORT || 5432),
    user: process.env.PG_USER,
    password: process.env.PG_PASSWORD,
    database: process.env.PG_DATABASE,
    ssl: useSsl ? { rejectUnauthorized: false } : undefined
  },
  migrations: { directory: __dirname + '/migrations', tableName: 'knex_migrations' }
};
