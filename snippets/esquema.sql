-- Esquema genérico del sistema de leads (PostgreSQL 16).
-- Nombres simplificados para el caso de estudio. Sin datos.

CREATE SCHEMA IF NOT EXISTS leads;

-- Contactos -------------------------------------------------------------------------------------

CREATE TABLE leads.contactos (
  id                   serial PRIMARY KEY,
  nombre               varchar(255) NOT NULL,
  email                varchar(255) NOT NULL,
  telefono             varchar(50),
  horario_preferido    varchar(100),
  servicio             varchar(255),
  mensaje              text,

  -- Origen y campaña
  fuente               varchar(20) DEFAULT 'bot',
  gclid                text,
  utm_source           text,
  utm_medium           text,
  utm_campaign         text,
  utm_term             text,
  utm_content          text,

  -- Análisis de la IA
  viabilidad           varchar(20),               -- alta | media | baja | pendiente
  tipo_caso            varchar(255),
  resumen              text,
  prioridad            integer CHECK (prioridad BETWEEN 1 AND 5),
  correo_enviado       text,

  -- Gestión
  estado               varchar(50) DEFAULT 'nuevo',
  asignado_a           varchar(100),
  observaciones        text,
  comentario_final     text,

  -- Recordatorio
  recordatorio         varchar(10),               -- 1s | 15d | 1m
  recordatorio_fecha   timestamptz,
  recordatorio_enviado boolean DEFAULT false,

  creado               timestamptz DEFAULT now(),
  actualizado          timestamptz DEFAULT now()
);

CREATE INDEX contactos_email_idx  ON leads.contactos (email);
CREATE INDEX contactos_estado_idx ON leads.contactos (estado);
CREATE INDEX contactos_creado_idx ON leads.contactos (creado);
-- Para el flujo de recordatorios: solo los pendientes de enviar.
CREATE INDEX contactos_recordatorio_idx ON leads.contactos (recordatorio_fecha)
  WHERE recordatorio IS NOT NULL AND NOT recordatorio_enviado;

-- Usuarios, actividad y acceso ------------------------------------------------------------------

CREATE TABLE leads.usuarios (
  id            serial PRIMARY KEY,
  nombre        varchar(100),
  email         varchar(255) NOT NULL UNIQUE,
  password_hash varchar(255) NOT NULL,
  roles         text[] DEFAULT ARRAY['empleado'],
  activo        boolean DEFAULT true,
  creado        timestamptz DEFAULT now()
);

CREATE TABLE leads.actividad (
  id             serial PRIMARY KEY,
  fecha          timestamptz DEFAULT now(),
  usuario_id     integer,
  usuario_nombre varchar(100),        -- copia en el momento del cambio
  accion         varchar(30) NOT NULL, -- login | lead_update | ...
  contacto_id    integer,
  campo          varchar(50),
  valor_anterior text,
  valor_nuevo    text
);
CREATE INDEX actividad_fecha_idx   ON leads.actividad (fecha);
CREATE INDEX actividad_usuario_idx ON leads.actividad (usuario_id);

CREATE TABLE leads.codigos_2fa (
  id          serial PRIMARY KEY,
  usuario_id  integer NOT NULL,
  codigo_hash varchar(64) NOT NULL,   -- nunca el código en claro
  caduca      timestamptz NOT NULL,
  intentos    integer DEFAULT 0,
  usado       boolean DEFAULT false,
  creado      timestamptz DEFAULT now()
);

CREATE TABLE leads.dispositivos_confianza (
  id         serial PRIMARY KEY,
  usuario_id integer NOT NULL,
  token_hash varchar(64) NOT NULL,
  caduca     timestamptz NOT NULL,
  creado     timestamptz DEFAULT now()
);
CREATE INDEX dispositivos_token_idx ON leads.dispositivos_confianza (token_hash);

-- Métricas de publicidad ------------------------------------------------------------------------

CREATE TABLE leads.metricas_ads (
  id                 serial PRIMARY KEY,
  fecha              date NOT NULL,
  campana_id         varchar(50),
  campana_nombre     varchar(255),
  impresiones        bigint DEFAULT 0,
  clics              bigint DEFAULT 0,
  coste              numeric(12,2) DEFAULT 0,
  conversiones       numeric(12,2) DEFAULT 0,
  valor_conversiones numeric(12,2) DEFAULT 0,
  cargado            timestamptz DEFAULT now()
);
-- Upsert idempotente por día y campaña.
CREATE UNIQUE INDEX metricas_ads_dia_campana_uidx ON leads.metricas_ads (fecha, campana_id);

-- Normalización en la base: da igual por qué entrada llegue el contacto --------------------------

CREATE FUNCTION leads.normalizar_contacto() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  d text;
BEGIN
  IF NEW.nombre IS NOT NULL AND btrim(NEW.nombre) <> '' THEN
    NEW.nombre := initcap(regexp_replace(btrim(NEW.nombre), '\s+', ' ', 'g'));
  END IF;

  IF NEW.telefono IS NOT NULL THEN
    d := regexp_replace(NEW.telefono, '\D', '', 'g');            -- solo dígitos
    IF length(d) = 11 AND left(d, 2) = '34' THEN d := right(d, 9);  -- 34XXXXXXXXX
    ELSIF length(d) = 13 AND left(d, 4) = '0034' THEN d := right(d, 9);
    END IF;
    IF length(d) = 9 THEN                                         -- formato único
      NEW.telefono := '+34 ' || substr(d,1,3) || ' ' || substr(d,4,2) || ' '
                               || substr(d,6,2) || ' ' || substr(d,8,2);
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE FUNCTION leads.limpiar_marketing() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  -- Los formularios envían "undefined" o '' cuando no hay parámetro de campaña.
  NEW.gclid        := NULLIF(NULLIF(NEW.gclid,        'undefined'), '');
  NEW.utm_source   := NULLIF(NULLIF(NEW.utm_source,   'undefined'), '');
  NEW.utm_medium   := NULLIF(NULLIF(NEW.utm_medium,   'undefined'), '');
  NEW.utm_campaign := NULLIF(NULLIF(NEW.utm_campaign, 'undefined'), '');
  NEW.utm_term     := NULLIF(NULLIF(NEW.utm_term,     'undefined'), '');
  NEW.utm_content  := NULLIF(NULLIF(NEW.utm_content,  'undefined'), '');
  RETURN NEW;
END $$;

CREATE TRIGGER normalizar_contacto BEFORE INSERT ON leads.contactos
  FOR EACH ROW EXECUTE FUNCTION leads.normalizar_contacto();
CREATE TRIGGER limpiar_marketing BEFORE INSERT ON leads.contactos
  FOR EACH ROW EXECUTE FUNCTION leads.limpiar_marketing();
