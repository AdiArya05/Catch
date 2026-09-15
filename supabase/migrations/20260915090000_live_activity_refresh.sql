create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

create table if not exists public.live_activity_subscriptions (
  activity_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  push_token text not null,
  stop_code text not null check (stop_code ~ '^[0-9]{5}$'),
  service_no text not null check (char_length(service_no) between 1 and 8),
  progress_started_at timestamptz not null,
  last_arrival_at timestamptz,
  environment text not null check (environment in ('sandbox', 'production')),
  expires_at timestamptz not null default (now() + interval '4 hours'),
  updated_at timestamptz not null default now()
);

alter table public.live_activity_subscriptions enable row level security;

create policy "owners can read live activity registrations"
on public.live_activity_subscriptions for select to authenticated
using (auth.uid() = user_id);

create policy "owners can insert live activity registrations"
on public.live_activity_subscriptions for insert to authenticated
with check (auth.uid() = user_id);

create policy "owners can update live activity registrations"
on public.live_activity_subscriptions for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owners can delete live activity registrations"
on public.live_activity_subscriptions for delete to authenticated
using (auth.uid() = user_id);

revoke all on public.live_activity_subscriptions from anon;
grant select, insert, update, delete on public.live_activity_subscriptions to authenticated;

-- The one-minute job is installed after LIVE_ACTIVITY_CRON_SECRET is saved in
-- both Supabase Edge Function secrets and Vault. See the function README.
