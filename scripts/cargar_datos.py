import pandas as pd
import psycopg2
from psycopg2 import extras
import os

def cargar_csv_a_timescale(archivo_nombre, tipo_sensor, participante):
    dir_actual = os.path.dirname(os.path.abspath(__file__))
    ruta_entrada = os.path.join(dir_actual, '..', 'data', archivo_nombre)

    # Diccionario Completo
    mapa_columnas = {
        'pulse_rate': 'pulse_rate_bpm',
        'eda': 'eda_scl_usiemens',
        'temperature': 'temperature_celsius',
        'respiratory_rate': 'respiratory_rate_brpm',
        'accelerometer_std': 'accelerometers_std_g',
        'prv': 'prv_rmssd_ms',
        'step_count': 'step_counts',
        'wearing_detection': 'wearing_detection_percentage',
        'met': 'met',
        'activity_intensity': 'activity_intensity',
        'activity_class': 'activity_class',
        'activity_counts': 'activity_counts',
        'actigraphy_vector': 'vector_magnitude',
        'body_position': 'body_position_left',
        'acticounts_x': 'acticounts_x_axis'
    }

    # Mapeo de texto a número (Para columnas categóricas)
    mapeo_categorias = {
        'still': 0, 'walking': 1, 'running': 2, 'generic': 3, # activity_class
        'sitting_reclining_lying': 0, 'standing': 1,         # body_position
        'sedentary': 0, 'lpa': 1, 'mpa': 2, 'vpa': 3          # activity_intensity
    }

    if not os.path.exists(ruta_entrada): 
        raise FileNotFoundError(f"No se encontró el archivo: {ruta_entrada}")

    try:
        # Usamos variable de entorno para que funcione tanto en Docker como en local
        db_host = os.getenv("DB_HOST", "localhost")
        conn = psycopg2.connect(dbname="tfg_embrace", user="ines", password="tfg_password", host=db_host, port="5432")
        cur = conn.cursor()
        
        df = pd.read_csv(ruta_entrada, low_memory=False)
        
        # Limpieza 
        df = df[df['missing_value_reason'] != 'device_not_recording'].copy()
        df['quality_flag'] = df['missing_value_reason'].fillna('good')

        columna_valor = mapa_columnas.get(tipo_sensor)
        datos_finales = []
    
        for r in df.itertuples():
            valor_raw = getattr(r, columna_valor) if columna_valor in df.columns else None
            calidad = r.quality_flag
            
            # Lógica de Mapeo Numérico para Categorías (Texto -> Número)
            if isinstance(valor_raw, str) and valor_raw.lower() in mapeo_categorias:
                valor_num = mapeo_categorias[valor_raw.lower()]
                calidad = f"{calidad} | {valor_raw}" # Guardamos el texto original en la calidad
            else:
                valor_num = valor_raw if pd.notnull(valor_raw) else None

            datos_finales.append((r.timestamp_iso, participante, tipo_sensor, valor_num, calidad))

        if datos_finales:
            sql = "INSERT INTO biomarcadores (time, participant_id, sensor_type, value, quality_flag) VALUES %s"
            extras.execute_values(cur, sql, datos_finales, page_size=1000)
            conn.commit()
            print(f"¡ÉXITO! {len(datos_finales)} registros de {tipo_sensor} cargados.")

    except Exception as e:
        if 'conn' in locals(): conn.rollback()
        # Lanzamos el error hacia arriba para que FastAPI (main.py) se entere
        raise Exception(f"Fallo en la base de datos al procesar {archivo_nombre}: {str(e)}")
    finally:
        if 'cur' in locals(): cur.close()
        if 'conn' in locals(): conn.close()