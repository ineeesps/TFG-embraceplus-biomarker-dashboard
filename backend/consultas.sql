-- =====================================================================
-- HITO 3.1: Lógica de Resampling SQL e Interpolación (Falta de Señal)
-- =====================================================================
-- Agrupa los datos por minuto y calcula la media.
-- Utiliza time_bucket_gapfill e interpolate para rellenar los huecos
-- donde la pulsera perdió calidad de señal (NULLs).

SELECT 
    time_bucket_gapfill('1 minute', time) AS minuto, 
    'pulse_rate' as sensor_type, 
    interpolate(AVG(value)) as media_valor 
FROM biomarcadores 
WHERE participant_id = 'PRUEBA 1' 
  AND sensor_type = 'pulse_rate' 
  AND value IS NOT NULL 
  AND time >= '2025-02-22 12:30:00+00' 
  AND time <= '2025-02-22 12:57:00+00' 
GROUP BY minuto 
ORDER BY minuto ASC;


-- =====================================================================
-- HITO 3.2: Prototipado de Correlación (EDA vs HR)
-- =====================================================================
-- Alinea en paralelo los datos de frecuencia cardíaca (pulse_rate) 
-- y actividad electrodérmica (eda) en la misma línea temporal.

SELECT 
    time_bucket('1 minute', time) AS minuto, 
    AVG(value) FILTER (WHERE sensor_type = 'pulse_rate') AS media_hr, 
    AVG(value) FILTER (WHERE sensor_type = 'eda') AS media_eda 
FROM biomarcadores 
WHERE participant_id = 'PRUEBA 1' 
  AND sensor_type IN ('pulse_rate', 'eda') 
GROUP BY minuto 
ORDER BY minuto ASC;