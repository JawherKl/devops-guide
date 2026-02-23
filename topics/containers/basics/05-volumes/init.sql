-- =============================================================================
-- 05-volumes/init.sql — Volumes demo database schema
-- Auto-runs on first postgres container start
-- =============================================================================

CREATE TABLE IF NOT EXISTS notes (
    id         SERIAL PRIMARY KEY,
    content    TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO notes (content) VALUES
    ('This data lives in a named volume'),
    ('It survives docker rm and docker stop'),
    ('Only docker volume rm destroys it');