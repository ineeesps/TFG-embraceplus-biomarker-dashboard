import pandas as pd

def etl_inicial_embrace(archivo_entrada, archivo_salida):
    print(f"--- Iniciando limpieza de: {archivo_entrada} ---")
    
    # 1. LEER EL ARCHIVO
    df = pd.read_csv(archivo_entrada, low_memory=False)
    
    # 2. FILTRAR: Borrar solo 'device_not_recording'
    df_limpio = df[df['missing_value_reason'] != 'device_not_recording'].copy()
    
    # 3. VALIDACIÓN
    if not df_limpio.empty:
        print(f"Primer dato útil detectado en: {df_limpio.iloc[0]['timestamp_iso']}")
        print(f"Resumen de etiquetas de calidad conservadas:\n{df_limpio['missing_value_reason'].value_counts()}")
    else:
        print("El archivo resultante está VACÍO.")
    
    # 4. GUARDAR
    df_limpio.to_csv(archivo_salida, index=False)
    print(f"Proceso finalizado. Archivo creado: {archivo_salida}")

# --- EJECUCIÓN ---
etl_inicial_embrace('prv.csv', 'datos_limpios.csv')