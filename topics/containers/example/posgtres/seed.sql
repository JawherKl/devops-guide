-- =============================================================================
-- postgres/seed.sql — Sample task data
-- Runs after init.sql on first container start
-- ON CONFLICT DO NOTHING = safe to re-run
-- =============================================================================

INSERT INTO tasks (title, description, done) VALUES
    ('Read the containers README',
     'Start from basics/README.md and work through each section in order.',
     true),

    ('Run docker compose up -d',
     'Clone the devops-guide repo, cd into topics/containers/example, then run make dev.',
     true),

    ('Verify network isolation',
     'Run verify-isolation.sh in the custom-networks folder to confirm your network topology is correct.',
     false),

    ('Build a multi-stage Dockerfile',
     'Try the node.dockerfile and go.dockerfile in advanced/multi-stage-build. Run compare-sizes.sh to see the size difference.',
     false),

    ('Scan an image with Trivy',
     'Run trivy-scan.sh against your image. Check the SARIF report in trivy-reports/.',
     false),

    ('Set up a private Docker registry',
     'Follow the registry section in advanced/ to run a self-hosted registry with Docker Compose.',
     false)
ON CONFLICT DO NOTHING;