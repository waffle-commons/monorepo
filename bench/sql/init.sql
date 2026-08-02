-- Bench database bootstrap for ALL THREE engines (mounted into
-- /docker-entrypoint-initdb.d/ of the bench-postgres service — runs once per
-- fresh data volume; `docker compose down -v` + `up` re-seeds deterministically).
--
-- Schema = skeleton/migrations/Version2026053101_CreateUsersTable.sql verbatim
-- (same migration exists in workspace; all engines read/write the same table).
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Deterministic 10k-row seed for the read workload (GET /read/demo?id=<uuid>).
--
-- ID DERIVATION SCHEME (k6 scripts MUST use the same derivation — documented in
-- bench/README.md):
--   h  = md5('bench-user-' || n)            -- n in 1..10000
--   id = uuid-formatted h                    -- 8-4-4-4-12 slices of the 32 hex chars
-- e.g. n=1 -> md5('bench-user-1') = 'c5195...' -> 'c5195xxx-xxxx-...'
-- In k6:  const h = crypto.md5(`bench-user-${n}`, 'hex');
--         const id = `${h.substr(0,8)}-${h.substr(8,4)}-${h.substr(12,4)}-${h.substr(16,4)}-${h.substr(20,12)}`;
--
-- Emails are unique per row ('user<n>@bench.waffle.local') so the write workload
-- (POST /write/demo, server-generated values) can never collide with the seed.
INSERT INTO users (id, email, password_hash, created_at)
SELECT
    substr(t.h, 1, 8) || '-' || substr(t.h, 9, 4) || '-' || substr(t.h, 13, 4)
        || '-' || substr(t.h, 17, 4) || '-' || substr(t.h, 21, 12) AS id,
    'user' || t.n || '@bench.waffle.local' AS email,
    md5('bench-pass-' || t.n) AS password_hash,
    NOW() AS created_at
FROM (
    SELECT gs.n AS n, md5('bench-user-' || gs.n) AS h
    FROM generate_series(1, 10000) AS gs(n)
) AS t
ON CONFLICT (id) DO NOTHING;

-- Fast sanity probe used by scripts/run-bench.sh after (re-)seeding.
-- Expected: 10000.
-- SELECT count(*) FROM users WHERE email LIKE '%@bench.waffle.local';
