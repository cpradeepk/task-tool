# Requirements (Excerpt: Email updates)

Change: Replace AWS SES with Gmail SMTP for all emails:
- Task assignment notifications
- Status change alerts
- Daily summary emails
- Mention notifications

Constraints:
- Use Gmail/Workspace with 2FA + App Password
- Acknowledge daily sending limits; implement rate caps
- Maintain same email templates and triggers as original plan

