#!/bin/bash
set -e

# Create database if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE iot' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'iot');
EOSQL

echo "Database initialization completed."
