-- Test Data for Corp (Hub)
-- Run this on the Corp database

-- 1. Insert Hotels
INSERT INTO HOTEL (ID_HOTEL, NOMBRE, UBICACION) VALUES (1, 'Hotel Playa', 'Cancun');
INSERT INTO HOTEL (ID_HOTEL, NOMBRE, UBICACION) VALUES (2, 'Hotel Montana', 'Bariloche');

-- 2. Update Hotel Info (to test Corp -> Hotel replication)
UPDATE HOTEL SET UBICACION = 'Cancun - Zona Hotelera' WHERE ID_HOTEL = 1;

COMMIT;
