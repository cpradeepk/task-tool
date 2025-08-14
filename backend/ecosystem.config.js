module.exports = {
  apps: [
    {
      name: 'task-tool-backend',
      script: 'src/server.js',
      interpreter: 'node',
      env: {
        NODE_ENV: 'production',
        PORT: 3003,
        CORS_ORIGIN: 'https://ai.swargfood.com',
        SMTP_HOST: 'smtp.gmail.com',
        SMTP_PORT: 465,
        SMTP_SECURE: true,
        SMTP_USER: 'youraddress@gmail.com',
        SMTP_PASS: 'replace_with_app_password',
        EMAIL_FROM: 'Task Tool <youraddress@gmail.com>'
      }
    }
  ]
};

