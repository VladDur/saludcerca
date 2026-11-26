-- =====================================================================
-- SaludCerca · Sprints 2 y 3 · Esquema de base de datos (Supabase / PostgreSQL)
-- Rol único de la app: USUARIO (autenticado con Supabase Auth).
-- Ejecutar completo en: Supabase → SQL Editor → New query → Run.
-- El script es idempotente: se puede volver a ejecutar sin errores.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABLAS
-- ---------------------------------------------------------------------

-- Perfil del usuario (1 a 1 con auth.users).
create table if not exists public.perfiles (
  id                           uuid primary key references auth.users (id) on delete cascade,
  nombre_completo              text not null check (char_length(nombre_completo) between 3 and 80),
  telefono                     text check (telefono is null or telefono ~ '^[0-9+\- ]{7,15}$'),
  ciudad                       text not null default 'La Paz' check (ciudad in ('La Paz', 'El Alto')),
  contacto_emergencia_nombre   text check (contacto_emergencia_nombre is null or char_length(contacto_emergencia_nombre) <= 80),
  contacto_emergencia_telefono text check (contacto_emergencia_telefono is null or contacto_emergencia_telefono ~ '^[0-9+\- ]{7,15}$'),
  activo                       boolean not null default true,
  creado_en                    timestamptz not null default now(),
  actualizado_en               timestamptz not null default now()
);

-- Catálogo de centros de salud (solo lectura para el USUARIO).
create table if not exists public.centros_salud (
  id                  uuid primary key default gen_random_uuid(),
  nombre              text not null,
  tipo                text not null check (tipo in ('hospital', 'centro_salud', 'posta')),
  ciudad              text not null check (ciudad in ('La Paz', 'El Alto')),
  zona                text not null,
  direccion           text not null,
  telefono            text not null,
  latitud             double precision not null,
  longitud            double precision not null,
  abierto_24h         boolean not null default false,
  hora_apertura       time,
  hora_cierre         time,
  dias_atencion       smallint[] not null default '{1,2,3,4,5}', -- 1 = lunes ... 7 = domingo
  atiende_emergencias boolean not null default false,
  descripcion         text not null default '',
  activo              boolean not null default true,
  creado_en           timestamptz not null default now(),
  constraint uq_centro_nombre unique (nombre)
);

-- Catálogo de servicios (Pediatría, Vacunas, ...).
create table if not exists public.servicios (
  id     serial primary key,
  nombre text not null unique
);

-- Relación N a M: qué servicios ofrece cada centro.
create table if not exists public.centro_servicios (
  centro_id   uuid not null references public.centros_salud (id) on delete cascade,
  servicio_id int  not null references public.servicios (id) on delete cascade,
  primary key (centro_id, servicio_id)
);

-- Centros favoritos del usuario (con nota personal). Baja lógica con "activo".
create table if not exists public.favoritos (
  id             uuid primary key default gen_random_uuid(),
  usuario_id     uuid not null references public.perfiles (id) on delete cascade,
  centro_id      uuid not null references public.centros_salud (id) on delete cascade,
  nota           text not null default '' check (char_length(nota) <= 200),
  activo         boolean not null default true,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  constraint uq_favorito unique (usuario_id, centro_id)
);

