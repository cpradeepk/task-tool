module.exports = {
  apps: [
    {
      name: 'swargfood-task-management',
      script: 'src/server.js',
      cwd: '/var/www/task/backend',
      instances: 1, // Single instance for initial deployment
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'development',
        PORT: 3003,
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3003,
        API_BASE_URL: 'https://ai.swargfood.com/task',
        FRONTEND_URL: 'https://ai.swargfood.com/task',
        CORS_ORIGIN: 'https://ai.swargfood.com',
        SOCKET_CORS_ORIGIN: 'https://ai.swargfood.com'
      },
      // Logging
      log_file: '/var/www/task/logs/combined.log',
      out_file: '/var/www/task/logs/out.log',
      error_file: '/var/www/task/logs/error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      
      // Auto restart configuration
      watch: false, // Set to true for development
      ignore_watch: ['node_modules', 'logs', 'uploads'],
      max_restarts: 10,
      min_uptime: '10s',
      
      // Memory management
      max_memory_restart: '500M',
      
      // Advanced features
      kill_timeout: 5000,
      wait_ready: true,
      listen_timeout: 10000,
      
      // Environment-specific settings
      node_args: '--max-old-space-size=1024',
      
      // Health monitoring
      health_check_grace_period: 3000,
      health_check_fatal_exceptions: true,
    }
  ],

  deploy: {
    production: {
      user: 'deploy',
      host: 'ai.swargfood.com',
      ref: 'origin/main',
      repo: 'git@github.com:your-username/task-tool.git',
      path: '/var/www/task',
      'pre-deploy-local': '',
      'post-deploy': 'cd backend && npm install --production && npm run generate && npm run migrate:prod && pm2 reload ecosystem.config.js --env production',
      'pre-setup': 'mkdir -p /var/www/task/logs && mkdir -p /var/www/task/uploads'
    }
  }
};
