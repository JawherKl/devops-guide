-- =============================================================================
-- postgres/seed.sql — Development seed data
-- Runs after init.sql on first container start
-- =============================================================================

INSERT INTO users (name, email) VALUES
    ('Alice Martin',  'alice@example.com'),
    ('Bob Hassan',    'bob@example.com'),
    ('Carol Zhang',   'carol@example.com')
ON CONFLICT (email) DO NOTHING;