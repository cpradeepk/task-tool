/**** Knex configuration (CJS required by knex CLI) ****/
require('dotenv').config();

module.exports = {
  client: 'pg',
  connection: {
    host: process.env.PG_HOST,
    port: Number(process.env.PG_PORT || 5432),
    user: process.env.PG_USER,
    password: process.env.PG_PASSWORD,
    database: process.env.PG_DATABASE
  },
  migrations: {
    directory: __dirname + '/migrations',
    tableName: 'knex_migrations'
  }
};

