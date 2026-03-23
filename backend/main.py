from fastapi import FastAPI, UploadFile, File, HTTPException
import psycopg2
from psycopg2.extras import RealDictCursor
import pandas as pd
import io
import os
import sys

# PARA QUE ENCUENTRE CARPETA SCRIPTS
# Le decimos a Python que suba una carpeta (..) y entre en 'scripts'
dir_actual = os.path.dirname(os.path.abspath(__file__))
ruta_scripts = os.path.join(dir_actual, '..', 'scripts')
sys.path.append(ruta_scripts)

from cargar_datos import cargar_csv_a_timescale

app = FastAPI(
    title="EmbracePlus API - TFG Inés",
    description="Backend integrado con Orquestador de Ingesta",
    version="2.0.0"
)

# Configuración de la base de datos: 
# Usa 'DB_HOST' si estamos en Docker, si no, usa 'localhost' (para pruebas locales)
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": "tfg_embrace",
    "user": "ines",
    "password": "tfg_password",
    "port": "5432"
}

# Diccionario de patrones
PATRONES_SENSORES = {
    'temperature': 'temperature', 'eda': 'eda', 'pulse-rate': 'pulse_rate',
    'respiratory-rate': 'respiratory_rate', 'accelerometers-std': 'accelerometer_std',
    'prv': 'prv', 'step-counts': 'step_count', 'met': 'met',
    'activity-intensity': 'activity_intensity', 'wearing-detection': 'wearing_detection',
    'activity-classification': 'activity_class', 'activity-counts': 'activity_counts',
    'actigraphy-counts': 'actigraphy_vector', 'body-position': 'body_position',
    'acticounts': 'acticounts_x'
}

@app.get("/")
async def root():
    return {"status": "online", "modulo": "API TFG Inés"}

@app.get("/health")
async def health():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.close()
        return {"status": "ok", "db": "connected"}
    except:
        return {"status": "error", "db": "disconnected"}

# ==========================================
# ENDPOINT DE INGESTA REAL
# ==========================================
@app.post("/participante/{id}/cargar")
async def cargar_archivo_automatico(id: str, file: UploadFile = File(...)):
    """
    Paso A: Llama a cargar_datos.py para insertar en DB.
    Paso B: Valida la fila 752.
    """
    nombre_archivo = file.filename.lower()
    sensor_detectado = None

    # Detectar el sensor usando tus patrones
    for patron, sensor in PATRONES_SENSORES.items():
        if patron in nombre_archivo:
            sensor_detectado = sensor
            break
    
    if not sensor_detectado:
        raise HTTPException(status_code=400, detail="Tipo de sensor no reconocido")

    try:
        # Leemos el archivo en memoria para validarlo
        contenido = await file.read()
        df = pd.read_csv(io.BytesIO(contenido), low_memory=False)
        
        # PASO B: VALIDACIÓN EN TIEMPO REAL 
        if len(df) <= 751:
            raise HTTPException(status_code=400, detail="Fichero vacío o corrupto: sin datos tras fila 752")

        # PASO A: EJECUCIÓN DEL ORQUESTADOR
        # 1. Guardamos el archivo temporalmente en la carpeta "data" para que tu script lo encuentre
        dir_actual = os.path.dirname(os.path.abspath(__file__))
        ruta_data = os.path.join(dir_actual, '..', 'data')
        os.makedirs(ruta_data, exist_ok=True) 
        
        ruta_temp = os.path.join(ruta_data, file.filename)
        with open(ruta_temp, "wb") as f:
            f.write(contenido)
        
        # 2. LLAMAMOS A MI CÓDIGO ORIGINAL. Esto es lo que inserta de verdad en TimescaleDB
        cargar_csv_a_timescale(file.filename, sensor_detectado, id)
        
        # 3. Borramos el archivo temporal para no ensuciar el ordenador
        if os.path.exists(ruta_temp):
            os.remove(ruta_temp)

        # Calculamos cuántas filas limpias quedaron para informar
        df_limpio = df[df['missing_value_reason'] != 'device_not_recording']

        return {
            "status": "success",
            "participante": id,
            "sensor": sensor_detectado,
            "filas_insertadas": len(df_limpio),
            "mensaje": "Datos validados e insertados correctamente en TimescaleDB"
        }

    except HTTPException as http_e:
        raise http_e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")

# ==========================================
# EL "CONTRATO" DE DATOS (JSON)
# ==========================================
@app.get("/participante/{id}/metricas")
async def consultar_datos(id: str):
    """
    Paso C: Devuelve los datos para que Flutter los lea a 60 fps (RF4.1)
    """
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Busca por el ID del participante, no solo por sensor
        cur.execute("""
            SELECT time, sensor_type, value, quality_flag 
            FROM biomarcadores 
            WHERE participant_id = %s 
            ORDER BY time DESC 
            LIMIT 100
        """, (id,))
        
        res = cur.fetchall()
        cur.close()
        conn.close()
        
        return {
            "participante": id, 
            "total_registros": len(res), 
            "metricas": res
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))