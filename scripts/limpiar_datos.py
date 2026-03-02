import pandas as pd
import os

def etl_inicial_embrace(archivo_nombre, archivo_salida_nombre):
    # --- CONFIGURACIÓN DE RUTAS DINÁMICAS ---
    # Obtenemos la carpeta donde está este script (TFG_Analisis/scripts)
    directorio_actual = os.path.dirname(os.path.abspath(__file__))
    # Subimos un nivel para llegar a la raíz (TFG_Analisis)
    raiz_proyecto = os.path.dirname(directorio_actual)
    
    # Construimos las rutas hacia la carpeta 'data'
    ruta_entrada = os.path.join(raiz_proyecto, 'data', archivo_nombre)
    ruta_salida = os.path.join(raiz_proyecto, 'data', archivo_salida_nombre)
    # ----------------------------------------

    print(f"--- Iniciando limpieza de: {archivo_nombre} ---")
    print(f"Buscando en: {ruta_entrada}")
    
    # Verificación de existencia del archivo
    if not os.path.exists(ruta_entrada):
        print(f"ERROR: No se encuentra el archivo '{archivo_nombre}' en la carpeta 'data'.")
        print(f"Asegúrate de que la ruta sea correcta: {ruta_entrada}")
        return

    # 1. LEER EL ARCHIVO
    # Usamos low_memory=False para evitar avisos con archivos grandes
    df = pd.read_csv(ruta_entrada, low_memory=False)
    
    # 2. FILTRAR: Borrar solo periodos donde la pulsera no estaba grabando
    df_limpio = df[df['missing_value_reason'] != 'device_not_recording'].copy()
    
    # 3. VALIDACIÓN: Comprobar integridad de los datos útiles
    if not df_limpio.empty:
        print(f"ÉXITO: Primer dato útil detectado en: {df_limpio.iloc[0]['timestamp_iso']}")
        print(f"Registros eliminados: {len(df) - len(df_limpio)}")
    else:
        print("CUIDADO: El archivo resultante está VACÍO (todos los datos eran inactivos).")
    
    # 4. GUARDAR
    df_limpio.to_csv(ruta_salida, index=False)
    print(f"Proceso finalizado. Archivo creado en: {ruta_salida}")

# --- EJECUCIÓN ---
if __name__ == "__main__":
    etl_inicial_embrace('accelerometers-std.csv', 'datos_limpios.csv')