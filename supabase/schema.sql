-- TonyLocuras Entreno · esquema de Supabase
-- Pega TODO este archivo en Supabase > SQL Editor > New query > Run.
-- Es idempotente: puedes ejecutarlo más de una vez.

-- ============================================================ Tablas

create table if not exists public.profiles (
  uid uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('athlete','coach','client')),
  name text not null default '',
  birth date,
  guardian_name text default '',
  guardian_consent boolean not null default false,
  consent_at timestamptz,
  consent_version text default '',
  created_at timestamptz not null default now()
);

-- Tabla genérica de datos. Una fila por registro de la app.
create table if not exists public.records (
  owner uuid not null references auth.users(id) on delete cascade,
  col text not null,
  id text not null,
  json jsonb not null,
  updated timestamptz not null default now(),
  deleted boolean not null default false,
  primary key (owner, col, id)
);
create index if not exists records_owner_updated on public.records (owner, updated);

create table if not exists public.coach_links (
  coach uuid not null references auth.users(id) on delete cascade,
  client uuid not null references auth.users(id) on delete cascade,
  class_id text default '',
  created_at timestamptz not null default now(),
  primary key (coach, client)
);

create table if not exists public.invites (
  code text primary key,
  coach uuid not null references auth.users(id) on delete cascade,
  class_id text default '',
  note text default '',
  created_at timestamptz not null default now(),
  used_by uuid references auth.users(id),
  used_at timestamptz
);


-- El servidor fija "updated" (cursor de sincronización), sin depender del reloj del móvil.
create or replace function public.set_updated() returns trigger language plpgsql as $$
begin new.updated = now(); return new; end $$;
drop trigger if exists records_set_updated on public.records;
create trigger records_set_updated before insert or update on public.records
  for each row execute function public.set_updated();

-- ============================================================ RLS

alter table public.profiles enable row level security;
alter table public.records enable row level security;
alter table public.coach_links enable row level security;
alter table public.invites enable row level security;

-- profiles
drop policy if exists profiles_self_select on public.profiles;
create policy profiles_self_select on public.profiles for select using (uid = auth.uid());
drop policy if exists profiles_coach_select on public.profiles;
create policy profiles_coach_select on public.profiles for select using (
  exists (select 1 from public.coach_links l where l.coach = auth.uid() and l.client = profiles.uid)
);
drop policy if exists profiles_self_insert on public.profiles;
create policy profiles_self_insert on public.profiles for insert with check (uid = auth.uid());
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles for update using (uid = auth.uid());

-- records: el dueño lo ve y lo escribe todo
drop policy if exists records_owner_all on public.records;
create policy records_owner_all on public.records for all
  using (owner = auth.uid()) with check (owner = auth.uid());

-- records: el entrenador vinculado LEE todo lo del cliente...
drop policy if exists records_coach_select on public.records;
create policy records_coach_select on public.records for select using (
  exists (select 1 from public.coach_links l where l.coach = auth.uid() and l.client = records.owner)
);
-- ...y solo ESCRIBE plan, mensajes y notas de entrenador en los datos del cliente
drop policy if exists records_coach_insert on public.records;
create policy records_coach_insert on public.records for insert with check (
  col in ('plan','messages','coachnotes')
  and exists (select 1 from public.coach_links l where l.coach = auth.uid() and l.client = records.owner)
);
drop policy if exists records_coach_update on public.records;
create policy records_coach_update on public.records for update using (
  col in ('plan','messages','coachnotes')
  and exists (select 1 from public.coach_links l where l.coach = auth.uid() and l.client = records.owner)
);

-- coach_links: lo ven ambas partes; cualquiera de los dos puede romper el vínculo
drop policy if exists links_select on public.coach_links;
create policy links_select on public.coach_links for select using (coach = auth.uid() or client = auth.uid());
drop policy if exists links_delete on public.coach_links;
create policy links_delete on public.coach_links for delete using (coach = auth.uid() or client = auth.uid());

-- invites: solo el entrenador dueño
drop policy if exists invites_select on public.invites;
create policy invites_select on public.invites for select using (coach = auth.uid());
drop policy if exists invites_insert on public.invites;
create policy invites_insert on public.invites for insert with check (
  coach = auth.uid()
  and exists (select 1 from public.profiles p where p.uid = auth.uid() and p.role = 'coach')
);
drop policy if exists invites_delete on public.invites;
create policy invites_delete on public.invites for delete using (coach = auth.uid() and used_by is null);

-- ============================================================ Funciones (RPC)

-- Un cliente canjea un código y queda vinculado al entrenador.
create or replace function public.redeem_invite(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare inv public.invites; coach_name text;
begin
  if not exists (select 1 from public.profiles where uid = auth.uid() and role = 'client') then
    raise exception 'Solo una cuenta de cliente puede canjear un código';
  end if;
  select * into inv from public.invites where code = upper(trim(p_code)) and used_by is null;
  if not found then raise exception 'Código no válido o ya usado'; end if;
  insert into public.coach_links (coach, client, class_id) values (inv.coach, auth.uid(), coalesce(inv.class_id, ''))
    on conflict (coach, client) do update set class_id = excluded.class_id;
  update public.invites set used_by = auth.uid(), used_at = now() where code = inv.code;
  select name into coach_name from public.profiles where uid = inv.coach;
  return json_build_object('coach', inv.coach, 'coach_name', coach_name, 'class_id', inv.class_id);
end $$;

-- El entrenador lista sus clientes.
create or replace function public.my_clients()
returns table (uid uuid, name text, birth date, guardian_consent boolean, class_id text, linked_at timestamptz)
language sql security definer set search_path = public as $$
  select p.uid, p.name, p.birth, p.guardian_consent, l.class_id, l.created_at
  from public.coach_links l join public.profiles p on p.uid = l.client
  where l.coach = auth.uid()
  order by p.name;
$$;

-- El cliente ve quién es su entrenador.
create or replace function public.my_coach()
returns table (uid uuid, name text)
language sql security definer set search_path = public as $$
  select p.uid, p.name from public.coach_links l join public.profiles p on p.uid = l.coach
  where l.client = auth.uid();
$$;

-- Borra TODOS los datos del usuario (derecho de supresión) sin borrar la cuenta.
create or replace function public.erase_my_data()
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.records where owner = auth.uid();
  delete from public.coach_links where client = auth.uid();
end $$;

-- ============================================================ Storage (documentos)

insert into storage.buckets (id, name, public) values ('docs', 'docs', false)
  on conflict (id) do nothing;

drop policy if exists docs_owner_all on storage.objects;
create policy docs_owner_all on storage.objects for all
  using (bucket_id = 'docs' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'docs' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists docs_coach_select on storage.objects;
create policy docs_coach_select on storage.objects for select using (
  bucket_id = 'docs'
  and exists (
    select 1 from public.coach_links l
    where l.coach = auth.uid() and l.client::text = (storage.foldername(name))[1]
  )
);
