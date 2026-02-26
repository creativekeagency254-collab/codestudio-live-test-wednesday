/*
  Allow clients to explicitly verify their own projects after payment confirmation.
*/

begin;

alter table public.projects
  add column if not exists client_verified boolean not null default false,
  add column if not exists client_verified_at timestamptz,
  add column if not exists client_verified_by uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'projects'
      and c.conname = 'projects_client_verified_by_fkey'
  ) then
    alter table public.projects
      add constraint projects_client_verified_by_fkey
      foreign key (client_verified_by)
      references public.profiles(id)
      on delete set null;
  end if;
end $$;

create index if not exists idx_projects_client_verified on public.projects(client_verified);
create index if not exists idx_projects_client_verified_at on public.projects(client_verified_at);

update public.projects p
set
  client_verified = true,
  client_verified_at = coalesce(p.client_verified_at, now()),
  client_verified_by = coalesce(p.client_verified_by, p.client_id)
where coalesce(p.client_verified, false) = false
  and exists (
    select 1
    from public.invoices i
    where i.project_id = p.id
      and lower(coalesce(i.status, '')) = 'paid'
  );

commit;

