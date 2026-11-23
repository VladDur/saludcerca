-- =====================================================================
-- SaludCerca · Sprint 2 · Datos de prueba
-- Ejecutar DESPUÉS de schema.sql (SQL Editor → Run). Idempotente.
-- Nombres, teléfonos y direcciones son ficticios (solo demostración);
-- las coordenadas son aproximadas a cada zona de La Paz / El Alto.
-- Los usuarios de prueba se crean desde la app (pantalla "Crear cuenta").
-- =====================================================================

insert into public.servicios (nombre) values
  ('Medicina general'), ('Vacunas'), ('Control de presión'), ('Farmacia'),
  ('Emergencias'), ('Pediatría'), ('Laboratorio'), ('Rayos X'), ('Cardiología'),
  ('Curaciones'), ('Maternidad'), ('Odontología'), ('Urgencias menores'),
  ('Geriatría'), ('Fisioterapia'), ('Oftalmología')
on conflict (nombre) do nothing;

insert into public.centros_salud
  (nombre, tipo, ciudad, zona, direccion, telefono, latitud, longitud,
   abierto_24h, hora_apertura, hora_cierre, dias_atencion, atiende_emergencias, descripcion)
values
  ('Centro de Salud Villa Victoria', 'centro_salud', 'La Paz', 'Villa Victoria',
   'Calle 3 esq. Av. Baptista, Villa Victoria', '2-000-0001', -16.4870, -68.1490,
   false, '07:00', '19:00', '{1,2,3,4,5,6}', false,
   'Centro de primer nivel para consultas generales, control de adultos mayores y vacunación.'),
  ('Hospital General Miraflores', 'hospital', 'La Paz', 'Miraflores',
   'Av. Saavedra N° 100, Miraflores', '2-000-0002', -16.5010, -68.1210,
   true, null, null, '{1,2,3,4,5,6,7}', true,
   'Hospital de referencia con emergencias las 24 horas y especialidades.'),
  ('Posta Sanitaria Pura Pura', 'posta', 'La Paz', 'Pura Pura',
   'Calle Los Pinos N° 45, Pura Pura', '2-000-0003', -16.4880, -68.1580,
   false, '08:00', '16:00', '{1,2,3,4,5}', false,
   'Posta de barrio para atenciones básicas y curaciones.'),
  ('Hospital Municipal Ciudad Satélite', 'hospital', 'El Alto', 'Ciudad Satélite',
   'Av. Satélite N° 200, Ciudad Satélite', '2-000-0004', -16.5390, -68.1690,
   true, null, null, '{1,2,3,4,5,6,7}', true,
   'Hospital de segundo nivel en El Alto con emergencias y maternidad.'),
  ('Centro de Salud 16 de Julio', 'centro_salud', 'El Alto', '16 de Julio',
   'Av. Alfonso Ugarte N° 80, 16 de Julio', '2-000-0005', -16.4950, -68.1880,
   false, '07:00', '22:00', '{1,2,3,4,5,6,7}', true,
   'Centro con horario extendido y atención de urgencias menores.'),
  ('Centro de Salud Sopocachi', 'centro_salud', 'La Paz', 'Sopocachi',
   'Calle Rosendo Gutiérrez N° 30, Sopocachi', '2-000-0006', -16.5100, -68.1290,
   false, '08:00', '18:00', '{1,2,3,4,5}', false,
   'Atención de medicina general, geriatría y control de enfermedades crónicas.'),
  ('Posta Sanitaria Villa Fátima', 'posta', 'La Paz', 'Villa Fátima',
   'Av. Las Américas N° 12, Villa Fátima', '2-000-0007', -16.4800, -68.1180,
   false, '08:00', '14:00', '{1,2,3,4,5,6}', false,
   'Posta de barrio con vacunación y curaciones.'),
  ('Hospital Zona Sur Obrajes', 'hospital', 'La Paz', 'Obrajes',
   'Calle 5 de Obrajes N° 55', '2-000-0008', -16.5250, -68.1110,
   true, null, null, '{1,2,3,4,5,6,7}', true,
   'Hospital con emergencias, pediatría, oftalmología y laboratorio.'),
  ('Centro de Salud Villa Adela', 'centro_salud', 'El Alto', 'Villa Adela',
   'Av. Bolivia N° 300, Villa Adela', '2-000-0009', -16.5180, -68.2050,
   false, '07:30', '19:30', '{1,2,3,4,5,6}', false,
   'Centro de primer nivel con odontología y fisioterapia.'),
  ('Posta Sanitaria Río Seco', 'posta', 'El Alto', 'Río Seco',
   'Calle 8 N° 21, Río Seco', '2-000-0010', -16.4790, -68.2010,
   false, '08:00', '16:00', '{1,2,3,4,5}', false,
   'Posta para controles básicos y curaciones.')
on conflict (nombre) do nothing;

