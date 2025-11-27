# Tutorial del sistema de replicación de hoteles

Esta guía explica cómo configurar y verificar la replicación de SymmetricDS entre el Corporate Hub y los Hotel Spokes.

## Prerequisitos
- **Servidor de base de datos Firebird**: Versión **3.0.x** (se recomienda SuperServer).
- **SymmetricDS**: Versión **3.16.x** (probado con 3.16.8).
- **Java Runtime Environment (JRE)**: Versión **8** o **11** (requerido para SymmetricDS).
- **Controlador JDBC de Firebird (Jaybird)**: Versión **4.x.x** (específicamente `jaybird-full-4.x.x.jar`).
- *Nota: NO utilice Jaybird 5, ya que carece del jar completo requerido por SymmetricDS.*
- Coloque este jar en la carpeta `lib` de su instalación de SymmetricDS.

## 1. Configuración de la base de datos

### Crear bases de datos
Cree dos bases de datos Firebird:
1. `corp.fdb` (Hub)
2. `hotel_001.fdb` (Spoke)

### Inicializar esquema
Run `sql/schema.sql` en **BOTH** bases de datos para crear las tablas y generadores.

## 2. Configuración de SymmetricDS

### Archivos de propiedades
Copie los archivos de configuración a su SymmetricDS `engines` directorio (o ejecutar de forma independiente).
- `conf/corp.properties` -> `engines/corp-000.properties`
- `conf/hotel-template.properties` -> `engines/hotel-001.properties` (Edite `db.url` según sea necesario).
  
### Inicializar tablas de SymmetricDS
Ejecute el siguiente comando para crear tablas del sistema SymmetricDS en la base de datos **Corp** y cargar la configuración:

```bash
# Suponiendo que se encuentra en el directorio symmetric-ds/bin
symadmin --engine corp-000 create-sym-tables
dbimport --engine corp-000 sql/sym_config.sql
```

## 3. Iniciando replicación

### Abrir registro
Antes de que el nodo del hotel pueda sincronizarse, debe permitir que se registre con el hub. Ejecute este comando (puede hacerlo mientras el servidor se ejecuta en otra terminal):

```bash
symadmin --engine corp-000 open-registration hotel 001
```

### Iniciar Servidor
Inicie el servidor SymmetricDS:
```bash
sym
```
Revisa los registros. Deberías ver:
1. `corp-000` iniciando.
2. `hotel-001` iniciando e intentando registrarse con `corp-000`.
3. Registro exitoso.
4. Carga inicial (si está configurada) o sincronización lista.

### 4. Pruebas de verificación

#### Forzar sincronización de triggers (Importante)
Después de que el nodo del hotel se registre, necesita crear disparadores en sus tablas. A veces, esto requiere un pequeño ajuste.
Ejecute este comando en la terminal **Corp**:
```bash
symadmin --engine corp-000 sync-triggers
```
Revisa los registros del hotel. Deberías verlos. `Creating trigger for ...`.

### Test 1: Hotel -> Corp (Alta Local)
1. Run `sql/test_data_hotel_1.sql` en `hotel_001.fdb` (o insertar un NUEVO registro manualmente).
2. Espere el intervalo de inserción (predeterminado 10 s).
3. Controlar `corp.fdb`. Las tablas `HABITACION`, `HUESPED`, `RESERVA`, `CONSUMO` debe contener los nuevos registros.

### Test 2: Corp -> Hotel (Updates)
1. Run `sql/test_data_corp.sql` en `corp.fdb`.
2. Espere el intervalo de push/pull.
3. Controlar `hotel_001.fdb`. La tabla `HOTEL` debe actualizarse.

### Test 3: Filtracion
1. Inserte un registro en `hotel_001.fdb` con un `ID_HOTEL` diferente (por ejemplo, 999) manualmente (si no está bloqueado por FK).
2. Verifique si se replica a Corp. (Debería, porque el filtro `ID_HOTEL=:EXTERNAL_ID` es para el enrutador. Espere, si inserto ID_HOTEL=999 en Hotel 1, y el ID externo es 1, el filtro `999 = 1` es Falso. Por lo tanto, **NO** debería replicarse).

