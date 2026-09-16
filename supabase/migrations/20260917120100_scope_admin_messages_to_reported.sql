-- admin_select_messages politikasi is_admin() = true olan kullaniciya TUM mesajlari
-- (raporlanmis olsun olmasin) okuma izni veriyordu. Bu, moderasyon ihtiyacinin
-- cok otesinde bir gizlilik riski: admin, hic sikayet edilmemis konusmalari da
-- okuyabiliyordu.
--
-- Duzeltme: admin sadece fiilen bir sikayete konu olan mesaji gorebilir
-- (admin-app zaten sadece raporlanan mesaj id'lerini cekiyor, davranis degismiyor).
drop policy if exists admin_select_messages on public.messages;

create policy admin_select_messages on public.messages
  for select using (
    is_admin()
    and exists (
      select 1 from public.user_reports r
      where r.message_id = messages.id
    )
  );
