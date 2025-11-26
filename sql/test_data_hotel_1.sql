-- Test Data for Hotel 1 (ID 100000 range)
-- Run this on the Hotel 1 database

-- 1. Insert Hotel Info (if not present, though usually comes from Corp)
-- For the test, we might need it locally to satisfy FKs if replication hasn't happened yet.
INSERT INTO HOTEL (ID_HOTEL, NOMBRE, UBICACION) VALUES (1, 'Hotel Playa', 'Cancun');

-- 2. Insert Rooms
INSERT INTO HABITACION (ID_HAB, ID_HOTEL, TIPO, ESTADO) VALUES (100001, 1, 'SINGLE', 'DISPONIBLE');
INSERT INTO HABITACION (ID_HAB, ID_HOTEL, TIPO, ESTADO) VALUES (100002, 1, 'DOUBLE', 'OCUPADA');

-- 3. Insert Guest
INSERT INTO HUESPED (ID_HUES, ID_HOTEL, NOMBRE, DOC) VALUES (100001, 1, 'Juan Perez', 'DNI-12345');

-- 4. Insert Reservation
INSERT INTO RESERVA (ID_RES, ID_HOTEL, ID_HUES, ID_HAB, FECHA_DESDE, FECHA_HASTA) 
VALUES (100001, 1, 100001, 100002, '2023-10-01 14:00:00', '2023-10-05 10:00:00');

-- 5. Insert Consumption
INSERT INTO CONSUMO (ID_CONS, ID_HOTEL, ID_RES, DETALLE, MONTO) 
VALUES (100001, 1, 100001, 'Frigobar', 50.00);

COMMIT;
