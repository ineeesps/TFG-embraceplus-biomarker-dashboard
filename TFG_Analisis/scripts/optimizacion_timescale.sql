-- =========================================================================
-- OPTIMIZACIÓN CLÍNICA AVANZADA DE TIMESCALEDB PARA EMBRACEPLUS
-- Proyecto TFG
-- Este script se debe ejecutar sobre la base de datos `tfg_embrace`.
-- =========================================================================

-- 1. JERARQUÍA DE SESIONES CLINICAS
-- Permite aislar y agrupar los datos fisiológicos (ej. Prueba de esfuerzo vs Reposo)
CREATE TABLE IF NOT EXISTS sesiones_clinicas (
    id SERIAL PRIMARY KEY,
    participant_id VARCHAR(50) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    tipo_prueba VARCHAR(100),
    descripcion TEXT
);

-- 2. ÍNDICES COMPUESTOS ESPECÍFICOS (Rendimiento Extremo)
-- Acelera los filtros del dashboard donde el investigador busca un paciente y sensor concreto ordenado por tiempo
CREATE INDEX IF NOT EXISTS idx_biomarcadores_participant_sensor_time 
ON biomarcadores (participant_id, sensor_type, time DESC);

-- 3. COMPRESIÓN DE SERIES TEMPORALES
-- Activa la compresión nativa para ahorrar hasta un 90% de almacenamiento
-- Se segmenta por sensor_type y participant_id
ALTER TABLE biomarcadores SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'participant_id, sensor_type',
    timescaledb.compress_orderby = 'time DESC'
);

-- Configura que los datos de más de 7 días se compriman automáticamente en segundo plano
SELECT add_compression_policy('biomarcadores', INTERVAL '7 days');


-- 4. VISTAS MATERIALIZADAS CONTINUAS (CAGG)
-- Precalcula las "cubetas" (buckets) de 1 minuto automáticamente.
-- Cuando el Frontend pide datos, la BD ya los tiene calculados, respondiendo en milisegundos.
CREATE MATERIALIZED VIEW IF NOT EXISTS metricas_1_minuto
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 minute', time) AS bucket,
    participant_id,
    sensor_type,
    CASE 
        WHEN sensor_type IN ('activity_class', 'activity_intensity', 'body_position', 'sleep_detection') 
        THEN mode() WITHIN GROUP (ORDER BY value)
        ELSE AVG(value)
    END as value_resampled,
    COUNT(*) as total_samples,
    COUNT(*) FILTER (WHERE quality_flag NOT LIKE '%%good%%') as noisy_samples
FROM biomarcadores
GROUP BY bucket, participant_id, sensor_type;

-- Política para refrescar la vista materializada cada hora
SELECT add_continuous_aggregate_policy('metricas_1_minuto',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');


-- 5. POLÍTICAS DE RETENCIÓN DE DATOS (DATA LIFECYCLE)
-- Para cumplir con RGPD o ahorrar servidor: Borra datos crudos obsoletos de más de 12 meses
-- Nota: La vista materializada (CAGG) retendrá los promedios estadísticos históricos aunque el crudo se borre.
SELECT add_retention_policy('biomarcadores', INTERVAL '12 months');
