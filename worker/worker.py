import ipaddress
import logging
import os
import signal
import socket
import time
from concurrent.futures import ThreadPoolExecutor
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener

import psycopg

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("worker")

INTERVAL = int(os.getenv("CHECK_INTERVAL", "30"))
TIMEOUT = float(os.getenv("CHECK_TIMEOUT", "5"))
ALLOW_PRIVATE = os.getenv("ALLOW_PRIVATE_TARGETS", "false").lower() == "true"
stop = False


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):  # a redirect could point at an internal address
        return None


opener = build_opener(NoRedirect)


def is_public(host: str) -> bool:
    """SSRF guard: users supply URLs, so refuse anything resolving to a private address."""
    try:
        addrs = {a[4][0] for a in socket.getaddrinfo(host, None)}
        return bool(addrs) and all(ipaddress.ip_address(a).is_global for a in addrs)
    except (OSError, ValueError):
        return False


def check(site):
    site_id, url = site
    start = time.monotonic()
    code, error = None, None
    if not ALLOW_PRIVATE and not is_public(urlparse(url).hostname or ""):
        error = "blocked: not a public address"
    else:
        try:
            with opener.open(Request(url, headers={"User-Agent": "uptime-monitor/1.0"}), timeout=TIMEOUT) as r:
                code = r.status
        except HTTPError as exc:      # includes 3xx, because redirects are not followed
            code = exc.code
        except Exception as exc:
            error = type(exc).__name__
    ms = round((time.monotonic() - start) * 1000)
    return (site_id, code is not None and code < 400, code, ms, error)


def run_once(url: str):
    with psycopg.connect(url) as conn:
        sites = conn.execute("SELECT id, url FROM sites").fetchall()
        if sites:
            with ThreadPoolExecutor(max_workers=min(10, len(sites))) as pool:
                results = list(pool.map(check, sites))
            with conn.cursor() as cur:
                cur.executemany("INSERT INTO checks (site_id, up, status_code, latency_ms, error) "
                                "VALUES (%s, %s, %s, %s, %s)", results)
        conn.execute("DELETE FROM checks WHERE checked_at < now() - interval '7 days'")
    log.info("checked %d sites", len(sites))


def main():
    global stop
    for sig in (signal.SIGTERM, signal.SIGINT):   # ECS sends SIGTERM on deploys
        signal.signal(sig, lambda *_: globals().update(stop=True))
    url = os.environ["DATABASE_URL"]
    while not stop:
        try:
            run_once(url)
        except Exception:
            log.exception("check cycle failed")
        for _ in range(INTERVAL):
            if stop:
                break
            time.sleep(1)
    log.info("shutting down cleanly")


if __name__ == "__main__":
    main()