create table if not exists public.order_templates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  items jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint order_templates_items_is_array
    check (jsonb_typeof(items) = 'array')
);

create index if not exists order_templates_organization_updated_idx
  on public.order_templates (organization_id, updated_at desc);

create or replace function public.set_order_templates_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_order_templates_updated_at on public.order_templates;

create trigger set_order_templates_updated_at
before update on public.order_templates
for each row
execute function public.set_order_templates_updated_at();

alter table public.order_templates enable row level security;

grant select, insert, update, delete on public.order_templates to authenticated;
revoke all on public.order_templates from anon;

drop policy if exists "Members can read order templates" on public.order_templates;
create policy "Members can read order templates"
on public.order_templates
for select
to authenticated
using (
  exists (
    select 1
    from public.organization_members om
    where om.organization_id = order_templates.organization_id
      and om.user_id = (select auth.uid())
  )
);

drop policy if exists "Members can insert order templates" on public.order_templates;
create policy "Members can insert order templates"
on public.order_templates
for insert
to authenticated
with check (
  exists (
    select 1
    from public.organization_members om
    where om.organization_id = order_templates.organization_id
      and om.user_id = (select auth.uid())
  )
);

drop policy if exists "Members can update order templates" on public.order_templates;
create policy "Members can update order templates"
on public.order_templates
for update
to authenticated
using (
  exists (
    select 1
    from public.organization_members om
    where om.organization_id = order_templates.organization_id
      and om.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.organization_members om
    where om.organization_id = order_templates.organization_id
      and om.user_id = (select auth.uid())
  )
);

drop policy if exists "Members can delete order templates" on public.order_templates;
create policy "Members can delete order templates"
on public.order_templates
for delete
to authenticated
using (
  exists (
    select 1
    from public.organization_members om
    where om.organization_id = order_templates.organization_id
      and om.user_id = (select auth.uid())
  )
);
