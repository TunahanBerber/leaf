import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!; // .p8 dosyasının içeriği
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;     // com.tunahan.leaf
const APNS_PRODUCTION = Deno.env.get("APNS_PRODUCTION") === "true";

// APNs JWT oluştur (ES256)
async function buildApnsJwt(): Promise<string> {
  const encoder = new TextEncoder();

  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const payload = { iss: APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) };

  const toB64 = (obj: object) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const signingInput = `${toB64(header)}.${toB64(payload)}`;

  const pemBody = APNS_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput)
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${signingInput}.${sigB64}`;
}

async function sendApns(
  deviceToken: string,
  aps: object,
  extra: Record<string, string>
) {
  const host = APNS_PRODUCTION
    ? "api.push.apple.com"
    : "api.sandbox.push.apple.com";

  const jwt = await buildApnsJwt();

  const body = JSON.stringify({ aps, ...extra });

  const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body,
  });

  if (!res.ok) {
    const err = await res.text();
    console.error("[APNs] Hata:", res.status, err);
  }
}

Deno.serve(async (req) => {
  try {
    const { type, recipient_id, sender_username, conversation_id } =
      await req.json();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Alıcının cihaz tokenini çek
    const { data: tokenRow } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", recipient_id)
      .maybeSingle();

    if (!tokenRow?.token) {
      return new Response("No device token", { status: 200 });
    }

    if (type === "request") {
      await sendApns(
        tokenRow.token,
        {
          alert: {
            title: "SocialLeaf",
            body: `${sender_username} sana sohbet isteği gönderdi`,
          },
          sound: "default",
          badge: 1,
        },
        { type: "request", sender_username }
      );
    } else {
      // type === "message"
      await sendApns(
        tokenRow.token,
        {
          alert: {
            title: sender_username,
            body: "Yeni bir mesaj gönderdi",
          },
          sound: "default",
          badge: 1,
        },
        { type: "message", conversation_id, sender_username }
      );
    }

    return new Response("OK", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response("Error", { status: 500 });
  }
});
