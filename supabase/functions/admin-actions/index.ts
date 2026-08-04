// admin-actions/index.ts
// Ban/unban/oturum-sonlandırma gibi GoTrue admin API gerektiren işlemler burada —
// service_role anahtarı sadece burada, sunucu tarafında duruyor, hiçbir client'a gitmiyor.
// Çağıranın admin olduğu her istekte JWT üzerinden doğrulanıyor.
//
// Not: supabase-js'in auth.admin.* yardımcıları esm.sh + Deno kombinasyonunda
// anlamsız hatalar veriyordu (String(e) === "{}"), o yüzden admin işlemlerini
// doğrudan REST çağrısıyla yapıyoruz — daha az katman, daha kolay debug.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// is_admin() SQL fonksiyonuyla aynı id — admin sayısı artarsa ikisini birlikte güncelle
const ADMIN_ID = "e5fa72d0-7b3b-430a-9e42-43ebafc3cffb";

type Action = "ban" | "unban" | "signout" | "list";

// admin-app tarayıcıdan çağırıyor — CORS olmadan istek daha ağa çıkmadan reddedilir
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

async function adminFetch(path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      ...init.headers,
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");

    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false }
    });
    const { data: userData, error: userErr } = await callerClient.auth.getUser(jwt);

    if (userErr || userData.user?.id !== ADMIN_ID) {
      return json({ error: "Yetkisiz" }, 403);
    }

    const { action, userId } = (await req.json()) as { action: Action; userId?: string };

    if (!["ban", "unban", "signout", "list"].includes(action)) {
      return json({ error: "Geçersiz istek" }, 400);
    }
    if (action !== "list" && !userId) {
      return json({ error: "userId gerekli" }, 400);
    }

    if (action === "list") {
      const res = await adminFetch("/auth/v1/admin/users?page=1&per_page=1000");
      if (!res.ok) {
        const body = await res.text();
        return json({ error: `listUsers başarısız: ${res.status} ${body}` }, 500);
      }
      const data = await res.json();
      const users = (data.users ?? []).map((u: { id: string; email?: string; banned_until?: string }) => ({
        id: u.id,
        email: u.email ?? null,
        bannedUntil: u.banned_until ?? null,
      }));
      return json({ users });
    }

    if (action === "ban" || action === "unban") {
      const res = await adminFetch(`/auth/v1/admin/users/${userId}`, {
        method: "PUT",
        body: JSON.stringify({ ban_duration: action === "ban" ? "876000h" : "none" }),
      });
      if (!res.ok) {
        const body = await res.text();
        return json({ error: `${action} başarısız: ${res.status} ${body}` }, 500);
      }

      if (action === "ban") {
        // askıya alırken açık oturumları da düşür — access token süresi
        // dolana kadar (en fazla ~1 saat) yine de geçerli kalabilir
        await adminFetch("/rest/v1/rpc/admin_force_signout", {
          method: "POST",
          body: JSON.stringify({ target_user_id: userId }),
        }).catch(() => {});
      }
    } else {
      const res = await adminFetch("/rest/v1/rpc/admin_force_signout", {
        method: "POST",
        body: JSON.stringify({ target_user_id: userId }),
      });
      if (!res.ok) {
        const body = await res.text();
        return json({ error: `signout başarısız: ${res.status} ${body}` }, 500);
      }
    }

    return json({ ok: true });
  } catch (e) {
    console.error(e);
    const err = e as { message?: string } | undefined;
    return json({ error: err?.message ?? String(e) }, 500);
  }
});
