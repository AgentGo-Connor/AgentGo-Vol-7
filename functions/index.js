/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const nodemailer = require("nodemailer");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Create transporter using Gmail SMTP
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "info@agentgo.au",
    pass: "fsrj mqzl ifev qvjj",
  },
});

// Export the function with the exact name
exports.sendTeamInviteEmail = onCall({
  region: 'australia-southeast1',
  maxInstances: 10,
  enforceAppCheck: false,
  timeoutSeconds: 60,
  minInstances: 0,
  memory: '256MiB',
}, async (request) => {
  // Check if the user is authenticated
  if (!request.auth?.uid) {
    console.log('Authentication failed. Auth object:', request.auth);
    throw new HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  // Log App Check status
  console.log('App Check status:', request.app ? 'Valid' : 'Not present');
  
  console.log('User authenticated:', request.auth.uid);
  console.log('Received request with data:', request.data);
  
  const {inviteeEmail, inviterEmail, teamName, inviteLink, inviteId, teamId} = request.data;
  
  console.log('Preparing email for:', inviteeEmail);
  
  const mailOptions = {
    from: "AgentGo Team <info@agentgo.au>",
    to: inviteeEmail,
    subject: `You're invited to join ${teamName} on AgentGo`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Team Invitation</h2>
        <p style="color: #666;">
          ${inviterEmail} has invited you to join their team "${teamName}" on AgentGo.
        </p>
        <p style="color: #666;">Click the button below to accept the invitation:</p>
        <div style="text-align: center; margin: 30px 0;">
          <a href="${inviteLink}" 
             style="display: inline-block; padding: 12px 24px; 
                    background: #007AFF; color: white; 
                    text-decoration: none; border-radius: 6px;">
            Join Team
          </a>
        </div>
        <p style="color: #999; font-size: 14px;">
          This invite will expire in 7 days.
        </p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
        <p style="color: #999; font-size: 12px;">
          If you didn't request this invitation, you can safely ignore this email.
        </p>
      </div>
    `,
  };

  try {
    console.log('Attempting to send email...');
    await transporter.sendMail(mailOptions);
    console.log('Email sent successfully');
    return {success: true};
  } catch (error) {
    console.error("Error sending email:", error);
    throw new HttpsError("internal", `Error sending email: ${error.message}`);
  }
});
