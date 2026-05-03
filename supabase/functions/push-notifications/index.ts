import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SECRET_KEY") || '';
const supabaseUrl = Deno.env.get("SUPABASE_URL") || '';
const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID") || '';

let firebaseServiceAccount: any = null;
try {
  const accountStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (accountStr) {
    firebaseServiceAccount = JSON.parse(accountStr);
  }
} catch (e) {
  console.error("Failed to parse FIREBASE_SERVICE_ACCOUNT JSON. Make sure it is a valid JSON string.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  
  const authHeader = req.headers.get('Authorization');
  console.log(`[Push Request] Auth Header present: ${!!authHeader}`);

  try {
    // 0. AUTHENTICATION & VALIDATION
    if (!authHeader) {
      console.error("[Push Auth] Error: Missing Authorization header");
      throw new Error('No authorization header');
    }

    const token = authHeader.replace(/bearer /i, '').trim();
    const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    const secretKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SECRET_KEY");

    // Diagnostic logging
    console.log(`[Push Auth] Token (first 5): ${token.substring(0, 5)}... Length: ${token.length}`);
    console.log(`[Push Auth] Available Env Vars: ${Object.keys(Deno.env.toObject()).filter(k => k.includes('SUPABASE') || k.includes('KEY')).join(', ')}`);
    console.log(`[Push Auth] Keys Found - Pub: ${!!publishableKey} (${publishableKey?.length}), Sec: ${!!secretKey} (${secretKey?.length})`);

    // We verify if the request comes from our own database trigger (using modern secret or publishable key)
    const matchesSecret = !!secretKey && token === secretKey;
    const matchesPub = !!publishableKey && token === publishableKey;

    if (!matchesSecret && !matchesPub) {
      console.error(`[Push Auth] Mismatch! Token is not a valid modern Secret or Publishable key.`);
      throw new Error(`Unauthorized: Key Mismatch (T:${token.length} S:${secretKey?.length} P:${publishableKey?.length})`);
    }
    console.log(`[Push Auth] Validated via modern ${matchesSecret ? 'Secret' : 'Publishable'} key.`);

    const payload = await req.json();    const { record } = payload; 

    if (!record || !record.user_id || !record.type) {
      console.error("Invalid payload structure:", payload);
      throw new Error('Invalid notification payload');
    }

    console.log(`Processing ${record.type} notification for user: ${record.user_id}`);
    
    if (!firebaseServiceAccount) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT is missing. Please set this in your Supabase secrets.');
    }

    // 1. SAFETY CHECK: Ensure not blocked or muted (Backup for DB trigger)
    // A. Check if recipient blocked actor
    const { data: blockData } = await supabase
      .from('blocked_users')
      .select('id')
      .eq('blocker_id', record.user_id)
      .eq('blocked_id', record.actor_id)
      .maybeSingle();

    if (blockData) {
      return new Response(JSON.stringify({ message: "Recipient has blocked actor" }), { status: 200 });
    }

    // B. Check if conversation is muted (for DMs)
    if (record.type === 'dm' && record.message_id) {
      // Get conversation_id
      const { data: msgData } = await supabase
        .from('messages')
        .select('conversation_id')
        .eq('id', record.message_id)
        .single();

      if (msgData) {
        const { data: participant } = await supabase
          .from('conversation_participants')
          .select('is_muted')
          .eq('conversation_id', msgData.conversation_id)
          .eq('user_id', record.user_id)
          .maybeSingle();

        if (participant?.is_muted) {
          return new Response(JSON.stringify({ message: "Conversation is muted" }), { status: 200 });
        }
      }
    }

    // 2. Get recipient profile (for FCM token)
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('fcm_token, username')
      .eq('id', record.user_id)
      .single();

    if (profileError || !profile?.fcm_token) {
      return new Response(JSON.stringify({ message: "No token found" }), { status: 200 });
    }

    // 2. Get actor profile (sender)
    const { data: actor, error: actorError } = await supabase
      .from('profiles')
      .select('username')
      .eq('id', record.actor_id)
      .single();

    const actorName = actor?.username || "Someone";
    let title = "New Notification";
    let body = record.content || "";

    // 3. Customize based on type
    switch (record.type) {
      case 'dm':
        title = actorName;
        break;
      case 'like':
        title = "New Like";
        body = `${actorName} liked your post`;
        break;
      case 'comment':
        title = "New Comment";
        body = `${actorName} commented on your post`;
        break;
      case 'follow':
        title = "New Follower";
        body = `${actorName} started following you`;
        break;
      case 'follow_request':
        title = "Follow Request";
        body = `${actorName} sent you a follow request`;
        break;
      case 'call':
        // Parse call details from content (stored as JSON string)
        let callDetails = {};
        try {
          if (record.content) {
            callDetails = JSON.parse(record.content);
          }
        } catch (e) {
          // ignore parse error
        }
        const callType = callDetails['type'] || 'voice';
        const callId = callDetails['call_id'] || '';
        title = `Incoming ${callType === 'video' ? 'Video' : 'Voice'} Call`;
        body = `${actorName} is calling you`;
        // Add call-specific data for navigation
        record.call_id = callId;
        record.call_type = callType;
        break;
    }

    // 4. Get Google OAuth2 access token for FCM
    const accessToken = await getGoogleAccessToken(firebaseServiceAccount);

    // Build data payload - include conversation_id for DMs and sender info
    let dataPayload: Record<string, string> = {
      type: record.type,
      actor_id: record.actor_id,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    };

    // Add DM-specific data for deep linking
    if (record.type === 'dm' && record.message_id) {
      // Get sender info for deep linking
      const { data: senderProfile } = await supabase
        .from('profiles')
        .select('username, avatar_url')
        .eq('id', record.actor_id)
        .maybeSingle();

      if (senderProfile) {
        dataPayload['sender_name'] = senderProfile.username || '';
        dataPayload['sender_avatar'] = senderProfile.avatar_url || '';
      }

      // Get conversation_id from message
      const { data: msgData } = await supabase
        .from('messages')
        .select('conversation_id')
        .eq('id', record.message_id)
        .single();

      if (msgData) {
        dataPayload['conversation_id'] = msgData.conversation_id;
        dataPayload['sender_id'] = record.actor_id;
      }
    }

    // Add call-specific data
    if (record.call_id) {
      dataPayload['call_id'] = record.call_id;
      dataPayload['call_type'] = record.call_type || 'voice';
    }

    // 5. Build the final FCM payload
    // IMPORTANT: We use a "data-only" message (NO 'notification' block)
    // This ensures that the OS doesn't show a generic system notification,
    // and instead wakes up our Flutter background handler to decrypt and show it properly.
    
    // Add all metadata from the trigger payload to the FCM data payload
    if (payload.metadata) {
      for (const [key, value] of Object.entries(payload.metadata)) {
        if (value !== null && value !== undefined) {
          // FCM data values must be strings
          dataPayload[key] = typeof value === 'object' ? JSON.stringify(value) : value.toString();
        }
      }
    }

    // Add title and body to data so the background handler knows what to show if decryption fails
    dataPayload['title'] = title;
    dataPayload['body'] = body;

    const fcmPayload: any = {
      message: {
        token: profile.fcm_token,
        data: dataPayload,
        android: {
          priority: "high",
        },
        apns: {
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {
            aps: {
              contentAvailable: true,
              badge: 1,
              sound: "default",
              // Only include the OS-level notification block for iOS to wake it up when killed.
              // On Android, we rely on data-only messages to trigger the background handler
              // and show a custom notification with buttons (Like/Reply).
              alert: record.type !== 'call' ? {
                title: title,
                body: (body.length > 60 && !body.contains(' ')) ? 'New message' : body,
              } : undefined,
            },
          },
        },
      },
    };

    // 6. Send FCM message
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmPayload),
      }
    );

    const fcmResult = await fcmResponse.json();
    console.log("FCM Response:", fcmResult);
    return new Response(JSON.stringify(fcmResult), { status: 200 });

  } catch (error: any) {
    console.error("Push notification error:", error.message || error);
    return new Response(JSON.stringify({ error: error.message || "Unknown error" }), { status: 500 });
  }
});

async function getGoogleAccessToken(serviceAccount: any) {
  // Create JWT for Google OAuth2
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  // Encode header and claim
  const encodedHeader = b64url(JSON.stringify(header));
  const encodedClaim = b64url(JSON.stringify(claim));
  const payload = `${encodedHeader}.${encodedClaim}`;

  // Sign the JWT using Web Crypto API
  const signature = await signJwt(payload, serviceAccount.private_key);
  const jwt = `${payload}.${signature}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  if (!tokenResponse.ok) throw new Error(`Failed to get Google token: ${JSON.stringify(tokenData)}`);
  return tokenData.access_token;
}

async function signJwt(payload: string, privateKeyPem: string): Promise<string> {
  // Import the private key
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKeyPem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  // Sign the payload
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    privateKey,
    new TextEncoder().encode(payload)
  );

  // Convert to base64url
  return b64url(Array.from(new Uint8Array(signature)));
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  // Remove PEM header/footer and decode base64
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function b64url(input: string | number[]): string {
  let base64: string;
  if (typeof input === 'string') {
    base64 = btoa(input);
  } else {
    base64 = btoa(String.fromCharCode(...input));
  }
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}