-- Servicios por centro (relación N a M).
insert into public.centro_servicios (centro_id, servicio_id)
select c.id, s.id
from (values
  ('Centro de Salud Villa Victoria',     array['Medicina general','Vacunas','Control de presión','Farmacia']),
  ('Hospital General Miraflores',        array['Emergencias','Pediatría','Laboratorio','Rayos X','Cardiología']),
  ('Posta Sanitaria Pura Pura',          array['Medicina general','Curaciones','Vacunas']),
  ('Hospital Municipal Ciudad Satélite', array['Emergencias','Maternidad','Pediatría','Laboratorio']),
  ('Centro de Salud 16 de Julio',        array['Medicina general','Odontología','Urgencias menores']),
  ('Centro de Salud Sopocachi',          array['Medicina general','Geriatría','Control de presión','Farmacia']),
  ('Posta Sanitaria Villa Fátima',       array['Vacunas','Curaciones']),
  ('Hospital Zona Sur Obrajes',          array['Emergencias','Pediatría','Oftalmología','Laboratorio','Rayos X']),
  ('Centro de Salud Villa Adela',        array['Medicina general','Odontología','Fisioterapia']),
  ('Posta Sanitaria Río Seco',           array['Medicina general','Curaciones','Control de presión'])
) as d(centro, lista)
join public.centros_salud c on c.nombre = d.centro
join public.servicios s on s.nombre = any (d.lista)
on conflict do nothing;

-- Comprobación rápida.
select (select count(*) from public.centros_salud) as centros,
       (select count(*) from public.servicios)     as servicios,
       (select count(*) from public.centro_servicios) as relaciones;

-- =====================================================================
-- SPRINT 3 · HU-03 Farmacias de turno (datos ficticios de demostración)
-- Coordenadas aproximadas a cada zona. Los turnos se generan desde 3 días
-- atrás hasta 120 días adelante: vuelve a ejecutar este bloque si vencen.
-- =====================================================================
insert into public.farmacias (nombre, ciudad, zona, direccion, telefono, latitud, longitud) values
  ('Farmacia San Pedro',        'La Paz',  'San Pedro',       'Calle Colombia N° 210, San Pedro',          '2-100-0001', -16.5005, -68.1360),
  ('Farmacia Sopocachi Central','La Paz',  'Sopocachi',       'Av. 6 de Agosto N° 2050, Sopocachi',        '2-100-0002', -16.5090, -68.1255),
  ('Farmacia Miraflores Salud', 'La Paz',  'Miraflores',      'Av. Busch N° 1500, Miraflores',             '2-100-0003', -16.4985, -68.1185),
  ('Farmacia El Prado',         'La Paz',  'Centro',          'Av. 16 de Julio N° 1600, El Prado',         '2-100-0004', -16.5012, -68.1322),
  ('Farmacia Obrajes',          'La Paz',  'Obrajes',         'Av. Hernando Siles N° 500, Obrajes',        '2-100-0005', -16.5230, -68.1125),
  ('Farmacia Villa Fátima',     'La Paz',  'Villa Fátima',    'Av. Tejada Sorzano N° 300, Villa Fátima',   '2-100-0006', -16.4815, -68.1200),
  ('Farmacia Ceja',             'El Alto', 'La Ceja',         'Av. 6 de Marzo N° 10, La Ceja',             '2-100-0007', -16.5040, -68.1640),
  ('Farmacia Satélite',         'El Alto', 'Ciudad Satélite', 'Plaza Juana Azurduy N° 5, Ciudad Satélite', '2-100-0008', -16.5370, -68.1720),
  ('Farmacia 16 de Julio',      'El Alto', '16 de Julio',     'Av. Alfonso Ugarte N° 120, 16 de Julio',    '2-100-0009', -16.4960, -68.1900),
  ('Farmacia Villa Adela',      'El Alto', 'Villa Adela',     'Av. Bolivia N° 450, Villa Adela',           '2-100-0010', -16.5200, -68.2030),
  ('Farmacia Río Seco',         'El Alto', 'Río Seco',        'Av. Juan Pablo II N° 900, Río Seco',        '2-100-0011', -16.4800, -68.2000),
  ('Farmacia Senkata',          'El Alto', 'Senkata',         'Av. 6 de Marzo N° 4000, Senkata',           '2-100-0012', -16.5560, -68.1960)
on conflict (nombre) do nothing;

-- Rotación: cada día quedan 2 farmacias de turno en La Paz y 2 en El Alto.
insert into public.turnos_farmacia (farmacia_id, fecha)
select f.id, d.fecha
from (
  select id, ciudad, row_number() over (partition by ciudad order by nombre) - 1 as n
  from public.farmacias
) f
cross join (
  select gs::date as fecha,
         (gs::date - date '2026-01-01') as k
  from generate_series((now() at time zone 'America/La_Paz')::date - 3,
                       (now() at time zone 'America/La_Paz')::date + 120,
                       interval '1 day') as gs
) d
where (d.k + f.n) % 3 = 0
on conflict (farmacia_id, fecha) do nothing;

select (select count(*) from public.farmacias)       as farmacias,
       (select count(*) from public.turnos_farmacia) as turnos;
