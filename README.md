# Implementation Plan - Hotel Chain Replication (SymmetricDS)

This plan outlines the creation of database scripts and SymmetricDS configuration files to implement the Hub & Spoke replication architecture for the hotel chain.

## User Review Required
> [!IMPORTANT]
> This plan assumes Firebird SQL syntax. Please confirm if a specific version of Firebird (e.g., 2.5, 3.0, 4.0) is targeted, as syntax for identity/sequences may vary. I will default to Firebird 3.0+ syntax.

## Proposed Changes

### Database Schema
We will create SQL scripts to initialize the database structure.

#### [NEW] [schema.sql](file:///c:/Users/nicor/.gemini/antigravity/playground/tensor-prominence/sql/schema.sql)
- DDL for tables: `HOTEL`, `HABITACION`, `HUESPED`, `RESERVA`, `CONSUMO`.
- Primary Keys and Foreign Keys.
- Generators/Sequences for IDs.

### SymmetricDS Configuration
We will create the configuration files required to run the replication.

#### [NEW] [corp.properties](file:///c:/Users/nicor/.gemini/antigravity/playground/tensor-prominence/conf/corp.properties)
- Configuration for the Central Node (Hub).
- Database connection settings (placeholders).
- Registration URL.

#### [NEW] [hotel-template.properties](file:///c:/Users/nicor/.gemini/antigravity/playground/tensor-prominence/conf/hotel-template.properties)
- Template configuration for Hotel Nodes (Spokes).
- Parameterized `external.id` and database paths.

#### [NEW] [sym_config.sql](file:///c:/Users/nicor/.gemini/antigravity/playground/tensor-prominence/sql/sym_config.sql)
- SQL script to populate SymmetricDS system tables (`sym_node_group`, `sym_node_group_link`, `sym_channel`, `sym_trigger`, `sym_router`, `sym_trigger_router`).
- Configuration of the `ID_HOTEL` filter.

## Verification Plan

### Manual Verification
- Review the generated SQL scripts for syntax correctness.
- Review the properties files against SymmetricDS documentation.
- (Optional) If the user has SymmetricDS installed, we can try to start the nodes.
