// get-profile-photo/index.ts
// Aşamalı fotoğraf açmanın asıl uygulandığı yer burası: hangi varyantın (hiç/blur/orijinal)
// gösterileceğine client değil, conversations tablosundaki gerçek eşleşme/onay durumuna
// bakarak sunucu karar veriyor. Client sadece dönen signed URL'i gösterir.

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

    const { target_user_id: targetId } = (await req.json()) as { target_user_id?: string };
    const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!targetId || !UUID_RE.test(targetId)) {
      // targetId asagida .or() ile ham bir PostgREST filtre string'ine gomuluyor;
      // gecerli bir uuid oldugunu burada garanti etmezsek filtre enjeksiyonuna acik olur.
      return json({ error: "target_user_id gecersiz" }, 400);
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Normal kullanimi (kart acma, mesajlasma) hic etkilemeyecek kadar genis bir
    // limit; amac scriptli reveal-stage enumeration'i engellemek.
    const { data: withinLimit } = await admin.rpc("check_rate_limit", {
      p_user_id: callerId,
      p_action: "get_profile_photo",
      p_max_count: 30,
      p_window_seconds: 10,
    });
    if (withinLimit === false) {
      return json({ error: "Çok fazla istek, birazdan tekrar deneyin" }, 429);
    }

    const { data: targetProfile } = await admin
      .from("profiles")
      .select("photo_original_path, photo_blurred_path")
      .eq("id", targetId)
      .single();

    if (!targetProfile?.photo_original_path) {
      return json({ stage: "none" satisfies Stage, url: null });
    }

    // kendi fotoğrafın her zaman tam açık
    if (targetId === callerId) {
      const { data: signed } = await admin.storage
        .from("profile-photos")
        .createSignedUrl(targetProfile.photo_original_path, SIGNED_URL_TTL_SECONDS);
      return json({ stage: "revealed" satisfies Stage, url: signed?.signedUrl ?? null });
    }

    const { data: blockedPair } = await admin.rpc("is_blocked_pair", { a: callerId, b: targetId });
    if (blockedPair) {
      return json({ stage: "hidden" satisfies Stage, url: null });
    }

    const { data: conv } = await admin
      .from("conversations")
      .select("user_a_id, user_a_photo_confirmed, user_b_photo_confirmed")
      .or(`and(user_a_id.eq.${callerId},user_b_id.eq.${targetId}),and(user_a_id.eq.${targetId},user_b_id.eq.${callerId})`)
      .maybeSingle();

    // Aralarında eşleşme (conversation) yoksa Keşfet kart aşamasındayız — bulanık
    // önizleme gösteriliyor (aşağıdaki blurred fallback'e düşer), reveal ikonu client
    // tarafında zaten sadece conversationId verildiğinde çıkıyor, kartlarda hiç çıkmaz.
    let bothConfirmed = false;
    if (conv) {
      const callerIsUserA = conv.user_a_id === callerId;
      const callerConfirmed = callerIsUserA ? conv.user_a_photo_confirmed : conv.user_b_photo_confirmed;
      const targetConfirmed = callerIsUserA ? conv.user_b_photo_confirmed : conv.user_a_photo_confirmed;
      bothConfirmed = callerConfirmed && targetConfirmed;
    }

    if (bothConfirmed) {
      const { data: signed } = await admin.storage
        .from("profile-photos")
        .createSignedUrl(targetProfile.photo_original_path, SIGNED_URL_TTL_SECONDS);
      return json({ stage: "revealed" satisfies Stage, url: signed?.signedUrl ?? null });
    }

    if (targetProfile.photo_blurred_path) {
      const { data: signed } = await admin.storage
        .from("profile-photos")
        .createSignedUrl(targetProfile.photo_blurred_path, SIGNED_URL_TTL_SECONDS);
      return json({ stage: "blurred" satisfies Stage, url: signed?.signedUrl ?? null });
    }

    return json({ stage: "none" satisfies Stage, url: null });
  } catch (e) {
    console.error(e);
    const err = e as { message?: string } | undefined;
    return json({ error: err?.message ?? String(e) }, 500);
  }
});
