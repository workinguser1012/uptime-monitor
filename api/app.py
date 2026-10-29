import logging
import os
import socket
from urllib.parse import urlparse

import psycopg
from flask import Flask, jsonify, request
from psycopg.rows import dict_row

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
app = Flask(__name__)
MAX_SITES = 20


def db():
    return psycopg.connect(os.environ["DATABASE_URL"], row_factory=dict_row)


def valid_url(url: str) -> bool:
    p = urlparse(url)
    return p.scheme in ("http", "https") and bool(p.hostname)


@app.get("/health")
def health():  # liveness: is THIS process alive? (never touches the DB)
    return jsonify({"status": "ok"})


@app.get("/api/ready")
def ready():  # readiness: can we reach the database?
    try:
        with db() as conn:
            conn.execute("SELECT 1")
        return jsonify({"status": "ready"})
    except Exception:
        return jsonify({"status": "db unavailable"}), 503


@app.get("/api/sites")
def list_sites():
    with db() as conn:
        rows = conn.execute("""
            SELECT s.id, s.name, s.url, c.up, c.status_code, c.latency_ms, c.checked_at,
              (SELECT round((100.0 * avg(up::int))::numeric, 1)::float FROM checks
                WHERE site_id = s.id AND checked_at > now() - interval '24 hours') AS uptime_24h
            FROM sites s
            LEFT JOIN LATERAL (SELECT * FROM checks WHERE site_id = s.id
                               ORDER BY checked_at DESC LIMIT 1) c ON true
            ORDER BY s.name""").fetchall()
    return jsonify({"sites": rows, "served_by": socket.gethostname(),
                    "version": os.getenv("GIT_SHA", "dev")})


@app.post("/api/sites")
def add_site():
    data = request.get_json(silent=True) or {}
    name, url = str(data.get("name", "")).strip(), str(data.get("url", "")).strip()
    if not name or len(name) > 60 or not valid_url(url):
        return jsonify({"error": "need a name (max 60 chars) and an http(s) url"}), 400
    with db() as conn:
        if conn.execute("SELECT count(*) AS n FROM sites").fetchone()["n"] >= MAX_SITES:
            return jsonify({"error": f"limit of {MAX_SITES} sites reached"}), 409
        row = conn.execute("INSERT INTO sites (name, url) VALUES (%s, %s) "
                           "ON CONFLICT (url) DO NOTHING RETURNING id", (name, url)).fetchone()
    if row is None:
        return jsonify({"error": "that url is already monitored"}), 409
    return jsonify({"id": row["id"]}), 201


@app.delete("/api/sites/<int:site_id>")
def delete_site(site_id):
    with db() as conn:
        conn.execute("DELETE FROM sites WHERE id = %s", (site_id,))
    return "", 204


@app.get("/api/sites/<int:site_id>/history")
def history(site_id):
    with db() as conn:
        rows = conn.execute("SELECT checked_at, up, status_code, latency_ms, error FROM checks "
                            "WHERE site_id = %s ORDER BY checked_at DESC LIMIT 50", (site_id,)).fetchall()
    return jsonify({"history": rows})