 
**Tecnología:** Firebird 3.0 + SymmetricDS 3.16  

Este repositorio contiene los scripts y la guía paso a paso para desplegar una arquitectura de base de datos distribuida para una cadena de hoteles, asegurando la continuidad operativa ante fallos de red mediante replicación asíncrona.

---

## Prerequisitos del Entorno

Antes de comenzar la demostración, asegurar que el equipo cumple con lo siguiente:

1.  **Sistema Operativo:** Windows 10/11.
2.  **Firebird 3.0:** Instalado y corriendo como servicio (SuperServer recomendado).
3.  **Java Runtime (JRE):** Versión 8 o 11 instalada (`java -version`).
4.  **SymmetricDS:** Binarios descomprimidos en una ruta accesible (ej: `C:\symmetric-ds`).
5.  **Jaybird Driver:** El archivo `jaybird-full-4.x.x.jar` debe estar copiado en la carpeta `lib` de SymmetricDS.

---

## Guía de Despliegue "Desde Cero"

Siga estos pasos secuenciales para levantar el entorno durante la defensa.

### PASO 1: Preparación del Directorio de Trabajo
Abrir una consola (CMD) como Administrador y crear una estructura limpia para evitar conflictos de rutas.

```cmd
cd C:\
mkdir TPI_DEMO
cd TPI_DEMO
mkdir DB
mkdir SQL
```
---
Nota: Copiar los archivos schema.sql y sym_config.sql de este repositorio a la carpeta C:\TPI_DEMO\SQL recién creada.

### PASO 2: Creación de Bases de Datos (Firebird)

Utilizaremos isql para crear las bases de datos vacías para la Central (Corp) y la Sucursal (Hotel 1).

1. Abrir la consola SQL:
"C:\Program Files\Firebird\Firebird_3_0\isql.exe" -u sysdba -p masterkey

2. Ejecutar los comandos de creación:
CREATE DATABASE 'C:\TPI_DEMO\DB\CORP.fdb' user 'sysdba' password 'masterkey';
CREATE DATABASE 'C:\TPI_DEMO\DB\HOTEL1.fdb' user 'sysdba' password 'masterkey';
quit;

PASO 3: Configuración de los Nodos (Properties)

Ir a la carpeta engines dentro de su instalación de SymmetricDS y crear los siguientes archivos con el contenido exacto.

Archivo 1: corp-000.properties (Central)
engine.name=corp-000
group.id=corp
external.id=000
# Configuración JDBC (Notar la ruta hacia TPI_DEMO)
db.driver=org.firebirdsql.jdbc.FBDriver
db.url=jdbc:firebirdsql://localhost:3050/C:/TPI_DEMO/DB/CORP.fdb?encoding=UTF8
db.user=sysdba
db.password=masterkey
# Configuración de Sync
registration.url=http://localhost:31415/sync/corp-000
sync.url=http://localhost:31415/sync/corp-000
http.port=31415
# Tiempos de Jobs (Acelerados para la demo)
job.routing.period.time.ms=2000
job.push.period.time.ms=2000
job.pull.period.time.ms=2000
# Fix para UTF8
firebird.extract.varchar.row.old.pk.data=8000,8000,1000

Archivo 2: hotel-001.properties (Sucursal)
engine.name=hotel-001
group.id=hotel
external.id=1
# Configuración JDBC
db.driver=org.firebirdsql.jdbc.FBDriver
db.url=jdbc:firebirdsql://localhost:3050/C:/TPI_DEMO/DB/HOTEL1.fdb?encoding=UTF8
db.user=sysdba
db.password=masterkey
# Apunta a la Central para registrarse
registration.url=http://localhost:31415/sync/corp-000
sync.url=http://localhost:31415/sync/hotel-001
http.port=31415
job.routing.period.time.ms=2000
job.push.period.time.ms=2000
job.pull.period.time.ms=2000
firebird.extract.varchar.row.old.pk.data=8000,8000,1000

PASO 4: Inicialización de SymmetricDS

Desde la carpeta bin de SymmetricDS, ejecutar:

1. Crear tablas de sistema en CORP:
symadmin --engine corp-000 create-sym-tables

2. Importar configuración de replicación (Canales, Routers, Triggers):
dbimport --engine corp-000 C:\TPI_DEMO\SQL\sym_config.sql

PASO 5: Arranque y Registro

1. Abrir el registro para permitir la entrada del Hotel 1:
symadmin --engine corp-000 open-registration hotel 1
2. Iniciar el servidor:
sym
Esperar a ver el mensaje: Registration successful for node hotel:1
Pruebas de Replicación en Vivo

Mantener la consola de sym abierta y abrir dos nuevas consolas para actuar como Central y Hotel.

PRUEBA A: Central crea Hotel -> Baja a Sucursal (Push)

Objetivo: Verificar que los datos maestros creados en HQ bajan al hotel.

1. Conectar a CORP:
"C:\Program Files\Firebird\Firebird_3_0\isql.exe" -u sysdba -p masterkey "localhost:C:\TPI_DEMO\DB\CORP.fdb"

2. Ejecutar SQL:
INSERT INTO HOTEL (ID_HOTEL, NOMBRE, UBICACION) VALUES (1, 'Hotel Demo Central', 'Buenos Aires');
COMMIT;
QUIT;

3. Verificar en HOTEL1:
"C:\Program Files\Firebird\Firebird_3_0\isql.exe" -u sysdba -p masterkey "localhost:C:\TPI_DEMO\DB\HOTEL1.fdb"

SELECT * FROM HOTEL;
-- Resultado esperado: Aparece el registro creado en Central.
QUIT;

PRUEBA B: Sucursal crea Reserva -> Sube a Central (Push)

Objetivo: Verificar que las operaciones diarias suben a la central.

1. Conectar a HOTEL1:
"C:\Program Files\Firebird\Firebird_3_0\isql.exe" -u sysdba -p masterkey "localhost:C:\TPI_DEMO\DB\HOTEL1.fdb"

INSERT INTO HUESPED (ID_HUES, ID_HOTEL, NOMBRE, DOC) VALUES (100, 1, 'Profesor Evaluador', '12345678');
INSERT INTO RESERVA (ID_RES, ID_HOTEL, ID_HUES, ID_HAB, FECHA_DESDE, FECHA_HASTA) 
VALUES (500, 1, 100, 1, '2025-01-01', '2025-01-15');
COMMIT;
QUIT;

3. Verificar en CORP:
"C:\Program Files\Firebird\Firebird_3_0\isql.exe" -u sysdba -p masterkey "localhost:C:\TPI_DEMO\DB\CORP.fdb"

SELECT * FROM RESERVA;
-- Resultado esperado: Aparece la reserva 500.

Solución de Problemas Comunes
Error Connection Refused: SymmetricDS no está corriendo o el puerto 31415 está ocupado por otro proceso.

Error Foreign Key Violation en Hotel: Intentaste insertar una Reserva antes de que llegara el registro del HOTEL desde la central (Prueba A). SymmetricDS respeta el orden, si el Hotel no existe, la reserva falla.

Los datos no viajan: Verificar en los archivos .properties que external.id=1 coincida con el ID_HOTEL=1 insertado en la base de datos.
