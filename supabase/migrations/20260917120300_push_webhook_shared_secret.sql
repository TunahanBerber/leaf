-- send-push / send-push-notification edge function'lari hicbir auth kontrolu
-- yapmiyordu: sender_id, receiver_id, sender_username, content dogrudan
-- request body'den aliniyor, caller'in gercekten o mesaj/istegin sahibi
-- oldugu hic dogrulanmiyordu. Anon key elinde olan herhangi bir kullanici
-- (uygulamaya gomulu oldugu icin herkeste var) baska bir kullanici gibi
-- gorunerek key istedigi kullaniciya key istedigi icerikte push gonderebiliyordu.
--
-- Cozum: bu fonksiyonlar sadece bizim kendi trigger'larimizdan (mesaj/istek
-- insert edildiginde) cagrilmali. Trigger ile edge function arasinda, hicbir
-- client'in bilemeyecegi paylasilan bir secret koyuyoruz; edge function bu
-- secret'i dogrulamadan hicbir push göndermiyor.
create table if not exists public.internal_webhook_secrets (
  key   text primary key,
  value text not null
);

alter table public.internal_webhook_secrets enable row level security;
-- Bilerek hicbir policy eklenmiyor: PostgREST uzerinden (anon/authenticated)
-- bu tabloya kimse erisemez. Sadece service_role (edge function'larda) ve
-- SECURITY DEFINER trigger fonksiyonlari (owner olarak RLS'i bypass eder) okuyabilir.

insert into public.internal_webhook_secrets (key, value)
values ('push_webhook_secret', encode(gen_random_bytes(32), 'hex'))
on conflict (key) do nothing;

create or replace function public.notify_push_on_message()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_secret text;
begin
  select value into v_secret from public.internal_webhook_secrets where key = 'push_webhook_secret';

  PERFORM net.http_post(
      url     := 'https://qowvamowkmysdjrnhkkb.supabase.co/functions/v1/send-push-notification',
      headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvd3ZhbW93a215c2Rqcm5oa2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4NDE5MzQsImV4cCI6MjA5MDQxNzkzNH0.BsAg0sjHdvJ3WOFv2HaM9J4Z7RkNWfgyXObOYRPfVpI',
          'x-webhook-secret', v_secret
      ),
      body    := to_jsonb(NEW)
  );
  RETURN NEW;
END;
$function$;

create or replace function public.trigger_request_notification()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
  declare
    v_sender_username text;
    v_secret text;
  begin
    select username into v_sender_username
    from public.profiles
    where id = NEW.sender_id;

    select value into v_secret from public.internal_webhook_secrets where key = 'push_webhook_secret';

    begin
      perform net.http_post(
        url     := 'https://qowvamowkmysdjrnhkkb.supabase.co/functions/v1/send-push',
        body    := jsonb_build_object(
          'type', 'request',
          'recipient_id', NEW.receiver_id::text,
          'sender_username', coalesce(v_sender_username, 'Biri')
        ),
        params  := '{}'::jsonb,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvd3ZhbW93a215c2Rqcm5oa2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4NDE5MzQsImV4cCI6MjA5MDQxNzkzNH0.BsAg0sjHdvJ3WOFv2HaM9J4Z7RkNWfgyXObOYRPfVpI',
          'x-webhook-secret', v_secret
        )
      );
    exception when others then
      null;
    end;

    return NEW;
  end;
$function$;
