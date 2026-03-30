/**
 * FCM HTTP v1 API Integration for Node.js
 *
 * Uses service account authentication with JWT for secure messaging.
 * Sends notification+data messages for push notifications.
 */
import * as crypto from 'crypto';

interface ServiceAccountKey {
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
}

interface FCMResponse {
  success: boolean;
  messageId?: string;
  error?: string;
}

/**
 * Base64 URL encode (for JWT)
 */
function base64UrlEncode(data: string | Buffer): string {
  let base64: string;
  if (typeof data === 'string') {
    base64 = Buffer.from(data).toString('base64');
  } else {
    base64 = data.toString('base64');
  }
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * Generate JWT for FCM HTTP v1 API authentication
 */
async function generateFCMAccessToken(
  serviceAccount: ServiceAccountKey
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + 3600; // 1 hour expiry

  const header = {
    alg: 'RS256',
    typ: 'JWT',
    kid: serviceAccount.private_key_id,
  };

  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: exp,
  };

  // Create JWT
  const headerB64 = base64UrlEncode(JSON.stringify(header));
  const payloadB64 = base64UrlEncode(JSON.stringify(payload));
  const signatureInput = `${headerB64}.${payloadB64}`;

  // Sign with RSA-SHA256
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(signatureInput);
  const signature = sign.sign(serviceAccount.private_key);

  const signatureB64 = base64UrlEncode(signature);
  const jwt = `${headerB64}.${payloadB64}.${signatureB64}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  if (!tokenResponse.ok) {
    const error = await tokenResponse.text();
    throw new Error(`Failed to get access token: ${error}`);
  }

  const tokenData = (await tokenResponse.json()) as { access_token: string };
  return tokenData.access_token;
}

/**
 * Send FCM notification + data message.
 * The notification payload lets FCM display the notification directly,
 * while the data payload enables deep linking when tapped.
 */
export async function sendFCMMessage(
  token: string,
  data: Record<string, string>,
  serviceAccount: ServiceAccountKey
): Promise<FCMResponse> {
  try {
    const accessToken = await generateFCMAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    // Extract title/body for notification display, rest goes to data
    const { title, body, ...restData } = data;
    const notificationTitle = title || 'Obsession Tracker';
    const notificationBody = body || '';

    const message = {
      message: {
        token: token,
        // Notification payload - FCM displays this directly
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        // Data payload - passed to app for deep linking
        data: restData,
        android: {
          priority: 'high' as const,
          notification: {
            sound: 'default',
            channelId: 'obsession_announcements',
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      },
    };

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      }
    );

    if (response.ok) {
      const result = (await response.json()) as { name: string };
      return { success: true, messageId: result.name };
    } else {
      const error = await response.text();
      console.error('FCM error:', error);

      // Check for invalid token errors
      if (error.includes('UNREGISTERED') || error.includes('INVALID_ARGUMENT')) {
        return { success: false, error: 'INVALID_TOKEN' };
      }

      return { success: false, error };
    }
  } catch (e) {
    console.error('FCM exception:', e);
    return { success: false, error: String(e) };
  }
}

/**
 * Send FCM message to multiple tokens (batch)
 * Returns statistics about successful and failed sends.
 */
export async function sendFCMBatch(
  tokens: string[],
  data: Record<string, string>,
  serviceAccount: ServiceAccountKey
): Promise<{
  sent: number;
  failed: number;
  invalidTokens: string[];
  errors: string[];
}> {
  const results = await Promise.all(
    tokens.map(async (token) => {
      const result = await sendFCMMessage(token, data, serviceAccount);
      return { token, ...result };
    })
  );

  const sent = results.filter((r) => r.success).length;
  const failed = results.filter((r) => !r.success).length;
  const invalidTokens = results
    .filter((r) => r.error === 'INVALID_TOKEN')
    .map((r) => r.token);
  const errors = results
    .filter((r) => !r.success && r.error !== 'INVALID_TOKEN')
    .map((r) => r.error || 'Unknown error')
    .slice(0, 10); // Limit error list

  return { sent, failed, invalidTokens, errors };
}
