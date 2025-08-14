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

  return { send };
}