## Solución de problemas
- **Controlador JDBC faltante**: si ve `java.lang.ClassNotFoundException: org.firebirdsql.jdbc.FBDriver`, significa que el JAR de Jaybird no está en la carpeta `lib` o que está usando la versión incorrecta.
   1. **Descargue Jaybird 4** (no 5) desde [FirebirdSQL.org](https://firebirdsql.org/en/jdbc-driver/). Jaybird 5 no incluye el archivo jar completo.
    2. Extraiga y busque **`jaybird-full-4.x.x.jar`**.
3. Colóquelo en `symmetric-server-x.x.x/lib`.
4. Elimine cualquier archivo jar `jaybird-5.x`.
- **I/O Error / Path Not Found**: Si ve `Error de I/O... D:escu...`, su ruta de base de datos tiene barras invertidas que se están comiendo.
    - **Solución**: En el archivo `.properties`, utilice **barras diagonales** (`/`) para la ruta, incluso en Windows.
    - Ejemplo: `db.url=jdbc:firebirdsql://localhost:3050/D:/escu/Bd/bd2/TPI/hub.fdb`
- **Clave única/Violación de restricción**: Si ve "violación de la restricción CLAVE PRINCIPAL o ÚNICA", significa que está ejecutando el script en una base de datos que ya tiene la configuración.
    - **Solución**: Restablecer las tablas SymmetricDS para comenzar de nuevo:
      ```bash
      symadmin --engine corp-000 uninstall
      symadmin --engine corp-000 create-sym-tables
      ```
- **Dynamic SQL Error / Límite de implementación excedido**: Si ve "Tipo de datos desconocido; límite de implementación excedido", se debe a que el límite VARCHAR de Firebird (32 KB) es excedido por la conversión predeterminada de SymmetricDS (20 000 caracteres * 4 bytes/carácter = 80 KB) cuando se usa UTF8.
    -**Solución**: agregue esta línea a sus archivos `corp-000.properties` y `hotel-001.properties`:
      ```properties
      firebird.extract.varchar.row.old.pk.data=8000,8000,1000
      ```
      (Esto establece los tamaños de conversión para row_data, old_data y pk_data en valores seguros).
- **Conexión rechazada**: si ves `Conexión rechazada` cuando Corp intenta enviar datos al hotel, es probable que se trate de una falta de coincidencia de puertos.
    **Causa**: Si ambos nodos se ejecutan en la *misma* instancia de SymmetricDS, comparten el mismo puerto de servidor web (normalmente 31415). Configurar `hotel-001` para usar 8080 funciona en modo independiente, pero falla en este caso.
- **Datos capturados pero no enviados (falta de coincidencia del enrutador)**: si ve datos en `SYM_DATA` pero no llegan a Corp, verifique sus ID.
    **Causa**: Su base de datos tiene `ID_HOTEL=1` (entero), pero `hotel-001.properties` tiene `external.id=001`. El enrutador `ID_HOTEL=:EXTERNAL_ID` falla porque `1 != 001`.
- **Errores de bucle de sincronización/lote**: si ve un mensaje interminable "Omitiendo lote... ya cargado" o "No se pudo encontrar el lote para confirmar".
    - **Causa**: El estado de sincronización está dañado, generalmente después de cambiar las ID o volver a registrarse sin borrar el historial.
    **Solución (Reinicio completo)**:
1. Detenga el servidor (`Ctrl+C`).
2. Desinstale las tablas en **AMBOS** nodos:
           ```bash
           symadmin --engine corp-000 uninstall
           symadmin --engine hotel-001 uninstall
           ```
        3. Recrear tablas:
           ```bash
           symadmin --engine corp-000 create-sym-tables
           symadmin --engine hotel-001 create-sym-tables
           ```
        4. Reimportar configuración:
           ```bash
           dbimport --engine corp-000 sym_config.sql
           ```
        5. Inscripción abierta:
           ```bash
           symadmin --engine corp-000 open-registration hotel 1
           ```
        6. Iniciar servidor (`sym`).

**Infracción de clave externa**: Si ve el mensaje «Infracción de la restricción de clave externa... el destino de referencia no existe».

**Causa**: Está replicando un registro secundario (p. ej., «HUESPED»), pero el registro principal (p. ej., «HOTEL») no existe en la base de datos de destino.

**Solución**: Inserte manualmente el registro principal que falta en la base de datos de destino. Por ejemplo, asegúrese de que «HOTEL» con «ID_HOTEL=1» exista en «corp.fdb».
## 5. Carga inicial (sincronización de datos antiguos)
### Opción A: Enviar datos desde Hub -> Hotel (Corp Data)
Para enviar datos corporativos (como la tabla 'HOTEL') a un hotel específico:
```bash
symadmin --engine corp-000 reload-node 1
```

### Opción B: Enviar datos desde Hotel -> Hub (Local Data)
Para enviar todos los datos locales de un hotel al centro central, lo más confiable es recargar cada mesa:

```bash
symadmin --engine hotel-001 reload-table --node 000 HABITACION
symadmin --engine hotel-001 reload-table --node 000 HUESPED
symadmin --engine hotel-001 reload-table --node 000 RESERVA
symadmin --engine hotel-001 reload-table --node 000 CONSUMO
```
*Esto obliga al nodo Hotel a extraer datos para estas tablas específicas y enviarlos al nodo 000 (Corp).*

## 6. Agregar un nuevo hotel (e.g., Hotel 2)
Para agregar otro hotel a la red, siga estos pasos:

### 1. Crear la base de datos
Crear una nueva base de datos (e.g., `hotel_002.fdb`) y ejecutar el script de esquema:
```bash
isql -user sysdba -password masterkey -i sql/schema.sql "jdbc:firebirdsql://localhost:3050/C:/path/to/hotel_002.fdb"
```

### 2. Crear configuración
Copia tu trabajo `hotel-001.properties` to `engines/hotel-002.properties` y editarlo:
- **`engine.name`**: `hotel-002`
- **`db.url`**: Señala lo nuevo `hotel_002.fdb`
- **`external.id`**: `2` (Debe coincidir `ID_HOTEL` en su base de datos!)
- **`sync.url`**: `http://localhost:31415/sync/hotel-002` (Si se ejecuta en la misma instancia)

### 3. Regístrate y comienza
1.  Inscripciones abiertas en el Hub:
    ```bash
    symadmin --engine corp-000 open-registration hotel 2
    ```
2.  Reinicie el servidor SymmetricDS. Detectará el nuevo`hotel-002.properties` archivo, registre el nodo y comience a sincronizar.

### 4. Crear registro de hotel (Importante)
Una vez registrado el Hotel 2, debes definirlo en la base de datos de **Hub (Corp)** para que el sistema sepa que existe.
1.  Conectarse a `corp.fdb`.
2.  Run:
    ```sql
    INSERT INTO HOTEL (ID_HOTEL, NOMBRE, DIRECCION) VALUES (2, 'Hotel 2 Name', 'Address');
    COMMIT;
    ```
3.  SymmetricDS enviará automáticamente este registro a `hotel_002.fdb` (debido al canal `corp_to_hotel`).
    *   *Nota: Si necesita insertar datos en el Hotel 2 inmediatamente antes de sincronizar, también puede insertar este registro manualmente en `hotel_002.fdb` para evitar errores de clave foranea.*
