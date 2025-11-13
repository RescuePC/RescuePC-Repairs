// Multi-provider email service for RescuePC license delivery
// Supports Resend API or SMTP (e.g. MailerSend) based on environment variables

import nodemailer from "nodemailer";
import type SMTPTransport from "nodemailer/lib/smtp-transport";
import { Resend } from "resend";
import { config } from "./config";

type EmailPayload = {
  to: string;
  subject: string;
  html: string;
  text?: string;
};

const defaultFrom = config.email.fromName
  ? `${config.email.fromName} <${config.email.fromEmail}>`
  : config.email.fromEmail;

let smtpTransport:
  | nodemailer.Transporter<SMTPTransport.SentMessageInfo>
  | null = null;
let resendClient: Resend | null = null;

const ensureSendingEnabled = () => {
  if (!config.email.sendingEnabled) {
    console.warn("Email delivery disabled by configuration.");
    return false;
  }
  return true;
};

const hasResendProvider = (): boolean =>
  Boolean(config.email.resendApiKey?.length);

const hasSmtpProvider = (): boolean =>
  Boolean(
    config.email.smtpHost &&
      config.email.smtpUser &&
      config.email.smtpPass
  );

const getResendClient = (): Resend => {
  if (!hasResendProvider()) {
    throw new Error("Resend API key is not configured.");
  }
  if (!resendClient) {
    resendClient = new Resend(config.email.resendApiKey);
  }
  return resendClient;
};

const getSmtpTransport = () => {
  if (!hasSmtpProvider()) {
    throw new Error("SMTP credentials are not configured.");
  }
  if (!smtpTransport) {
    smtpTransport = nodemailer.createTransport({
      host: config.email.smtpHost,
      port: config.email.smtpPort,
      secure: config.email.smtpSecure,
      auth: {
        user: config.email.smtpUser,
        pass: config.email.smtpPass,
      },
    });
  }
  return smtpTransport;
};

const sendViaResend = (payload: EmailPayload) => {
  const resend = getResendClient();
  return resend.emails.send({
    from: defaultFrom,
    to: payload.to,
    subject: payload.subject,
    html: payload.html,
    text: payload.text,
    reply_to: config.email.replyTo || undefined,
  });
};

const sendViaSmtp = (payload: EmailPayload) => {
  const transport = getSmtpTransport();
  return transport.sendMail({
    from: defaultFrom,
    to: payload.to,
    subject: payload.subject,
    html: payload.html,
    text: payload.text,
    replyTo: config.email.replyTo || undefined,
  });
};

const deliverEmail = async (payload: EmailPayload) => {
  if (!ensureSendingEnabled()) {
    return { skipped: true };
  }

  if (hasResendProvider()) {
    return sendViaResend(payload);
  }

  if (hasSmtpProvider()) {
    return sendViaSmtp(payload);
  }

  throw new Error(
    "No email provider configured. Set RESEND_API_KEY or SMTP_* environment variables."
  );
};

export interface LicenseEmailOptions {
  to: string;
  licenseKey: string;
  product: string;
  amountCents: number;
  currency: string;
}

export async function sendLicenseEmail(opts: LicenseEmailOptions) {
  const amount = (opts.amountCents / 100).toFixed(2);

  const html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Your RescuePC License</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #1e40af, #3b82f6); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: white; padding: 30px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; }
        .license-key { background: #f8fafc; border: 2px solid #e2e8f0; padding: 15px; border-radius: 6px; font-family: monospace; font-size: 18px; font-weight: bold; color: #1e40af; text-align: center; margin: 20px 0; }
        .button { display: inline-block; background: #1e40af; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: 600; margin: 10px 0; }
        .button:hover { background: #1d4ed8; }
        .details { background: #f8fafc; padding: 20px; border-radius: 6px; margin: 20px 0; }
        .details p { margin: 8px 0; }
        .footer { text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; color: #6b7280; font-size: 14px; }
        ol { padding-left: 20px; }
        li { margin: 8px 0; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Welcome to RescuePC!</h1>
        <p>Your automated Windows repair toolkit is ready</p>
      </div>

      <div class="content">
        <p>Thank you for your purchase! Here are your license details:</p>

        <div class="license-key">
          ${opts.licenseKey}
        </div>

        <div class="details">
          <p><strong>Product:</strong> ${opts.product}</p>
          <p><strong>Amount:</strong> $${amount} ${opts.currency.toUpperCase()}</p>
          <p><strong>License Type:</strong> Perpetual License</p>
        </div>

        <div style="text-align: center; margin: 30px 0;">
          <a href="https://rescuepcrepairs.com/download" class="button">Download RescuePC</a>
        </div>

        <h3>How to Activate Your License</h3>
        <ol>
          <li>Download and install RescuePC Repairs from the link above</li>
          <li>Launch the application</li>
          <li>Enter your license key when prompted</li>
          <li>Use the email address from this purchase (${opts.to})</li>
        </ol>

        <p><strong>Important:</strong> Keep this license key safe. You'll need it to activate the software.</p>

        <div class="footer">
          <p>Need help? Contact our support team at <a href="mailto:support@rescuepcrepairs.com">support@rescuepcrepairs.com</a></p>
          <p>&copy; ${new Date().getFullYear()} RescuePC. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
  `;

  return deliverEmail({
    to: opts.to,
    subject: "Your RescuePC License Key",
    html,
  });
}

export async function sendErrorNotification(error: string, eventId: string) {
  const html = `
    <h2>License Generation Error</h2>
    <p><strong>Event ID:</strong> ${eventId}</p>
    <p><strong>Error:</strong> ${error}</p>
    <p>Please check the webhook logs and database for more details.</p>
  `;

  const alertRecipient = config.email.alertTo;

  return deliverEmail({
    to: alertRecipient,
    subject: "RescuePC License Generation Error",
    html,
  });
}
