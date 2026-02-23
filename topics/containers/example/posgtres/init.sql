-- =============================================================================
-- postgres/init.sql — Task Manager schema
-- Runs automatically on first container start (docker-entrypoint-initdb.d/)
-- =============================================================================

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    title       VARCHAR(200) NOT NULL CHECK (char_length(trim(title)) > 0),
    description TEXT         NOT NULL DEFAULT '',
    done        BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Index for listing tasks in order
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks (created_at DESC);
-- Index for filtering done vs todo
CREATE INDEX IF NOT EXISTS idx_tasks_done ON tasks (done);

-- Auto-update updated_at on every UPDATE
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tasks_updated_at ON tasks;
CREATE TRIGGER trg_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();