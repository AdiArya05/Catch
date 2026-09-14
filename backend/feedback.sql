-- Run once in a new Supabase project's SQL editor.
create table public.feedback (
  id uuid primary key,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 10 and 4000),
  status text not null default 'received' check (status in ('received','accepted','in progress','completed')),
  published boolean not null default false,
  developer_response text,
  created_at timestamptz not null default now()
);
create index feedback_author_created on public.feedback(author_id, created_at desc);
alter table public.feedback enable row level security;
revoke all on public.feedback from anon, authenticated;
grant select(id,body,status,developer_response,created_at) on public.feedback to authenticated;
create policy feedback_read on public.feedback for select to authenticated
using (published or author_id = (select auth.uid()));

-- Only this function may create feedback. Clients cannot set status/replies/publication.
create function public.submit_feedback(message text, request_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := auth.uid();
  previous public.feedback;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if message is null or char_length(trim(message)) not between 10 and 4000 then
    raise exception 'Message must contain 10–4000 characters';
  end if;
  -- Serialize per author so simultaneous submissions cannot bypass the hourly limit.
  perform pg_advisory_xact_lock(hashtextextended(caller::text, 0));
  select * into previous from public.feedback where id = request_id;
  if found then
    if previous.author_id = caller and previous.body = trim(message) then return request_id; end if;
    raise exception 'Request conflicts with an existing submission';
  end if;
  if (select count(*) from public.feedback where author_id = caller and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Please wait before sending more feedback';
  end if;
  insert into public.feedback(id, author_id, body) values(request_id, caller, trim(message));
  return request_id;
end;
$$;
revoke all on function public.submit_feedback(text, uuid) from public, anon;
grant execute on function public.submit_feedback(text, uuid) to authenticated;
