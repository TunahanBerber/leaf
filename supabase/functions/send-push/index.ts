import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!; // .p8 dosyasının içeriği
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;     // com.tunahan.leaf

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
  environment: string,
  aps: object,
  extra: Record<string, string>
): Promise<{ host: string; status: number; response: string }> {
  // token hangi build'den geldiyse (Debug→sandbox, Release/TestFlight→production)
  // host da ona göre seçiliyor — tek bir global ortam varsaymak, karışık
  // dev/TestFlight test senaryolarında bildirimlerin sessizce başarısız
  // olmasına sebep oluyordu
  const host = environment === "sandbox"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";

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

  const text = await res.text();
  if (!res.ok) {
    console.error("[APNs] Hata:", res.status, text);
  } else {
    console.log("[APNs] Basarili:", res.status);
  }
  // sonucu response'a da yansıtıyoruz — pg_net'in net._http_response tablosundan
  // APNs'in gerçek cevabını görebilmek için (debug: bildirim gitmiyor sorunları)
  return { host, status: res.status, response: text };
}

Deno.serve(async (req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Bu fonksiyon sadece trigger_request_notification DB trigger'i tarafindan
    // cagrilmali. Herkeste bulunan anon key ile dogrudan cagrilip baska
    // kullanicilar adina sahte push gonderilmesini engellemek icin, sadece
    // trigger'in bildigi paylasilan secret ile calisiyor.
    const providedSecret = req.headers.get("x-webhook-secret");
    const { data: secretRow } = await supabase
      .from("internal_webhook_secrets")
      .select("value")
      .eq("key", "push_webhook_secret")
      .maybeSingle();
    if (!secretRow?.value || providedSecret !== secretRow.value) {
      return new Response("unauthorized", { status: 401 });
    }

    const { type, recipient_id, sender_username, conversation_id } =
      await req.json();

    // Alıcının cihaz tokenini ve hangi APNs ortamından geldiğini çek
    const { data: tokenRow } = await supabase
      .from("device_tokens")
      .select("token, environment")
      .eq("user_id", recipient_id)
      .maybeSingle();

    if (!tokenRow?.token) {
      return new Response("No device token", { status: 200 });
    }

    let result;
    if (type === "request") {
      result = await sendApns(
        tokenRow.token,
        tokenRow.environment,
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
      result = await sendApns(
        tokenRow.token,
        tokenRow.environment,
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

    return new Response(
      JSON.stringify({ ok: result.status < 300, environment: tokenRow.environment, ...result }),
      { status: 200, headers: { "content-type": "application/json" } }
    );
  } catch (e) {
    console.error(e);
    return new Response("Error", { status: 500 });
  }
});
