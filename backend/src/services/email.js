import nodemailer from 'nodemailer';

export function initEmail() {
  const host = process.env.SMTP_HOST || 'smtp.gmail.com';
  const port = Number(process.env.SMTP_PORT || 465);
  const secure = String(process.env.SMTP_SECURE || 'true') === 'true';
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.EMAIL_FROM || user;

  if (!user || !pass) {
    console.warn('[email] SMTP_USER/SMTP_PASS missing. Email sending will fail.');
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure, // true for 465, false for 587
    auth: { user, pass }
  });

  async function send({ to, subject, html, text }) {
    const info = await transporter.sendMail({ from, to, subject, html, text });
    return { messageId: info.messageId, accepted: info.accepted };
  }

  // Project assignment notification
  async function sendProjectAssignmentNotification({ userEmail, userName, projectName, role, assignedBy }) {
    const subject = `You've been assigned to project: ${projectName}`;

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
          <h2 style="color: #2c3e50; margin: 0;">Project Assignment Notification</h2>
        </div>

        <div style="padding: 20px; background-color: white; border-radius: 8px; border: 1px solid #e9ecef;">
          <p>Hello ${userName},</p>

          <p>You have been assigned to a new project with the following details:</p>

          <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3 style="color: #495057; margin-top: 0;">Project Details</h3>
            <p><strong>Project Name:</strong> ${projectName}</p>
            <p><strong>Your Role:</strong> ${role}</p>
            <p><strong>Assigned By:</strong> ${assignedBy}</p>
          </div>

          <p>You can now access this project and start collaborating with your team members.</p>

          <div style="text-align: center; margin: 30px 0;">
            <a href="${process.env.FRONTEND_URL || 'https://task.amtariksha.com'}/task/#/projects"
               style="background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
              View Project
            </a>
          </div>

          <p style="color: #6c757d; font-size: 14px; margin-top: 30px;">
            If you have any questions about this project assignment, please contact your project manager or administrator.
          </p>
        </div>

        <div style="text-align: center; padding: 20px; color: #6c757d; font-size: 12px;">
          <p>This is an automated notification from the Task Management System.</p>
        </div>
      </div>
    `;

    return await send({ to: userEmail, subject, html });
  }

  // Task assignment notification
  async function sendTaskAssignmentNotification({
    userEmail,
    userName,
    taskTitle,
    taskId,
    projectName,
    moduleName,
    priority,
    dueDate,
    assignedBy
  }) {
    const subject = `New task assigned: ${taskTitle}`;

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
          <h2 style="color: #2c3e50; margin: 0;">Task Assignment Notification</h2>
        </div>

        <div style="padding: 20px; background-color: white; border-radius: 8px; border: 1px solid #e9ecef;">
          <p>Hello ${userName},</p>

          <p>A new task has been assigned to you with the following details:</p>

          <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3 style="color: #495057; margin-top: 0;">Task Details</h3>
            <p><strong>Task ID:</strong> ${taskId}</p>
            <p><strong>Title:</strong> ${taskTitle}</p>
            <p><strong>Project:</strong> ${projectName}</p>
            <p><strong>Module:</strong> ${moduleName || 'Unassigned'}</p>
            <p><strong>Priority:</strong> ${priority || 'Normal'}</p>
            ${dueDate ? `<p><strong>Due Date:</strong> ${new Date(dueDate).toLocaleDateString()}</p>` : ''}
            <p><strong>Assigned By:</strong> ${assignedBy}</p>
          </div>

          <p>Please review the task details and start working on it as soon as possible.</p>

          <div style="text-align: center; margin: 30px 0;">
            <a href="${process.env.FRONTEND_URL || 'https://task.amtariksha.com'}/task/#/tasks"
               style="background-color: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
              View Task
            </a>
          </div>

          <p style="color: #6c757d; font-size: 14px; margin-top: 30px;">
            If you have any questions about this task, please contact your project manager or the person who assigned it to you.
          </p>
        </div>

        <div style="text-align: center; padding: 20px; color: #6c757d; font-size: 12px;">
          <p>This is an automated notification from the Task Management System.</p>
        </div>
      </div>
    `;

    return await send({ to: userEmail, subject, html });
  }

  return { send, sendProjectAssignmentNotification, sendTaskAssignmentNotification };
}

