-- Run once in a new Supabase project's SQL editor.
create table public.feedback (
  id uuid primary key,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 10 and 4000),
  status text not null default 'received' check (status in ('received','accepted','in progress','completed')),
  published boolean not null default true,
  developer_response text,
  created_at timestamptz not null default now()
);
create index feedback_author_created on public.feedback(author_id, created_at desc);
alter table public.feedback enable row level security;
revoke all on public.feedback from anon, authenticated;
grant select(id,body,status,developer_response,created_at) on public.feedback to authenticated;
create policy feedback_read on public.feedback for select to authenticated
using (published or author_id = (select auth.uid()));

create table public.feedback_votes (
  feedback_id uuid not null references public.feedback(id) on delete cascade,
  voter_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (feedback_id, voter_id)
);
create index feedback_votes_voter_created on public.feedback_votes(voter_id, created_at desc);
alter table public.feedback_votes enable row level security;
revoke all on public.feedback_votes from anon, authenticated;

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
  insert into public.feedback(id, author_id, body, published) values(request_id, caller, trim(message), true);
  return request_id;
end;
$$;
revoke all on function public.submit_feedback(text, uuid) from public, anon;
grant execute on function public.submit_feedback(text, uuid) to authenticated;

create function public.feedback_feed()
returns table (
  id uuid,
  body text,
  status text,
  developer_response text,
  created_at timestamptz,
  upvote_count integer,
  did_upvote boolean
)
language sql
security definer
set search_path = ''
as $$
  select
    f.id,
    f.body,
    f.status,
    f.developer_response,
    f.created_at,
    coalesce(v.vote_count, 0)::integer as upvote_count,
    exists (
      select 1 from public.feedback_votes mine
      where mine.feedback_id = f.id and mine.voter_id = auth.uid()
    ) as did_upvote
  from public.feedback f
  left join (
    select feedback_id, count(*)::integer as vote_count
    from public.feedback_votes
    group by feedback_id
  ) v on v.feedback_id = f.id
  where f.published or f.author_id = auth.uid()
  order by f.created_at desc
  limit 100;
$$;
revoke all on function public.feedback_feed() from public, anon;
grant execute on function public.feedback_feed() to authenticated;

create function public.toggle_feedback_upvote(feedback_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  visible boolean;
  total integer;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  select exists (
    select 1 from public.feedback f
    where f.id = feedback_id and (f.published or f.author_id = caller)
  ) into visible;
  if not visible then raise exception 'Feedback not found'; end if;

  if exists (
    select 1 from public.feedback_votes
    where feedback_votes.feedback_id = toggle_feedback_upvote.feedback_id
      and voter_id = caller
  ) then
    delete from public.feedback_votes
    where feedback_votes.feedback_id = toggle_feedback_upvote.feedback_id
      and voter_id = caller;
  else
    insert into public.feedback_votes(feedback_id, voter_id)
    values(toggle_feedback_upvote.feedback_id, caller);
  end if;

  select count(*)::integer into total
  from public.feedback_votes
  where feedback_votes.feedback_id = toggle_feedback_upvote.feedback_id;
  return total;
end;
$$;
revoke all on function public.toggle_feedback_upvote(uuid) from public, anon;
grant execute on function public.toggle_feedback_upvote(uuid) to authenticated;
