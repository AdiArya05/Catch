create table if not exists public.feedback_votes (
  feedback_id uuid not null references public.feedback(id) on delete cascade,
  voter_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (feedback_id, voter_id)
);

create index if not exists feedback_votes_voter_created
on public.feedback_votes(voter_id, created_at desc);

alter table public.feedback_votes enable row level security;
revoke all on public.feedback_votes from anon, authenticated;

create or replace function public.feedback_feed()
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

create or replace function public.toggle_feedback_upvote(feedback_id uuid)
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
