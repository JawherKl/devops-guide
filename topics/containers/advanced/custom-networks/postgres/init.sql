-- =============================================================================
-- postgres/init.sql — Database initialization for custom-networks demo
-- =============================================================================
-- Runs automatically on first container start via docker-entrypoint-initdb.d/
-- =============================================================================

-- Sample table to verify connectivity from the API
CREATE TABLE IF NOT EXISTS network_tests (
    id         SERIAL PRIMARY KEY,
    tested_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source     VARCHAR(100),
    note       TEXT
);

-- Seed one row so queries return something immediately
INSERT INTO network_tests (source, note) VALUES
    ('init.sql', 'Database initialized successfully via postgres container on backend network');