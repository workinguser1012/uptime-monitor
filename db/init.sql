CREATE TABLE sites (
  id         SERIAL PRIMARY KEY,
  name       TEXT NOT NULL,
  url        TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE checks (
  id          BIGSERIAL PRIMARY KEY,
  site_id     INT NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  checked_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  up          BOOLEAN NOT NULL,
  status_code INT,
  latency_ms  INT,
  error       TEXT
);
CREATE INDEX checks_site_time ON checks (site_id, checked_at DESC);