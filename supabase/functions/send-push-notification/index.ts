import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APNS_KEY_ID      = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID     = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY") ?? "";
const BUNDLE_ID        = "com.tunahan.leaf";

const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

Deno.serve(async (req: Request) => {
  try {
    const record = await req.json();
    const { sender_id, conversation_id, content } = record;
    if (!sender_id || !conversation_id || !content) {
      return new Response("missing fields", { status: 400 });
    }

    console.log(`[Push] Mesaj alindi — sender: ${sender_id}, conv: ${conversation_id}`);
    console.log(`[Push] KEY_ID: ${APNS_KEY_ID ? APNS_KEY_ID.substring(0,4)+'...' : 'MISSING'}, TEAM_ID: ${APNS_TEAM_ID || 'MISSING'}`);

    const { data: conv } = await supabaseAdmin
      .from("conversations")
      .select("user_a_id, user_b_id")
      .eq("id", conversation_id)
      .single();
    if (!conv) return new Response("conv not found", { status: 404 });

    const receiver_id = conv.user_a_id === sender_id ? conv.user_b_id : conv.user_a_id;
    console.log(`[Push] Alici: ${receiver_id}`);

    const { data: senderProfile } = await supabaseAdmin
      .from("profiles")
      .select("username")
      .eq("id", sender_id)
      .single();
    const senderName = senderProfile?.username ?? "Birileri";

    // token hangi build'den geldiyse (Debug→sandbox, Release/TestFlight→production)
    // gönderim de ona göre yapılıyor — eskiden tek bir global APNS_ENV kullanılıyordu,
    // bu da dev/TestFlight karışık test senaryolarında bildirimlerin sessizce
    // başarısız olmasına sebep oluyordu
    const { data: tokens } = await supabaseAdmin
      .from("device_tokens")
      .select("token, environment")
      .eq("user_id", receiver_id);

    console.log(`[Push] Token sayisi: ${tokens?.length ?? 0}`);
    if (!tokens || tokens.length === 0) return new Response("no tokens", { status: 200 });

    if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY) {
      console.error("[Push] APNs env vars eksik!");
      return new Response("apns not configured", { status: 500 });
    }

    const jwt = await createApnsJwt();

    const results = await Promise.all(tokens.map(({ token, environment }) =>
      sendApns(jwt, environment, token, senderName, content, conversation_id)
    ));
    console.log(`[Push] Sonuclar: ${JSON.stringify(results)}`);

    return new Response(JSON.stringify({ ok: true, results }), { status: 200 });
  } catch (e) {
    console.error("[Push] Genel hata:", e);
    return new Response("error", { status: 500 });
  }
});

async function createApnsJwt(): Promise<string> {
  const header  = { alg: "ES256", kid: APNS_KEY_ID };
  const payload = { iss: APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) };

  const b64url = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const message = `${b64url(header)}.${b64url(payload)}`;

  const rawKey = APNS_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");

  const keyBuffer = Uint8Array.from(atob(rawKey), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBuffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(message)
  );

  const encodedSig = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  return `${message}.${encodedSig}`;
}

async function sendApns(
  jwt: string,
  environment: string,
  deviceToken: string,
  senderName: string,
  body: string,
  conversationId: string
): Promise<{ token: string; status: number; response: string }> {
  const host = environment === "sandbox"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
  const url = `https://${host}/3/device/${deviceToken}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": BUNDLE_ID,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: { title: senderName, body },
        sound: "default",
        badge: 1,
      },
      conversation_id: conversationId,
      sender_username: senderName,
    }),
  });
  const text = await res.text();
  if (!res.ok) {
    console.error(`[Push] APNs hata ${res.status}: ${text}`);
  } else {
    console.log(`[Push] APNs basarili: ${res.status}`);
  }
  return { token: deviceToken.substring(0, 8) + "...", status: res.status, response: text };
}
