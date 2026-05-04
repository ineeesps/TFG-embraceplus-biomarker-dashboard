import os
import psycopg2
import sys

# Agregar scripts al path para importar
dir_actual = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(dir_actual, 'TFG_Analisis', 'scripts'))

from cargar_datos import cargar_csv_a_timescale

def main():
    # Asegurar que los sub-scripts usen el puerto correcto
    os.environ["DB_PORT"] = "5433"
    
    # 1. Conectar a PostgreSQL local y vaciar la tabla
    print("Conectando a la base de datos dockerizada en puerto 5433...")
    try:
        conn = psycopg2.connect(dbname="tfg_embrace", user="ines", password="tfg_password", host="localhost", port="5433")
        cur = conn.cursor()
        
        # En caso de que se haya borrado el docker sin volumes, creamos la tabla si no existe
        cur.execute("""
            CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
            CREATE TABLE IF NOT EXISTS biomarcadores (
                time TIMESTAMPTZ NOT NULL,
                participant_id VARCHAR(50) NOT NULL,
                sensor_type VARCHAR(50) NOT NULL,
                value DOUBLE PRECISION,
                quality_flag VARCHAR(100)
            );
            SELECT create_hypertable('biomarcadores', by_range('time'), if_not_exists => TRUE);
        """)
        
        cur.execute("TRUNCATE TABLE biomarcadores;")
        conn.commit()
        print("✅ Tabla 'biomarcadores' inicializada y vaciada con éxito.")
    except Exception as e:
        print(f"❌ Error vaciando la base de datos: {e}")
        return
    finally:
        if 'cur' in locals(): cur.close()
        if 'conn' in locals(): conn.close()

    # 2. Ingestar los CSVs de 1a_prueba y 2a_prueba
    datasets = [
        ("PRUEBA 1", os.path.join(dir_actual, '1a_prueba', '1788', '1', '1', 'participant_data', '2025-02-22', 'PRUEBA-3YK9J1H1GV', 'digital_biomarkers', 'aggregated_per_minute')),
        ("PRUEBA 2", os.path.join(dir_actual, '2a_prueba', '1788', '1', '1', 'participant_data', '2025-02-22', 'PRUEBA-3YK9J1H1GV', 'digital_biomarkers', 'aggregated_per_minute')),
    ]
    
    patrones = {
        'temperature': 'temperature', 'eda': 'eda', 'pulse-rate': 'pulse_rate',
        'respiratory-rate': 'respiratory_rate', 'accelerometers-std': 'accelerometer_std',
        'prv': 'prv', 'step-counts': 'step_count', 'met': 'met',
        'activity-intensity': 'activity_intensity', 'wearing-detection': 'wearing_detection',
        'activity-classification': 'activity_class', 'activity-counts': 'activity_counts',
        'actigraphy-counts': 'actigraphy_vector', 'body-position': 'body_position',
        'acticounts': 'acticounts_total'
    }

    import shutil
    ruta_data_script = os.path.join(dir_actual, 'TFG_Analisis', 'data')
    os.makedirs(ruta_data_script, exist_ok=True)

    conteo_exito = 0

    for participante, ruta_data in datasets:
        print(f"\n--- Procesando {participante} desde {ruta_data} ---")
        
        if not os.path.exists(ruta_data):
            print(f"❌ La ruta no existe: {ruta_data}")
            continue

        archivos_encontrados = os.listdir(ruta_data)

        for archivo in archivos_encontrados:
            if archivo.endswith('.csv'):
                for patron, sensor in patrones.items():
                    if patron in archivo.lower():
                        src = os.path.join(ruta_data, archivo)
                        dst = os.path.join(ruta_data_script, archivo)
                        shutil.copy2(src, dst)
                        
                        try:
                            print(f"Cargando {archivo} -> {sensor}...")
                            cargar_csv_a_timescale(archivo, sensor, participante)
                            conteo_exito += 1
                        except Exception as e:
                            print(f"❌ Error con {archivo}: {e}")
                        finally:
                            if os.path.exists(dst):
                                os.remove(dst)
                        break 
                        
    print(f"\n🎉 Proceso finalizado. {conteo_exito} CSVs procesados e injestados en DB.")

if __name__ == "__main__":
    main()