-- Recordatorios de citas, medicamentos o controles. Baja lógica con "activo".
create table if not exists public.recordatorios (
  id             uuid primary key default gen_random_uuid(),
  usuario_id     uuid not null references public.perfiles (id) on delete cascade,
  centro_id      uuid references public.centros_salud (id) on delete set null,
  titulo         text not null check (char_length(titulo) between 3 and 60),
  descripcion    text not null default '' check (char_length(descripcion) <= 250),
  tipo           text not null default 'cita' check (tipo in ('cita', 'medicamento', 'control')),
  fecha_hora     timestamptz not null,
  activo         boolean not null default true,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index if not exists idx_favoritos_usuario     on public.favoritos (usuario_id) where activo;
create index if not exists idx_recordatorios_usuario on public.recordatorios (usuario_id, fecha_hora) where activo;
create index if not exists idx_centros_ciudad        on public.centros_salud (ciudad) where activo;

-- ---------------------------------------------------------------------
-- 2. FUNCIONES Y TRIGGERS
-- ---------------------------------------------------------------------

-- Actualiza "actualizado_en" en cada UPDATE.
create or replace function public.tocar_actualizado_en()
returns trigger language plpgsql as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

drop trigger if exists trg_perfiles_actualizado on public.perfiles;
create trigger trg_perfiles_actualizado before update on public.perfiles
  for each row execute function public.tocar_actualizado_en();

drop trigger if exists trg_favoritos_actualizado on public.favoritos;
create trigger trg_favoritos_actualizado before update on public.favoritos
  for each row execute function public.tocar_actualizado_en();

drop trigger if exists trg_recordatorios_actualizado on public.recordatorios;
create trigger trg_recordatorios_actualizado before update on public.recordatorios
  for each row execute function public.tocar_actualizado_en();

-- Crea el perfil automáticamente cuando alguien se registra en Supabase Auth.
-- El nombre llega en los metadatos del registro (options.data.nombre_completo).
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, nombre_completo)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nombre_completo'), ''), split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_crear_perfil on auth.users;
create trigger trg_crear_perfil after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

-- ---------------------------------------------------------------------
-- 3. VISTA para la pantalla de Inicio (centro + lista de servicios)
-- security_invoker = true: la vista respeta el RLS de quien consulta.
-- ---------------------------------------------------------------------
create or replace view public.v_centros
with (security_invoker = true) as
select
  c.*,
  coalesce(array_agg(s.nombre order by s.nombre) filter (where s.id is not null), '{}') as servicios
from public.centros_salud c
left join public.centro_servicios cs on cs.centro_id = c.id
left join public.servicios s on s.id = cs.servicio_id
where c.activo
group by c.id;

-- ---------------------------------------------------------------------
-- 4. SEGURIDAD: Row Level Security (RLS)
-- Regla general: cada usuario solo ve y modifica SUS filas.
-- No hay políticas DELETE: la app usa baja lógica (activo = false).
-- ---------------------------------------------------------------------
alter table public.perfiles         enable row level security;
alter table public.centros_salud    enable row level security;
alter table public.servicios        enable row level security;
alter table public.centro_servicios enable row level security;
alter table public.favoritos        enable row level security;
alter table public.recordatorios    enable row level security;

-- perfiles
drop policy if exists "perfil: ver el propio" on public.perfiles;
create policy "perfil: ver el propio" on public.perfiles
  for select to authenticated using (id = auth.uid());

drop policy if exists "perfil: crear el propio" on public.perfiles;
create policy "perfil: crear el propio" on public.perfiles
  for insert to authenticated with check (id = auth.uid());

drop policy if exists "perfil: editar el propio" on public.perfiles;
create policy "perfil: editar el propio" on public.perfiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- catálogos: lectura solo para usuarios autenticados
drop policy if exists "centros: lectura autenticados" on public.centros_salud;
create policy "centros: lectura autenticados" on public.centros_salud
  for select to authenticated using (activo);

drop policy if exists "servicios: lectura autenticados" on public.servicios;
create policy "servicios: lectura autenticados" on public.servicios
  for select to authenticated using (true);

drop policy if exists "centro_servicios: lectura autenticados" on public.centro_servicios;
create policy "centro_servicios: lectura autenticados" on public.centro_servicios
  for select to authenticated using (true);

-- favoritos
drop policy if exists "favoritos: ver los propios" on public.favoritos;
create policy "favoritos: ver los propios" on public.favoritos
  for select to authenticated using (usuario_id = auth.uid());

drop policy if exists "favoritos: crear los propios" on public.favoritos;
create policy "favoritos: crear los propios" on public.favoritos
  for insert to authenticated with check (usuario_id = auth.uid());

