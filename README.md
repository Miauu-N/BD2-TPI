# Hotel Replication System Walkthrough

This guide explains how to set up and verify the SymmetricDS replication between the Corporate Hub and Hotel Spokes.

## Prerequisites
- **Firebird Database Server**: Version **3.0.x** (SuperServer recommended).
- **SymmetricDS**: Version **3.16.x** (tested with 3.16.8).
- **Java Runtime Environment (JRE)**: Version **8** or **11** (required for SymmetricDS).
- **Firebird JDBC Driver (Jaybird)**: Version **4.x.x** (specifically `jaybird-full-4.x.x.jar`).
    - *Note: Do NOT use Jaybird 5 as it lacks the 'full' jar required by SymmetricDS.*
    - Place this jar in the `lib` folder of your SymmetricDS installation.

## 1. Database Setup

### Create Databases
Create two Firebird databases:
1. `corp.fdb` (Hub)
2. `hotel_001.fdb` (Spoke)

### Initialize Schema
Run `sql/schema.sql` on **BOTH** databases to create the tables and generators.

## 2. SymmetricDS Configuration

### Properties Files
Copy the configuration files to your SymmetricDS `engines` directory (or run standalone).
- `conf/corp.properties` -> `engines/corp-000.properties`
- `conf/hotel-template.properties` -> `engines/hotel-001.properties` (Edit `db.url` as needed).

### Initialize SymmetricDS Tables
Run the following command to create SymmetricDS system tables in the **Corp** database and load the configuration:

```bash
# Assuming you are in the symmetric-ds/bin directory
symadmin --engine corp-000 create-sym-tables
dbimport --engine corp-000 sql/sym_config.sql
```

## 3. Starting Replication

### Open Registration
Before the hotel node can sync, you must allow it to register with the hub. Run this command (you can do this while the server is running in another terminal):

```bash
symadmin --engine corp-000 open-registration hotel 001
```

### Start Server
Start the SymmetricDS server:
```bash
sym
```
Watch the logs. You should see:
1. `corp-000` starting.
2. `hotel-001` starting and attempting to register with `corp-000`.
3. Registration successful.
4. Initial Load (if configured) or just synchronization ready.

### 4. Verification Tests

#### Force Trigger Sync (Important)
After the hotel node registers, it needs to create triggers on your tables. Sometimes this needs a nudge.
Run this command on the **Corp** terminal:
```bash
symadmin --engine corp-000 sync-triggers
```
Watch the hotel logs. You should see `Creating trigger for ...`.

### Test 1: Hotel -> Corp (Alta Local)
1. Run `sql/test_data_hotel_1.sql` on `hotel_001.fdb` (or insert a NEW record manually).
2. Wait for the push interval (default 10s).
3. Check `corp.fdb`. The tables `HABITACION`, `HUESPED`, `RESERVA`, `CONSUMO` should contain the new records.

### Test 2: Corp -> Hotel (Updates)
1. Run `sql/test_data_corp.sql` on `corp.fdb`.
2. Wait for the push/pull interval.
3. Check `hotel_001.fdb`. The `HOTEL` table should be updated.

### Test 3: Filtering
1. Insert a record in `hotel_001.fdb` with a different `ID_HOTEL` (e.g., 999) manually (if not blocked by FK).
2. Verify if it replicates to Corp. (It should, because the filter `ID_HOTEL=:EXTERNAL_ID` is for the router. Wait, if I insert ID_HOTEL=999 in Hotel 1, and External ID is 1, the filter `999 = 1` is False. So it should **NOT** replicate).

