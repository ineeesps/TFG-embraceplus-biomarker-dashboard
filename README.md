# TFG-embraceplus-biomarker-dashboard

Este proyecto forma parte de un **Trabajo de Fin de Grado (TFG)** centrado en la monitorización de salud mediante el dispositivo wearable *EmbracePlus* de Empatica. La plataforma permite la ingesta, procesamiento (ETL), limpieza y visualización de biomarcadores biomédicos complejos.

## 🚀 Características Principales
* **Limpieza Automática (ETL):** Script en Python/Pandas que detecta y elimina periodos de inactividad (`device_not_recording`).
* **Módulo de Fiabilidad:** Identificación de registros con baja calidad de señal o movimiento excesivo (`worn_during_motion`).
* **Ingesta de Alta Frecuencia:** Gestión de flujos de datos de hasta 208 Hz (acelerometría) y PPG.
* **Visualización Multiusuario:** Dashboard reactivo en **Flutter** capaz de comparar biomarcadores de varios participantes simultáneamente.

## 🛠️ Stack Tecnológico
Siguiendo una arquitectura de microservicios desacoplada para garantizar escalabilidad y portabilidad:
* **Frontend:** Flutter (Dashboard interactivo).
* **Backend:** FastAPI (Procesamiento asíncrono en Python).
* **Base de Datos:** TimescaleDB (Optimización de series temporales mediante *Hypertables*).
* **Despliegue:** Docker & Docker Compose (Orquestación "llave en mano").

## 📂 Estructura de Datos
El sistema está diseñado para procesar los ficheros CSV generados por EmbracePlus:
* `accelerometers-std.csv`: Desviación estándar de acelerometría.
* `eda.csv`: Actividad Electrodérmica.
* `pulse-rate.csv`: Frecuencia cardíaca.
* `temperature.csv`: Temperatura cutánea.
* `respiratory-rate.csv`: Frecuencia respiratoria.
