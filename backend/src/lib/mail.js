import nodemailer from 'nodemailer';

/**
 * Sends a password reset message. If SMTP is not configured, logs the token (dev-friendly).
 */
export async function sendPasswordResetEmail(app, to, resetToken) {
  const host = process.env.SMTP_HOST;
  const text = [
    'You requested a password reset for Spendly.',
    '',
    'Open the app → Reset password, and paste this code within 1 hour:',
    '',
    resetToken,
    '',
  ].join('\n');

  if (!host) {
    app.log.info(
      { email: to },
      'password reset email skipped (SMTP_HOST not set); token logged below for development',
    );
    app.log.info(`Reset token for ${to}:\n${resetToken}`);
    return;
  }

  const transporter = nodemailer.createTransport({
    host,
    port: Number.parseInt(process.env.SMTP_PORT ?? '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    auth:
      process.env.SMTP_USER != null && process.env.SMTP_USER !== ''
        ? {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS ?? '',
          }
        : undefined,
  });

  await transporter.sendMail({
    from: process.env.SMTP_FROM ?? 'noreply@localhost',
    to,
    subject: 'Reset your Spendly password',
    text,
  });
}
