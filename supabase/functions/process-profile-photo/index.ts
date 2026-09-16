// process-profile-photo/index.ts
// Kullanıcı ham JPEG baytlarını doğrudan body'de gönderiyor (ayrı bir staging bucket'a
// gerek yok). Burada hem orijinal hem de gerçekten bulanıklaştırılmış bir kopya
// üretilip private "profile-photos" bucket'ına yazılıyor — blur işlemi sunucuda
// oluyor ki client hiçbir zaman "blur'u ben uygularım" diyerek orijinali indiremesin.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Image } from "https://deno.land/x/imagescript@1.3.0/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const MAX_UPLOAD_BYTES = 15 * 1024 * 1024; // decode/blur oncesi DoS'a karsi ust sinir
const MAX_DIMENSION = 800;   // BookStore.resizedAndCompressed ile aynı yaklaşım
const BLUR_RADIUS = 14;      // "hafif blur" — kişi seçilebiliyor ama detaylar gizli
const SIGNED_URL_TTL_SECONDS = 300; // get-profile-photo ile aynı süre

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function resizedJpeg(bytes: Uint8Array): Promise<{ image: Image; jpeg: Uint8Array }> {
  const image = await Image.decode(bytes);
  const longestSide = Math.max(image.width, image.height);
  if (longestSide > MAX_DIMENSION) {
    if (image.width >= image.height) {
      image.resize(MAX_DIMENSION, Image.RESIZE_AUTO);
    } else {
      image.resize(Image.RESIZE_AUTO, MAX_DIMENSION);
    }
  }
  const jpeg = await image.encodeJPEG(85);
  return { image, jpeg };
}

// imagescript@1.3.0'da hazır bir blur metodu YOK (Image sınıfının kaynağında "blur"
// kelimesi bile geçmiyor) — bu yüzden eski kod `image.blur()` çağırınca runtime'da
// "TypeError: blur is not a function" ile patlıyordu ve hiçbir fotoğraf hiç
// kaydedilmiyordu. Burada ayrılabilir (separable) bir box blur'u doğrudan
// bitmap (Uint8ClampedArray, RGBA) üzerinde elle uyguluyoruz.
function boxBlur(image: Image, radius: number): void {
  if (radius < 1) return;
  const { width, height, bitmap } = image;
  const channels = 4;
  const src = new Uint8ClampedArray(bitmap);
  const temp = new Uint8ClampedArray(bitmap.length);

  // yatay geçiş
  for (let y = 0; y < height; y++) {
    const rowOffset = y * width;
    for (let x = 0; x < width; x++) {
      let r = 0, g = 0, b = 0, a = 0, count = 0;
      const minX = Math.max(0, x - radius);
      const maxX = Math.min(width - 1, x + radius);
      for (let nx = minX; nx <= maxX; nx++) {
        const idx = (rowOffset + nx) * channels;
        r += src[idx]; g += src[idx + 1]; b += src[idx + 2]; a += src[idx + 3];
        count++;
      }
      const idx = (rowOffset + x) * channels;
      temp[idx] = r / count;
      temp[idx + 1] = g / count;
      temp[idx + 2] = b / count;
      temp[idx + 3] = a / count;
    }
  }

  // dikey geçiş
  for (let x = 0; x < width; x++) {
    for (let y = 0; y < height; y++) {
      let r = 0, g = 0, b = 0, a = 0, count = 0;
      const minY = Math.max(0, y - radius);
      const maxY = Math.min(height - 1, y + radius);
      for (let ny = minY; ny <= maxY; ny++) {
        const idx = (ny * width + x) * channels;
        r += temp[idx]; g += temp[idx + 1]; b += temp[idx + 2]; a += temp[idx + 3];
        count++;
      }
      const idx = (y * width + x) * channels;
      bitmap[idx] = r / count;
      bitmap[idx + 1] = g / count;
      bitmap[idx + 2] = b / count;
      bitmap[idx + 3] = a / count;
    }
  }
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
    const uid = userData.user.id;

    const rawBytes = new Uint8Array(await req.arrayBuffer());
    if (rawBytes.length === 0) {
      return json({ error: "Boş görsel" }, 400);
    }
    if (rawBytes.length > MAX_UPLOAD_BYTES) {
      // Image.decode() boyut/format kontrolu olmadan calisiyordu; buyuk/bozuk
      // payload'lar decode/blur asamasinda bellek/CPU tuketimine yol acabilirdi.
      return json({ error: "Görsel çok büyük (maksimum 15MB)" }, 413);
    }

    const { jpeg: originalJpeg } = await resizedJpeg(rawBytes);

    // Blur'u ayrı bir decode üzerinden uyguluyoruz ki orijinal encode edilmiş
    // hali (original.jpg) hiç bulanıklaştırma geçirmeden saklansın.
    const blurredImage = await Image.decode(originalJpeg);
    boxBlur(blurredImage, BLUR_RADIUS);
    const blurredJpeg = await blurredImage.encodeJPEG(80);

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const originalPath = `${uid}/original.jpg`;
    const blurredPath = `${uid}/blurred.jpg`;

    const [originalUpload, blurredUpload] = await Promise.all([
      admin.storage.from("profile-photos").upload(originalPath, originalJpeg, {
        contentType: "image/jpeg",
        upsert: true,
      }),
      admin.storage.from("profile-photos").upload(blurredPath, blurredJpeg, {
        contentType: "image/jpeg",
        upsert: true,
      }),
    ]);

    if (originalUpload.error || blurredUpload.error) {
      const err = originalUpload.error ?? blurredUpload.error;
      return json({ error: `Yükleme başarısız: ${err?.message}` }, 500);
    }

    const { error: updateErr } = await admin
      .from("profiles")
      .update({ photo_original_path: originalPath, photo_blurred_path: blurredPath })
      .eq("id", uid);

    if (updateErr) {
      return json({ error: `Profil güncellenemedi: ${updateErr.message}` }, 500);
    }

    // Client kendi fotoğrafı için "revealed" URL'ini doğrudan burada alsın diye —
    // yoksa ayrıca get-profile-photo'yu çağırması gerekirdi, bu da yükleme sonrası
    // görselin ekranda görünmesini gereksiz yere geciktiriyordu.
    const { data: signed } = await admin.storage
      .from("profile-photos")
      .createSignedUrl(originalPath, SIGNED_URL_TTL_SECONDS);

    return json({ ok: true, url: signed?.signedUrl ?? null });
  } catch (e) {
    console.error(e);
    const err = e as { message?: string } | undefined;
    return json({ error: err?.message ?? String(e) }, 500);
  }
});
