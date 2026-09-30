-- Métricas del informe semanal en UNA sola consulta.
-- Devuelve una fila: indicadores sueltos y desgloses ya agregados como JSON [{label, value}],
-- listos para que un nodo Code de n8n componga el correo.
-- (El informe mensual es la misma consulta con 30 días y la comparación con los 30 anteriores.)

WITH semana AS (
  SELECT * FROM leads.contactos
  WHERE creado >= now() - interval '7 days'
),
desglose AS (
  SELECT 'fuente' AS dim, coalesce(nullif(fuente, ''), 'desconocida') AS label, count(*)::int AS value FROM semana GROUP BY 2
  UNION ALL
  SELECT 'estado',        coalesce(nullif(estado, ''), 'Sin estado'),              count(*)::int FROM semana GROUP BY 2
  UNION ALL
  SELECT 'servicio',      coalesce(nullif(servicio, ''), 'Sin servicio'),          count(*)::int FROM semana GROUP BY 2
  UNION ALL
  SELECT 'persona',       coalesce(nullif(asignado_a, ''), 'Sin asignar'),         count(*)::int FROM semana GROUP BY 2
)
SELECT
  (SELECT count(*) FROM semana)::int                                              AS nuevos,
  (SELECT count(*) FROM semana WHERE lower(viabilidad) = 'alta')::int             AS alta,
  (SELECT count(*) FROM semana WHERE lower(viabilidad) = 'media')::int            AS media,
  (SELECT count(*) FROM semana WHERE lower(viabilidad) = 'baja')::int             AS baja,

  -- Pendientes de gestionar en total (no solo esta semana).
  (SELECT count(*) FROM leads.contactos WHERE coalesce(estado, '') IN ('', 'nuevo'))::int
                                                                                  AS sin_gestionar,

  -- Las conversiones salen del registro de actividad: cambios de estado a «convertido».
  (SELECT count(*) FROM leads.actividad
    WHERE accion = 'lead_update' AND campo = 'estado'
      AND lower(valor_nuevo) = 'convertido'
      AND fecha >= now() - interval '7 days')::int                               AS convertidos,

  -- Desgloses: un array JSON por dimensión, ordenado de mayor a menor.
  (SELECT coalesce(json_agg(json_build_object('label', label, 'value', value) ORDER BY value DESC), '[]')
     FROM desglose WHERE dim = 'fuente')                                          AS por_fuente,
  (SELECT coalesce(json_agg(json_build_object('label', label, 'value', value) ORDER BY value DESC), '[]')
     FROM desglose WHERE dim = 'estado')                                          AS por_estado,
  (SELECT coalesce(json_agg(json_build_object('label', label, 'value', value) ORDER BY value DESC), '[]')
     FROM (SELECT * FROM desglose WHERE dim = 'servicio' ORDER BY value DESC LIMIT 10) s)
                                                                                  AS por_servicio,
  (SELECT coalesce(json_agg(json_build_object('label', label, 'value', value) ORDER BY value DESC), '[]')
     FROM desglose WHERE dim = 'persona')                                         AS por_persona;
