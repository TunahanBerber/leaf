-- delete_user_account(): sender_id/user_a_id/user_b_id/user_id kolonları uuid tipinde,
-- fonksiyon bunlari auth.uid()::text ile karsilastiriyordu -> "operator does not exist: uuid = text"
-- hatasi verip islemi rollback ediyordu, yani hesap silme istekleri sessizce basarisiz oluyordu.
-- Duzeltme: gereksiz ::text cast'lerini kaldiriyoruz.
create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  delete from public.messages
    where sender_id = auth.uid();
  delete from public.conversations
    where user_a_id = auth.uid()
       or user_b_id = auth.uid();
  delete from public.conversation_requests
    where sender_id   = auth.uid()
       or receiver_id = auth.uid();
  delete from public.device_tokens
    where user_id = auth.uid();
  delete from public.blocked_users
    where blocker_id = auth.uid()
       or blocked_id = auth.uid();
  delete from public.user_reports
    where reporter_id = auth.uid();
  delete from public.profiles
    where id = auth.uid();
  delete from auth.users
    where id = auth.uid();
end;
$function$;
