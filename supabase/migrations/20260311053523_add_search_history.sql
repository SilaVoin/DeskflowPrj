create table if not exists public.search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  query_text text not null,
  normalized_query text not null,
  last_used_at timestamp with time zone not null default now(),
  created_at timestamp with time zone not null default now(),
  constraint search_history_user_id_normalized_query_key unique (
    user_id,
    normalized_query
  )
);

create index if not exists idx_search_history_user_last_used
  on public.search_history (user_id, last_used_at desc);

alter table public.search_history enable row level security;

drop policy if exists "Users can read own search history" on public.search_history;
create policy "Users can read own search history"
  on public.search_history
  for select
  using (((select auth.uid() as uid) is not null) and ((select auth.uid() as uid) = user_id));

drop policy if exists "Users can insert own search history" on public.search_history;
create policy "Users can insert own search history"
  on public.search_history
  for insert
  with check (((select auth.uid() as uid) is not null) and ((select auth.uid() as uid) = user_id));

drop policy if exists "Users can update own search history" on public.search_history;
create policy "Users can update own search history"
  on public.search_history
  for update
  using (((select auth.uid() as uid) is not null) and ((select auth.uid() as uid) = user_id))
  with check (((select auth.uid() as uid) is not null) and ((select auth.uid() as uid) = user_id));

drop policy if exists "Users can delete own search history" on public.search_history;
create policy "Users can delete own search history"
  on public.search_history
  for delete
  using (((select auth.uid() as uid) is not null) and ((select auth.uid() as uid) = user_id));
