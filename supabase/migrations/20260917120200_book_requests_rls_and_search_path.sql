-- book_requests: RLS acikti ama hic policy yoktu, yani ozellik kimse icin
-- calismiyordu (admin dahil). Kullanicilar kendi isteklerini ekleyip/gorebilsin,
-- admin da katalog ihtiyaci icin hepsini gorebilsin.
create policy book_requests_select on public.book_requests
  for select using (user_id = auth.uid() or is_admin());

create policy book_requests_insert on public.book_requests
  for insert with check (user_id = auth.uid());

create policy book_requests_delete on public.book_requests
  for delete using (user_id = auth.uid() or is_admin());

-- search_path mutable uyarisi (Supabase linter WARN): bu iki fonksiyonda
-- explicit search_path yoktu, sema enjeksiyonu riskine karsi ekliyoruz.
create or replace function public.increment_book_catalog(p_title text, p_author text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  UPDATE book_catalog
  SET added_count = added_count + 1
  WHERE title = p_title AND author = p_author;
END;
$function$;

create or replace function public.update_device_token_timestamp()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$function$;
