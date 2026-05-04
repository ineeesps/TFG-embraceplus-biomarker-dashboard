import os
from cargar_datos import cargar_csv_a_timescale

def ejecutar_ingesta_total(id_participante):
    dir_actual = os.path.dirname(os.path.abspath(__file__))
    ruta_data = os.path.join(dir_actual, '..', 'data')
    
    # Patrones para detectar los 15 tipos de archivos
    patrones = {
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

    print(f"Iniciando orquestador para el participante: {id_participante}")
    archivos_encontrados = os.listdir(ruta_data)
    conteo_exito = 0

    for archivo in archivos_encontrados:
        if archivo.endswith('.csv'):
            for patron, sensor in patrones.items():
                if patron in archivo.lower():
                    print(f"Coincidencia: {archivo} -> {sensor}")
                    try:
                        cargar_csv_a_timescale(archivo, sensor, id_participante)
                        conteo_exito += 1
                    except Exception as e:
                        print(f"Error: {e}")
                    break 

    print(f"\nProceso finalizado. {conteo_exito} archivos cargados correctamente.")

if __name__ == "__main__":
    ejecutar_ingesta_total('Participante_01')