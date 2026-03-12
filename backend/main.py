from fastapi import FastAPI, UploadFile, File, HTTPException
import psycopg2
from psycopg2.extras import RealDictCursor
import pandas as pd
import io
import os

app = FastAPI(
    title="EmbracePlus API - TFG Inés",
    description="Backend con Lógica de Ingesta Unificada (Filtro device_not_recording)",
    version="1.1.0"
)

# Configuración de la base de datos en Docker
DB_CONFIG = {
    "host": "localhost",
    "database": "tfg_embrace",
    "user": "ines",
    "password": "tfg_password",
    "port": "5432"
}

# Diccionario de patrones orquestador
PATRONES_SENSORES = {
    'temperature': 'temperature',
    'eda': 'eda',
    'pulse-rate': 'pulse_rate',
    'respiratory-rate': 'respiratory_rate',
    'accelerometers-std': 'accelerometer_std',
    'prv': 'prv',
    'step-counts': 'step_count',
    'met': 'met',
    'activity-intensity': 'activity_intensity',
    'wearing-detection': 'wearing_detection',
    'activity-classification': 'activity_class',
    'activity-counts': 'activity_counts',
    'actigraphy-counts': 'actigraphy_vector',
    'body-position': 'body_position',
    'acticounts': 'acticounts_x'
}

@app.get("/")
async def root():
    return {"status": "online", "modulo": "API TFG Inés"}

@app.get("/health")
async def health():
    """Verifica si la base de datos responde"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.close()
        return {"status": "ok", "db": "connected"}
    except:
        return {"status": "error", "db": "disconnected"}

# ENDPOINT DE INGESTA 
@app.post("/cargar-archivo/{id_participante}")
async def cargar_archivo_automatico(id_participante: str, file: UploadFile = File(...)):
    """
    Identifica el sensor y aplica el filtro de 'device_not_recording'
    igual que el script cargar_datos.py
    """
    nombre_archivo = file.filename.lower()
    sensor_detectado = None

    for patron, sensor in PATRONES_SENSORES.items():
        if patron in nombre_archivo:
            sensor_detectado = sensor
            break
    
    if not sensor_detectado:
        raise HTTPException(status_code=400, detail="Tipo de sensor no reconocido")

    try:
        # 1. Leer el archivo completo
        contenido = await file.read()
        df = pd.read_csv(io.BytesIO(contenido), low_memory=False)
        
        # 2. Aplicar  lógica de limpieza 
        # Filtramos las filas donde el dispositivo no estaba grabando
        df_limpio = df[df['missing_value_reason'] != 'device_not_recording'].copy()
        
        # 3. Respuesta de éxito
        return {
            "participante": id_participante,
            "archivo": file.filename,
            "sensor_identificado": sensor_detectado,
            "analisis": {
                "filas_brutas": len(df),
                "filas_con_datos_reales": len(df_limpio),
                "datos_descartados": len(df) - len(df_limpio)
            },
            "estado": "Limpieza completada siguiendo lógica de cargar_datos.py"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error procesando el archivo: {str(e)}")

@app.get("/datos/{sensor}")
async def consultar_datos(sensor: str, limite: int = 50):
    """Devuelve los datos reales almacenados en la base de datos"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT time, value, quality_flag 
            FROM biomarcadores 
            WHERE sensor_type = %s 
            ORDER BY time DESC 
            LIMIT %s
        """, (sensor, limite))
        res = cur.fetchall()
        cur.close()
        conn.close()
        return {"sensor": sensor, "conteo": len(res), "datos": res}
    except Exception as e:
        return {"error": str(e)}