// get-profile-photos/index.ts
// get-profile-photo'nun toplu (batch) hali: Discover kartları veya Mesajlar listesi
// gibi birden fazla kullanıcının fotoğrafı aynı anda gösterileceği yerlerde her avatar
// için ayrı ayrı Edge Function çağrısı yapmak yerine (N istek + zincirlenmiş DB
// sorguları → gözle görülür "önce avatar, sonra fotoğraf" gecikmesi) tek istekte
// tüm hedefler için stage/URL döndürüyoruz. Stage hesaplaması tek bir SQL RPC'sinde
// (photo_reveal_stages), signed URL'ler de tek bir Storage batch çağrısında üretiliyor.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const SIGNED_URL_TTL_SECONDS = 300;

type Stage = "hidden" | "none" | "blurred" | "revealed";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");

    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: userData, error: userErr } = await callerClient.auth.getUser(jwt);
    if (userErr || !userData.user) {
      return json({ error: "Yetkisiz" }, 401);
    }
    const callerId = userData.user.id;

    const { target_user_ids: targetIds } = (await req.json()) as { target_user_ids?: string[] };
    if (!targetIds || targetIds.length === 0) {
      return json({ results: {} });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Discover/mesaj listesi gibi toplu yerlerde normalde saniyede birkac kez
    // cagriliyor; bu limit sadece otomatik/scriptli enumeration'i engelliyor.
    const { data: withinLimit } = await admin.rpc("check_rate_limit", {
      p_user_id: callerId,
      p_action: "get_profile_photos",
      p_max_count: 20,
      p_window_seconds: 10,
    });
    if (withinLimit === false) {
      return json({ error: "Çok fazla istek, birazdan tekrar deneyin" }, 429);
    }

    // Stage hesaplaması auth.uid()'e bağlı (RPC içinde) — çağıranın kimliğini
    // service-role client'a JWT ile taşımamız gerekiyor, o yüzden burada da
    // callerClient üzerinden çağırıyoruz (RLS'siz ama auth.uid() dolu).
    const { data: rows, error: rpcErr } = await callerClient.rpc("photo_reveal_stages", {
      target_ids: targetIds,
    });
    if (rpcErr) {
      return json({ error: rpcErr.message }, 500);
    }

    const paths = (rows ?? [])
      .map((r: { path: string | null }) => r.path)
      .filter((p: string | null): p is string => !!p);

    let signedByPath: Record<string, string> = {};
    if (paths.length > 0) {
      const { data: signedList } = await admin.storage
        .from("profile-photos")
        .createSignedUrls(paths, SIGNED_URL_TTL_SECONDS);
      for (const s of signedList ?? []) {
        if (s.path && s.signedUrl) signedByPath[s.path] = s.signedUrl;
      }
    }

    const results: Record<string, { stage: Stage; url: string | null }> = {};
    for (const row of (rows ?? []) as { target_id: string; stage: Stage; path: string | null }[]) {
      results[row.target_id] = {
        stage: row.stage,
        url: row.path ? (signedByPath[row.path] ?? null) : null,
      };
    }

    return json({ results });
  } catch (e) {
    console.error(e);
    const err = e as { message?: string } | undefined;
    return json({ error: err?.message ?? String(e) }, 500);
  }
});
