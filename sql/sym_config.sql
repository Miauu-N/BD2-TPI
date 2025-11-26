-- SymmetricDS Configuration Script (Idempotent for Firebird)

------------------------------------------------------------------------------
-- Node Groups
------------------------------------------------------------------------------
UPDATE OR INSERT INTO sym_node_group (node_group_id, description) 
VALUES ('corp', 'Corporate Central Hub')
MATCHING (node_group_id);

UPDATE OR INSERT INTO sym_node_group (node_group_id, description) 
VALUES ('hotel', 'Hotel Spoke Node')
MATCHING (node_group_id);

------------------------------------------------------------------------------
-- Node Group Links
------------------------------------------------------------------------------
-- Hotel pushes to Corp
UPDATE OR INSERT INTO sym_node_group_link (source_node_group_id, target_node_group_id, data_event_action) 
VALUES ('hotel', 'corp', 'P')
MATCHING (source_node_group_id, target_node_group_id);

-- Corp pushes to Hotel
UPDATE OR INSERT INTO sym_node_group_link (source_node_group_id, target_node_group_id, data_event_action) 
VALUES ('corp', 'hotel', 'P')
MATCHING (source_node_group_id, target_node_group_id);

------------------------------------------------------------------------------
-- Channels
------------------------------------------------------------------------------
UPDATE OR INSERT INTO sym_channel 
(channel_id, processing_order, max_batch_size, enabled, description)
VALUES 
('alta_local', 1, 1000, 1, 'Data generated at hotels')
MATCHING (channel_id);

UPDATE OR INSERT INTO sym_channel 
(channel_id, processing_order, max_batch_size, enabled, description)
VALUES 
('corp_to_hotel', 2, 1000, 1, 'Data from corp to hotels')
MATCHING (channel_id);

------------------------------------------------------------------------------
-- Routers
------------------------------------------------------------------------------
UPDATE OR INSERT INTO sym_router 
(router_id, source_node_group_id, target_node_group_id, router_type, create_time, last_update_time)
VALUES 
('hotel_2_corp', 'hotel', 'corp', 'default', current_timestamp, current_timestamp)
MATCHING (router_id);

UPDATE OR INSERT INTO sym_router 
(router_id, source_node_group_id, target_node_group_id, router_type, router_expression, create_time, last_update_time)
VALUES 
('corp_2_all_hotels', 'corp', 'hotel', 'column', 'ID_HOTEL=:EXTERNAL_ID', current_timestamp, current_timestamp)
MATCHING (router_id);

------------------------------------------------------------------------------
-- Triggers
------------------------------------------------------------------------------

-- 1. Hotel -> Corp
UPDATE OR INSERT INTO sym_trigger 
(trigger_id, source_table_name, channel_id, last_update_time, create_time)
VALUES 
('trig_habitacion', 'HABITACION', 'alta_local', current_timestamp, current_timestamp)
MATCHING (trigger_id);

UPDATE OR INSERT INTO sym_trigger 
(trigger_id, source_table_name, channel_id, last_update_time, create_time)
VALUES 
('trig_huesped', 'HUESPED', 'alta_local', current_timestamp, current_timestamp)
MATCHING (trigger_id);

UPDATE OR INSERT INTO sym_trigger 
(trigger_id, source_table_name, channel_id, last_update_time, create_time)
VALUES 
('trig_reserva', 'RESERVA', 'alta_local', current_timestamp, current_timestamp)
MATCHING (trigger_id);

UPDATE OR INSERT INTO sym_trigger 
(trigger_id, source_table_name, channel_id, last_update_time, create_time)
VALUES 
('trig_consumo', 'CONSUMO', 'alta_local', current_timestamp, current_timestamp)
MATCHING (trigger_id);

-- 2. Corp -> Hotel
UPDATE OR INSERT INTO sym_trigger 
(trigger_id, source_table_name, channel_id, last_update_time, create_time)
VALUES 
('trig_hotel', 'HOTEL', 'corp_to_hotel', current_timestamp, current_timestamp)
MATCHING (trigger_id);

------------------------------------------------------------------------------
-- Trigger Routers
------------------------------------------------------------------------------

-- Link Hotel Data Triggers to Hotel->Corp Router
UPDATE OR INSERT INTO sym_trigger_router 
(trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES 
('trig_habitacion', 'hotel_2_corp', 100, current_timestamp, current_timestamp)
MATCHING (trigger_id, router_id);

UPDATE OR INSERT INTO sym_trigger_router 
(trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES 
('trig_huesped', 'hotel_2_corp', 100, current_timestamp, current_timestamp)
MATCHING (trigger_id, router_id);

UPDATE OR INSERT INTO sym_trigger_router 
(trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES 
('trig_reserva', 'hotel_2_corp', 100, current_timestamp, current_timestamp)
MATCHING (trigger_id, router_id);

UPDATE OR INSERT INTO sym_trigger_router 
(trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES 
('trig_consumo', 'hotel_2_corp', 100, current_timestamp, current_timestamp)
MATCHING (trigger_id, router_id);

-- Link Corp Data Triggers to Corp->Hotel Router
UPDATE OR INSERT INTO sym_trigger_router 
(trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES 
('trig_hotel', 'corp_2_all_hotels', 50, current_timestamp, current_timestamp)
MATCHING (trigger_id, router_id);
