-- Genel amacli, hafif bir rate limit mekanizmasi: sabit zaman penceresi (fixed window)
-- sayaci. Amac normal kullanimi hic etkilememek, sadece scriptli/otomatik istismari
-- (foto reveal-stage enumeration, upload spam) engellemek.
create table if not exists public.rate_limit_buckets (
  user_id      uuid not null,
  action       text not null,
  window_start timestamptz not null,
  count        int not null default 0,
  primary key (user_id, action, window_start)
);

alter table public.rate_limit_buckets enable row level security;
-- Hicbir policy yok: sadece service_role (edge function'lar) erisebilir.

create or replace function public.check_rate_limit(
  p_user_id uuid,
  p_action text,
  p_max_count int,
  p_window_seconds int
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_window timestamptz;
  v_count int;
begin
  v_window := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);

  insert into public.rate_limit_buckets (user_id, action, window_start, count)
  values (p_user_id, p_action, v_window, 1)
  on conflict (user_id, action, window_start)
  do update set count = rate_limit_buckets.count + 1
  returning count into v_count;

  -- eski pencereleri firsat buldukca temizle (ayri bir cron job'a gerek kalmasin diye)
  if random() < 0.01 then
    delete from public.rate_limit_buckets where window_start < now() - interval '1 hour';
  end if;

  return v_count <= p_max_count;
end;
$function$;
