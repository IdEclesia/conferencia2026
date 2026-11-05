-- Conferencia "Instrumentos en las Manos del Redentor" · tabla de inscripciones
-- Pegar en Supabase > SQL Editor > Run

create table if not exists public.inscripciones (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  nombre text not null check (char_length(nombre) between 2 and 120),
  email text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  iglesia text not null check (char_length(iglesia) between 2 and 120),
  plenarias text[] not null default '{}',
  viene_acompanado boolean not null default false,
  adultos_acomp int not null default 0 check (adultos_acomp between 0 and 30),
  trae_ninos boolean not null default false,
  cant_ninos int not null default 0 check (cant_ninos between 0 and 30),
  edades_ninos text check (char_length(edades_ninos) <= 300),
  regalo_enviado boolean not null default false
);

-- Un correo = una inscripción
create unique index if not exists inscripciones_email_uq on public.inscripciones (lower(email));

alter table public.inscripciones enable row level security;

-- El público solo puede ANOTARSE (insertar). No puede leer, editar ni borrar.
drop policy if exists "publico_inserta" on public.inscripciones;
create policy "publico_inserta" on public.inscripciones
  for insert to anon with check (regalo_enviado = false);

-- Lista de administradores autorizados (por correo). Funciona aunque el proyecto
-- Supabase tenga otros usuarios registrados (por ejemplo, la plataforma de cursos).
create table if not exists public.admins (email text primary key);
alter table public.admins enable row level security;  -- sin policies: nadie la lee desde la web

create or replace function public.es_admin() returns boolean
language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.admins where lower(email) = lower(auth.jwt() ->> 'email'));
$$;

drop policy if exists "admin_lee" on public.inscripciones;
create policy "admin_lee" on public.inscripciones for select to authenticated using (public.es_admin());
drop policy if exists "admin_edita" on public.inscripciones;
create policy "admin_edita" on public.inscripciones for update to authenticated using (public.es_admin()) with check (public.es_admin());
drop policy if exists "admin_borra" on public.inscripciones;
create policy "admin_borra" on public.inscripciones for delete to authenticated using (public.es_admin());

-- Agregá a cada administrador (ya debe existir como usuario en Authentication > Users):
-- insert into public.admins (email) values ('correo-admin@ejemplo.com');
