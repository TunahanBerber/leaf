// admin-actions/index.ts
// Ban/unban/oturum-sonlandırma gibi GoTrue admin API gerektiren işlemler burada —
// service_role anahtarı sadece burada, sunucu tarafında duruyor, hiçbir client'a gitmiyor.
// Çağıranın admin olduğu her istekte JWT üzerinden doğrulanıyor.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// is_admin() SQL fonksiyonuyla aynı id — admin sayısı artarsa ikisini birlikte güncelle
const ADMIN_ID = "e5fa72d0-7b3b-430a-9e42-43ebafc3cffb";

type Action = "ban" | "unban" | "signout" | "list";

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");

    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await callerClient.auth.getUser(jwt);

    if (userErr || userData.user?.id !== ADMIN_ID) {
      return new Response(JSON.stringify({ error: "Yetkisiz" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { action, userId } = (await req.json()) as { action: Action; userId?: string };

    if (!["ban", "unban", "signout", "list"].includes(action)) {
      return new Response(JSON.stringify({ error: "Geçersiz istek" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
    if (action !== "list" && !userId) {
      return new Response(JSON.stringify({ error: "userId gerekli" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    if (action === "list") {
      const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
      if (error) throw error;

      const users = data.users.map((u) => ({
        id: u.id,
        email: u.email ?? null,
        bannedUntil: u.banned_until ?? null,
      }));

      return new Response(JSON.stringify({ users }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (action === "ban" || action === "unban") {
      const { error } = await admin.auth.admin.updateUserById(userId, {
        ban_duration: action === "ban" ? "876000h" : "none",
      });
      if (error) throw error;

      if (action === "ban") {
        // askıya alırken açık oturumları da düşür — access token süresi
        // dolana kadar (en fazla ~1 saat) yine de geçerli kalabilir
        await admin.rpc("admin_force_signout", { target_user_id: userId }).catch(() => {});
      }
    } else {
      const { error } = await admin.rpc("admin_force_signout", { target_user_id: userId });
      if (error) throw error;
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