drop policy if exists "favoritos: editar los propios" on public.favoritos;
create policy "favoritos: editar los propios" on public.favoritos
  for update to authenticated using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());

-- recordatorios
drop policy if exists "recordatorios: ver los propios" on public.recordatorios;
create policy "recordatorios: ver los propios" on public.recordatorios
  for select to authenticated using (usuario_id = auth.uid());

drop policy if exists "recordatorios: crear los propios" on public.recordatorios;
create policy "recordatorios: crear los propios" on public.recordatorios
  for insert to authenticated with check (usuario_id = auth.uid());

drop policy if exists "recordatorios: editar los propios" on public.recordatorios;
create policy "recordatorios: editar los propios" on public.recordatorios
  for update to authenticated using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());

-- Permisos de tabla (RLS filtra las filas; sin DELETE para el rol authenticated).
revoke all on public.perfiles, public.centros_salud, public.servicios, public.centro_servicios,
              public.favoritos, public.recordatorios from anon;
revoke delete on public.perfiles, public.favoritos, public.recordatorios from authenticated;
grant select on public.centros_salud, public.servicios, public.centro_servicios, public.v_centros to authenticated;
grant select, insert, update on public.perfiles, public.favoritos, public.recordatorios to authenticated;
revoke all on public.v_centros from anon;

-- =====================================================================
-- SPRINT 3 · HU-03 Farmacias de turno
-- Catálogos de solo lectura para el USUARIO (los cargará el panel web del
-- ADMINISTRADOR en una etapa posterior; por ahora, seed.sql).
-- =====================================================================

-- Farmacias de La Paz y El Alto.
create table if not exists public.farmacias (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null,
  ciudad     text not null check (ciudad in ('La Paz', 'El Alto')),
  zona       text not null,
  direccion  text not null,
  telefono   text not null,
  latitud    double precision not null check (latitud between -90 and 90),
  longitud   double precision not null check (longitud between -180 and 180),
  activo     boolean not null default true,
  creado_en  timestamptz not null default now(),
  constraint uq_farmacia_nombre unique (nombre)
);

-- Consulta de medicamentos por WhatsApp: celular con código de país, sin "+"
-- ni espacios (591 + 8 dígitos). Vacío = la farmacia no atiende por chat.
-- Los números reales no se guardan en seed.sql: se asignan en el SQL Editor.
alter table public.farmacias
  add column if not exists whatsapp text
  check (whatsapp ~ '^591[67][0-9]{7}$');

-- Turnos (1 farmacia → N turnos). Un turno empieza el día "fecha" a la
-- hora_inicio y termina al día siguiente a la hora_fin (turno de 24 h).
create table if not exists public.turnos_farmacia (
  id          uuid primary key default gen_random_uuid(),
  farmacia_id uuid not null references public.farmacias (id) on delete cascade,
  fecha       date not null,
  hora_inicio time not null default '08:00',
  hora_fin    time not null default '08:00',
  activo      boolean not null default true,
  creado_en   timestamptz not null default now(),
  constraint uq_turno_farmacia_fecha unique (farmacia_id, fecha)
);

create index if not exists idx_turnos_fecha on public.turnos_farmacia (fecha) where activo;
create index if not exists idx_farmacias_ciudad on public.farmacias (ciudad) where activo;

alter table public.farmacias       enable row level security;
alter table public.turnos_farmacia enable row level security;

drop policy if exists "farmacias: lectura autenticados" on public.farmacias;
create policy "farmacias: lectura autenticados" on public.farmacias
  for select to authenticated using (activo);

drop policy if exists "turnos: lectura autenticados" on public.turnos_farmacia;
create policy "turnos: lectura autenticados" on public.turnos_farmacia
  for select to authenticated using (activo);

-- Solo lectura: sin INSERT/UPDATE/DELETE para usuarios; nada para anon.
revoke all on public.farmacias, public.turnos_farmacia from anon;
revoke insert, update, delete on public.farmacias, public.turnos_farmacia from authenticated;
grant select on public.farmacias, public.turnos_farmacia to authenticated;
