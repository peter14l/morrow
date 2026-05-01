import sgMail from '@sendgrid/mail';

sgMail.setApiKey(process.env.SENDGRID_API_KEY || '');

// This MUST be the email address you verified in SendGrid "Single Sender Verification"
export const EMAIL_FROM = 'Oasis <oasis.officialsupport@gmail.com>';

export async function sendConfirmationEmail(userEmail: string) {
  try {
    // Email sending disabled as per request
    console.log('Confirmation email would have been sent to:', userEmail);
    return { success: true };
  } catch (error: any) {
    console.error('SendGrid Error:', error.response?.body || error);
    return { success: false, error };
  }
}

export async function sendLaunchEmail(userEmail: string) {
  try {
    // Email sending disabled as per request
    console.log('Launch email would have been sent to:', userEmail);
    return { success: true };
  } catch (error: any) {
    console.error('SendGrid Error:', error.response?.body || error);
    return { success: false, error };
  }
}
