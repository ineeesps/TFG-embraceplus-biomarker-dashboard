import psycopg2
from psycopg2 import extras
import os
from datetime import datetime, timedelta
import random

def generate_test_data():
    conn = None
    try:
        conn = psycopg2.connect(
            dbname="tfg_embrace",
            user="ines",
            password="tfg_password",
            host="localhost",
            port="5433"
        )
        cur = conn.cursor()

        participante = "PRUEBA_SUEÑO"
        investigador = "ines"
        
        # Limpiar datos previos del participante de prueba
        cur.execute("DELETE FROM biomarcadores WHERE participant_id = %s", (participante,))
        
        start_time = datetime(2026, 5, 14, 22, 0, 0)
        end_time = datetime(2026, 5, 15, 9, 0, 0)
        
        datos = []
        current = start_time
        
        print(f"Generando datos para {participante}...")
        
        while current < end_time:
            # Lógica de sueño: 
            # 22:00 - 23:00: Despierto (0)
            # 23:00 - 01:00: Sueño Ligero (1)
            # 01:00 - 03:00: Sueño Profundo (2)
            # 03:00 - 03:15: Despertar (0) - WASO
            # 03:15 - 05:00: Sueño Ligero (1)
            # 05:00 - 07:00: Sueño Profundo (2)
            # 07:00 - 08:00: Sueño Ligero (1)
            # 08:00 - 09:00: Despierto (0)
            
            h = current.hour
            m = current.minute
            
            stage = 0
            is_sleeping = 0
            pos = 5 # Supino por defecto
            pulse = 70 + random.randint(-5, 5)

            if 22 <= h < 23:
                stage = 0
                is_sleeping = 0
                pos = 1 # De pie / Sentado
            elif (23 <= h) or (0 <= h < 1):
                stage = 1
                is_sleeping = 1
                pos = 5 # Supino
                pulse = 55 + random.randint(-3, 3)
            elif 1 <= h < 3:
                stage = 2
                is_sleeping = 1
                pos = 2 # Lateral
                pulse = 50 + random.randint(-2, 2)
            elif h == 3 and m < 15:
                stage = 0
                is_sleeping = 0
                pos = 5
                pulse = 65
            elif (h == 3 and m >= 15) or (h == 4):
                stage = 1
                is_sleeping = 1
                pos = 3 # Lateral derecho
                pulse = 58
            elif 5 <= h < 7:
                stage = 2
                is_sleeping = 1
                pos = 5
                pulse = 48
            elif 7 <= h < 8:
                stage = 1
                is_sleeping = 1
                pos = 5
                pulse = 55
            else:
                stage = 0
                is_sleeping = 0
                pos = 0 # Sentado
                pulse = 75

            # Insertar sensores
            datos.append((current, participante, 'sleep_detection', is_sleeping, 'ok', investigador))
            datos.append((current, participante, 'sleep_stages', stage, 'ok', investigador))
            datos.append((current, participante, 'body_position', pos, 'ok', investigador))
            datos.append((current, participante, 'pulse_rate', pulse, 'ok', investigador))
            
            current += timedelta(minutes=1)

        sql = "INSERT INTO biomarcadores (time, participant_id, sensor_type, value, quality_flag, investigador) VALUES %s"
        extras.execute_values(cur, sql, datos)
        
        conn.commit()
        print(f"¡Éxito! Insertados {len(datos)} registros para {participante}.")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        if conn:
            cur.close()
            conn.close()

if __name__ == "__main__":
    generate_test_data()