## Troubleshooting
- **Missing JDBC Driver**: If you see `java.lang.ClassNotFoundException: org.firebirdsql.jdbc.FBDriver`, it means the Jaybird JAR is not in the `lib` folder or you are using the wrong version.
    1. **Download Jaybird 4** (not 5) from [FirebirdSQL.org](https://firebirdsql.org/en/jdbc-driver/). Jaybird 5 does not include the 'full' jar.
    2. Extract and find **`jaybird-full-4.x.x.jar`**.
    3. Place it in `symmetric-server-x.x.x/lib`.
    4. Remove any `jaybird-5.x` jars.
- **I/O Error / Path Not Found**: If you see `I/O error... D:escu...`, your database path has backslashes that are being eaten.
    - **Fix**: In your `.properties` file, use **forward slashes** (`/`) for the path, even on Windows.
    - Example: `db.url=jdbc:firebirdsql://localhost:3050/D:/escu/Bd/bd2/TPI/hub.fdb`
- **Unique Key / Constraint Violation**: If you see `violation of PRIMARY or UNIQUE KEY constraint`, it means you are running the script on a database that already has the config.
    - **Fix**: Reset the SymmetricDS tables to start fresh:
      ```bash
      symadmin --engine corp-000 uninstall
      symadmin --engine corp-000 create-sym-tables
      ```
- **Dynamic SQL Error / Implementation limit exceeded**: If you see `Data type unknown; Implementation limit exceeded`, it's because Firebird's VARCHAR limit (32KB) is exceeded by SymmetricDS's default cast (20,000 chars * 4 bytes/char = 80KB) when using UTF8.
    - **Fix**: Add this line to your `corp-000.properties` and `hotel-001.properties` files:
      ```properties
      firebird.extract.varchar.row.old.pk.data=8000,8000,1000
      ```
      (This sets the cast sizes for row_data, old_data, and pk_data to safe values).
- **Connection Refused**: If you see `Connection refused` when Corp tries to push to Hotel, it's likely a port mismatch.
    - **Cause**: If running both nodes in the *same* SymmetricDS instance, they share the same web server port (usually 31415). Configuring `hotel-001` to use 8080 works for standalone, but fails here.
- **Data Captured but Not Sent (Router Mismatch)**: If you see data in `SYM_DATA` but it doesn't arrive at Corp, check your IDs.
    - **Cause**: Your database has `ID_HOTEL=1` (integer), but `hotel-001.properties` has `external.id=001`. The router `ID_HOTEL=:EXTERNAL_ID` fails because `1 != 001`.
- **Sync Loop / Batch Errors**: If you see endless "Skipping batch... already loaded" or "Could not find batch to acknowledge".
    - **Cause**: The synchronization state is corrupted, usually after changing IDs or re-registering without clearing history.
    - **Fix (Hard Reset)**:
        1. Stop the server (`Ctrl+C`).
        2. Uninstall tables on **BOTH** nodes:
           ```bash
           symadmin --engine corp-000 uninstall
           symadmin --engine hotel-001 uninstall
           ```
        3. Re-create tables:
           ```bash
           symadmin --engine corp-000 create-sym-tables
           symadmin --engine hotel-001 create-sym-tables
           ```
        4. Re-import config:
           ```bash
           dbimport --engine corp-000 sym_config.sql
           ```
        5. Open registration:
           ```bash
           symadmin --engine corp-000 open-registration hotel 1
           ```
        6. Start server (`sym`).

- **Foreign Key Violation**: If you see `violation of FOREIGN KEY constraint ... reference target does not exist`.
    - **Cause**: You are replicating a child record (e.g., `HUESPED`) but the parent record (e.g., `HOTEL`) does not exist in the destination database.
    - **Fix**: Insert the missing parent record in the destination database manually. For example, ensure `HOTEL` with `ID_HOTEL=1` exists in `corp.fdb`.

## 5. Initial Load (Syncing Old Data)

### Option A: Send Data from Hub -> Hotel (Corp Data)
To send corporate data (like the `HOTEL` table) to a specific hotel:
```bash
symadmin --engine corp-000 reload-node 1
```

### Option B: Send Data from Hotel -> Hub (Local Data)
To send all local data from a hotel to the central hub, it is most reliable to reload each table:

```bash
symadmin --engine hotel-001 reload-table --node 000 HABITACION
symadmin --engine hotel-001 reload-table --node 000 HUESPED
symadmin --engine hotel-001 reload-table --node 000 RESERVA
symadmin --engine hotel-001 reload-table --node 000 CONSUMO
```
*This forces the Hotel node to extract data for these specific tables and send it to node 000 (Corp).*

## 6. Adding a New Hotel (e.g., Hotel 2)
To add another hotel to the network, follow these steps:

### 1. Create the Database
Create a new database (e.g., `hotel_002.fdb`) and run the schema script:
```bash
isql -user sysdba -password masterkey -i sql/schema.sql "jdbc:firebirdsql://localhost:3050/C:/path/to/hotel_002.fdb"
```

### 2. Create Configuration
Copy your working `hotel-001.properties` to `engines/hotel-002.properties` and edit it:
- **`engine.name`**: `hotel-002`
- **`db.url`**: Point to the new `hotel_002.fdb`
- **`external.id`**: `2` (Must match `ID_HOTEL` in your database!)
- **`sync.url`**: `http://localhost:31415/sync/hotel-002` (If running in same instance)

### 3. Register and Start
1.  Open registration on the Hub:
    ```bash
    symadmin --engine corp-000 open-registration hotel 2
    ```
2.  Restart the SymmetricDS server. It will detect the new `hotel-002.properties` file, register the node, and start syncing.

### 4. Create Hotel Record (Important)
Once Hotel 2 is registered, you must define it in the **Hub (Corp)** database so the system knows it exists.
1.  Connect to `corp.fdb`.
2.  Run:
    ```sql
    INSERT INTO HOTEL (ID_HOTEL, NOMBRE, DIRECCION) VALUES (2, 'Hotel 2 Name', 'Address');
    COMMIT;
    ```
3.  SymmetricDS will automatically send this record to `hotel_002.fdb` (because of the `corp_to_hotel` channel).
    *   *Note: If you need to insert data in Hotel 2 immediately before syncing, you can also insert this record manually in `hotel_002.fdb` to avoid Foreign Key errors.*
