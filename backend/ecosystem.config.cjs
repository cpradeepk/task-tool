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
        BASE_URL: 'https://ai.swargfood.com',
        // DATABASE_URL, JWT_SECRET, GOOGLE_CLIENT_ID, SMTP_*, EMAIL_FROM, UPLOAD_DIR...
      },
      watch: false,
      instances: 1,
      exec_mode: 'fork',
      out_file: '/var/log/task-tool/backend.out.log',
      error_file: '/var/log/task-tool/backend.err.log',
      merge_logs: true
    }
  ]
};