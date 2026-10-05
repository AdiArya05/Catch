alter table public.feedback
alter column published set default true;

-- Catch's feedback board is community-visible. Existing pending submissions were
-- created under the old private-by-default behavior, so publish them as part of
-- the migration; moderators can still unpublish individual entries afterwards.
update public.feedback
set published = true
where published = false;

create or replace function public.submit_feedback(message text, request_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := auth.uid();
  previous public.feedback;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if message is null or char_length(trim(message)) not between 10 and 4000 then
    raise exception 'Message must contain 10–4000 characters';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(caller::text, 0));
  select * into previous from public.feedback where id = request_id;
  if found then
    if previous.author_id = caller and previous.body = trim(message) then return request_id; end if;
    raise exception 'Request conflicts with an existing submission';
  end if;
  if (select count(*) from public.feedback where author_id = caller and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Please wait before sending more feedback';
  end if;
  insert into public.feedback(id, author_id, body, published)
  values(request_id, caller, trim(message), true);
  return request_id;
end;
$$;

revoke all on function public.submit_feedback(text, uuid) from public, anon;
grant execute on function public.submit_feedback(text, uuid) to authenticated;
