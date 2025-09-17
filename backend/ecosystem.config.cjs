module.exports = {
  apps: [
    {
      name: 'task-tool-backend',
      cwd: '/srv/task-tool/backend',
      script: 'src/server.js',
      interpreter: 'node',
      env: {
        NODE_ENV: 'production',
        PORT: 3003,
        BASE_URL: 'https://task.amtariksha.com',

        // Postgres
        PG_HOST: 'ls-f772dda62fea5a74f7a3e8f9139a79078b65a32f.crq8gq4ka0rw.ap-south-1.rds.amazonaws.com',
        PG_PORT: 5432,
        PG_USER: 'dbmasteruser',
        PG_PASSWORD: '~f~u*MRlsioIJm2IRGu$]qPXR!rr;C[6',
        PG_DATABASE: 'tasktool',

        // Redis (for BullMQ queue & scheduler)
        REDIS_URL: 'redis://127.0.0.1:6379',

        // Auth / JWT
        JWT_SECRET: 'afu6lJQakmsoXnRyxx3n9zP_VBL9trm7dudoWtTEafHPMh0qbY26S5UlMSA_lQq07c8LD80WnmHzhh-8rwvXWg',

        // CORS
        CORS_ORIGIN: 'https://task.amtariksha.com',

        // SMTP (Gmail with app password)
        SMTP_HOST: 'smtp.gmail.com',
        SMTP_PORT: 465,
        SMTP_SECURE: true,
        SMTP_USER: 'amtariksha@gmail.com',
        SMTP_PASS: '1#Amtariksha1#',
        EMAIL_FROM: 'Task Tool <amtariksha@gmail.com>',

        // Uploads dir (must match Nginx alias)
        UPLOAD_DIR: '/var/www/task/uploads'
      },
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      out_file: '/var/log/task-tool/backend.out.log',
      error_file: '/var/log/task-tool/backend.err.log',
      merge_logs: true
    }
  ]
};
