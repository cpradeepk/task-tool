import express from 'express';
import nodemailer from 'nodemailer';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

// Configure email transporter
const createTransporter = () => {
  if (process.env.EMAIL_SERVICE === 'gmail') {
    return nodemailer.createTransporter({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
      }
    });
  } else if (process.env.SMTP_HOST) {
    return nodemailer.createTransporter({
      host: process.env.SMTP_HOST,
      port: process.env.SMTP_PORT || 587,
      secure: process.env.SMTP_SECURE === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
      }
    });
  } else {
    // Development mode - use ethereal email
    return nodemailer.createTransporter({
      host: 'smtp.ethereal.email',
      port: 587,
      auth: {
        user: 'ethereal.user@ethereal.email',
        pass: 'ethereal.pass'
      }
    });
  }
};

// Email templates
const emailTemplates = {
  task_assigned: {
    subject: 'New Task Assigned: {{task_title}}',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #FFA301;">Task Assigned</h2>
        <p>Hello {{user_name}},</p>
        <p>You have been assigned a new task:</p>
        <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 15px 0;">
          <h3 style="margin: 0 0 10px 0;">{{task_title}}</h3>
          <p style="margin: 0;"><strong>Project:</strong> {{project_name}}</p>
          <p style="margin: 0;"><strong>Priority:</strong> {{priority}}</p>
          <p style="margin: 0;"><strong>Due Date:</strong> {{due_date}}</p>
          {{#if description}}<p style="margin: 10px 0 0 0;"><strong>Description:</strong> {{description}}</p>{{/if}}
        </div>
        <p><a href="{{app_url}}/tasks/{{task_id}}" style="background: #FFA301; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Task</a></p>
        <p>Best regards,<br>Task Tool Team</p>
      </div>
    `
  },
  task_completed: {
    subject: 'Task Completed: {{task_title}}',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #28a745;">Task Completed</h2>
        <p>Hello {{user_name}},</p>
        <p>The following task has been completed:</p>
        <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 15px 0;">
          <h3 style="margin: 0 0 10px 0;">{{task_title}}</h3>
          <p style="margin: 0;"><strong>Project:</strong> {{project_name}}</p>
          <p style="margin: 0;"><strong>Completed by:</strong> {{completed_by}}</p>
          <p style="margin: 0;"><strong>Completed on:</strong> {{completed_date}}</p>
        </div>
        <p><a href="{{app_url}}/tasks/{{task_id}}" style="background: #28a745; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Task</a></p>
        <p>Best regards,<br>Task Tool Team</p>
      </div>
    `
  },
  deadline_reminder: {
    subject: 'Deadline Reminder: {{task_title}}',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #dc3545;">Deadline Reminder</h2>
        <p>Hello {{user_name}},</p>
        <p>This is a reminder that the following task is due {{time_remaining}}:</p>
        <div style="background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 15px 0;">
          <h3 style="margin: 0 0 10px 0;">{{task_title}}</h3>
          <p style="margin: 0;"><strong>Project:</strong> {{project_name}}</p>
          <p style="margin: 0;"><strong>Due Date:</strong> {{due_date}}</p>
          <p style="margin: 0;"><strong>Priority:</strong> {{priority}}</p>
          <p style="margin: 0;"><strong>Status:</strong> {{status}}</p>
        </div>
        <p><a href="{{app_url}}/tasks/{{task_id}}" style="background: #dc3545; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Task</a></p>
        <p>Best regards,<br>Task Tool Team</p>
      </div>
    `
  },
  project_invitation: {
    subject: 'Project Invitation: {{project_name}}',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #FFA301;">Project Invitation</h2>
        <p>Hello {{user_name}},</p>
        <p>You have been invited to join the project:</p>
        <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 15px 0;">
          <h3 style="margin: 0 0 10px 0;">{{project_name}}</h3>
          <p style="margin: 0;"><strong>Invited by:</strong> {{invited_by}}</p>
          {{#if description}}<p style="margin: 10px 0 0 0;"><strong>Description:</strong> {{description}}</p>{{/if}}
        </div>
        <p><a href="{{app_url}}/projects/{{project_id}}" style="background: #FFA301; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Project</a></p>
        <p>Best regards,<br>Task Tool Team</p>
      </div>
    `
  },
  welcome: {
    subject: 'Welcome to Task Tool!',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #FFA301;">Welcome to Task Tool!</h2>
        <p>Hello {{user_name}},</p>
        <p>Welcome to Task Tool! Your account has been created successfully.</p>
        <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 15px 0;">
          <p style="margin: 0;"><strong>Email:</strong> {{email}}</p>
          <p style="margin: 0;"><strong>Role:</strong> {{role}}</p>
          {{#if temporary_password}}<p style="margin: 0;"><strong>Temporary Password:</strong> {{temporary_password}}</p>{{/if}}
        </div>
        <p>You can now log in and start managing your tasks and projects.</p>
        <p><a href="{{app_url}}/login" style="background: #FFA301; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Login Now</a></p>
        <p>Best regards,<br>Task Tool Team</p>
      </div>
    `
  }
};

// Send email endpoint
router.post('/send', async (req, res) => {
  try {
    const { to, template, data, subject, html, text } = req.body;

    if (!to) {
      return res.status(400).json({ error: 'Recipient email is required' });
    }

    let emailSubject = subject;
    let emailHtml = html;
    let emailText = text;

    // Use template if provided
    if (template && emailTemplates[template]) {
      const templateData = emailTemplates[template];
      emailSubject = templateData.subject;
      emailHtml = templateData.html;
      
      // Replace template variables
      if (data) {
        emailSubject = replaceTemplateVariables(emailSubject, data);
        emailHtml = replaceTemplateVariables(emailHtml, data);
      }
    }

    if (!emailSubject || !emailHtml) {
      return res.status(400).json({ error: 'Email subject and content are required' });
    }

    const transporter = createTransporter();
    
    const mailOptions = {
      from: process.env.EMAIL_FROM || 'noreply@tasktool.com',
      to,
      subject: emailSubject,
      html: emailHtml,
      text: emailText
    };

    const info = await transporter.sendMail(mailOptions);

    // Log email in database
    await knex('email_logs').insert({
      user_id: req.user.id,
      recipient: to,
      subject: emailSubject,
      template: template || 'custom',
      status: 'sent',
      message_id: info.messageId,
      created_at: new Date()
    }).catch(() => {}); // Ignore if table doesn't exist

    res.json({
      message: 'Email sent successfully',
      messageId: info.messageId
    });

  } catch (error) {
    console.error('Email send error:', error);
    
    // Log failed email
    await knex('email_logs').insert({
      user_id: req.user.id,
      recipient: req.body.to,
      subject: req.body.subject || 'Unknown',
      template: req.body.template || 'custom',
      status: 'failed',
      error_message: error.message,
      created_at: new Date()
    }).catch(() => {});

    res.status(500).json({ error: 'Failed to send email' });
  }
});

// Get email templates
router.get('/templates', (req, res) => {
  const templates = Object.keys(emailTemplates).map(key => ({
    name: key,
    subject: emailTemplates[key].subject,
    description: getTemplateDescription(key)
  }));
  
  res.json({ templates });
});

// Get specific template
router.get('/templates/:templateName', (req, res) => {
  const { templateName } = req.params;
  const template = emailTemplates[templateName];
  
  if (!template) {
    return res.status(404).json({ error: 'Template not found' });
  }
  
  res.json({
    name: templateName,
    ...template,
    description: getTemplateDescription(templateName)
  });
});

// Get email logs
router.get('/logs', async (req, res) => {
  try {
    const { limit = 20, offset = 0, status, template } = req.query;
    const userId = req.user.isAdmin ? null : req.user.id;

    let query = knex('email_logs').select('*');
    
    if (userId) {
      query = query.where('user_id', userId);
    }
    
    if (status) {
      query = query.where('status', status);
    }
    
    if (template) {
      query = query.where('template', template);
    }

    const logs = await query
      .orderBy('created_at', 'desc')
      .limit(parseInt(limit))
      .offset(parseInt(offset))
      .catch(() => []);

    const [{ count: totalCount }] = await knex('email_logs')
      .count('* as count')
      .modify(queryBuilder => {
        if (userId) queryBuilder.where('user_id', userId);
        if (status) queryBuilder.where('status', status);
        if (template) queryBuilder.where('template', template);
      })
      .catch(() => [{ count: 0 }]);

    res.json({
      logs,
      pagination: {
        total: parseInt(totalCount),
        limit: parseInt(limit),
        offset: parseInt(offset),
        has_more: parseInt(offset) + parseInt(limit) < parseInt(totalCount)
      }
    });
  } catch (error) {
    console.error('Error fetching email logs:', error);
    res.status(500).json({ error: 'Failed to fetch email logs' });
  }
});

// Helper functions
function replaceTemplateVariables(template, data) {
  let result = template;
  
  // Replace simple variables {{variable}}
  Object.keys(data).forEach(key => {
    const regex = new RegExp(`{{${key}}}`, 'g');
    result = result.replace(regex, data[key] || '');
  });
  
  // Handle conditional blocks {{#if variable}}...{{/if}}
  result = result.replace(/{{#if\s+(\w+)}}(.*?){{\/if}}/gs, (match, variable, content) => {
    return data[variable] ? content : '';
  });
  
  return result;
}

function getTemplateDescription(templateName) {
  const descriptions = {
    task_assigned: 'Sent when a task is assigned to a user',
    task_completed: 'Sent when a task is marked as completed',
    deadline_reminder: 'Sent as a reminder before task deadlines',
    project_invitation: 'Sent when a user is invited to join a project',
    welcome: 'Sent when a new user account is created'
  };
  
  return descriptions[templateName] || 'Custom email template';
}

export default router;
