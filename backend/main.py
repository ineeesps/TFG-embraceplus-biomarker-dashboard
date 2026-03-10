from fastapi import FastAPI
import psycopg2
from psycopg2.extras import RealDictCursor

app = FastAPI(
    title="EmbracePlus API - TFG Inés",
    description="Backend para la gestión de biomarcadores en tiempo real",
    version="1.0.0"
)

# Configuración de la base de datos en Docker
DB_CONFIG = {
    "host": "localhost",
    "database": "tfg_embrace",
    "user": "ines",
    "password": "tfg_password",
    "port": "5432"
}

@app.get("/")
async def read_root():
    return {"status": "running", "project": "TFG Análisis EmbracePlus"}

@app.get("/health")
async def check_health():
    """Verifica la conexión con TimescaleDB (Docker)"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("SELECT 1;")
        cur.close()
        conn.close()
        return {"database": "online", "message": "Conexión exitosa con TimescaleDB"}
    except Exception as e:
        return {"database": "offline", "error": str(e)}