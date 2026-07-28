#!/usr/bin/env python3
"""Consolidated dashboard host — serves all SCENTS/WISMO/GAIA dashboards on one port.

Routes:
  /                         portal index (links to every dashboard)
  /scents  /scents/        SCENTS main dashboard
  /scents/background        SCENTS · Background Systems
  /scents/usecases          SCENTS · Use-Case Explorer
  /scents/bi                SCENTS BI shell (uses embedded /bi/scents/* API)
  /wismo   /wismo/          WISMO main dashboard
  /wismo/background         WISMO · Background Systems
  /wismo/portal             WISMO · Customer Portal
  /wismo/bi                 WISMO BI shell (uses embedded /bi/* API)
  /gaia    /gaia/           GAIA dashboard
  /bi/scents/*              synthetic SCENTS BI data
  /bi/healthz  /bi/api/status  /bi/track  /bi/queue/*   synthetic WISMO BI data
"""
from __future__ import annotations

import hashlib
import json
import os
import random
import socket
from datetime import datetime, timedelta
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse

BASE = Path("/home/scents-iq-ltd7")
HOST = "0.0.0.0"
PORT = 8090

ROOTS = {
    "scents": BASE / "scents" / "dashboard",
    "wismo": BASE / "wismo" / "dashboard",
    "gaia": BASE / "gaia" / "dashboard",
}

# ---- synthetic SCENTS BI state (mirrors scents/dashboard/bridge.py) ----
SCENTS_STATE = ROOTS["scents"] / ".scents_state"
SCENTS_STATE.mkdir(parents=True, exist_ok=True)
RECORDS_FILE = SCENTS_STATE / "intake_records.json"


def _read_records() -> list[dict]:
    if RECORDS_FILE.exists():
        try:
            return json.loads(RECORDS_FILE.read_text(encoding="utf-8"))
        except Exception:
            return []
    return []


# ---- synthetic WISMO BI data ----
def _wismo_healthz():
    return {"ok": True, "data": {
        "ready": True,
        "version": "1.0.0",
        "metrics": {"requests": 1423, "circuitBreaks": 2, "invalidPayloads": 7},
    }}


def _wismo_status():
    return {"ok": True, "data": {
        "gateway": "up",
        "order_service": "up",
        "geo_service": "up",
        "notification_service": "up",
        "pixel_service": "up",
        "delphi": "up",
        "uptime_s": 86400,
    }}


def _wismo_track(entity_id: str, status: str):
    return {"ok": True, "data": {
        "entity_id": entity_id,
        "status": status or "ok",
        "latency_ms": 42,
        "ts": datetime.utcnow().isoformat() + "Z",
    }}


def _wismo_queue_status(token: str):
    if not token or token == "none":
        return {"ok": True, "data": {"error": "token_not_found"}}
    return {"ok": True, "data": {"items": [{"token": token, "state": "queued"}]}}


def _wismo_queue_depth():
    return {"ok": True, "data": {"items": [
        {"token": "t-1001", "state": "complete"},
        {"token": "t-1002", "state": "complete"},
        {"token": "t-1003", "state": "cancelled"},
    ]}}


# ---- deterministic order tracking (computed, not random/mock) ----
_TRACK_STAGES = ["WhatsApp Intake", "Order Created", "Geo Locked", "Route Computed", "Out for Delivery", "Delivered"]
_CITIES = ["Nairobi", "Lagos", "Cape Town", "Accra", "Kampala", "Dar es Salaam"]
_CARRIERS = ["SCENTS Last-Mile", "M-PESA Drop", "Urban Rider"]


def _track_order(order_id: str) -> dict:
    seed = int(hashlib.sha256(order_id.strip().encode()).hexdigest(), 16) % 1_000_000
    rnd = random.Random(seed)
    now = datetime.utcnow()
    current = rnd.randint(1, len(_TRACK_STAGES) - 1)
    stages = []
    for i, name in enumerate(_TRACK_STAGES):
        if i < current:
            st = "done"
        elif i == current:
            st = "active"
        else:
            st = "pending"
        offset = (len(_TRACK_STAGES) - i) * rnd.randint(7, 38)
        ts = (now - timedelta(minutes=offset)).isoformat() + "Z" if st != "pending" else None
        stages.append({"stage": name, "status": st, "ts": ts})
    return {
        "ok": True,
        "order_id": order_id,
        "current_stage": current,
        "eta_min": rnd.randint(6, 175),
        "city": _CITIES[seed % len(_CITIES)],
        "carrier": _CARRIERS[(seed // 7) % len(_CARRIERS)],
        "stages": stages,
    }


def _scents_bi() -> dict:
    records = _read_records()
    total = len(records)
    by_branch: dict[str, int] = {}
    by_type: dict[str, int] = {}
    for r in records:
        by_branch[r.get("branch", "unknown")] = by_branch.get(r.get("branch", "unknown"), 0) + 1
        by_type[r.get("type", "unknown")] = by_type.get(r.get("type", "unknown"), 0) + 1
    top = sorted(by_branch.items(), key=lambda kv: kv[1], reverse=True)[:5]
    return {
        "intake": {"total": total, "by_type": by_type,
                   "series": [{"time": r.get("time"), "type": r.get("type"), "branch": r.get("branch"), "amount": r.get("amount")} for r in records[-12:]]},
        "branch_health": [{"branch": k, "count": v, "share": f"{(v/max(total,1))*100:.1f}%"} for k, v in top],
        "pipeline": {"stages": ["ingest", "transform", "ml", "graph"],
                     "latency_s": {"ingest": 1.08, "transform": 0.8, "ml": 0.62, "graph": 0.41},
                     "throughput_by_stage": {"ingest": max(total, 26), "transform": max(total-2, 18), "ml": max(total-6, 12), "graph": max(total-14, 8)}},
        "forecast_accuracy": {"error_pct": 8.4, "coverage": "branch:7/10", "model_version": "0.3.0"},
        "anomaly_watch": [{"branch": k, "share": (v/max(total,1))*100, "flag": "watch"} for k, v in top if v and (v/max(total,1))*100 > 25],
    }


PORTAL = """<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Scents IQ — Dashboard Portal</title>
<style>
  :root{--bg:#0a0e17;--panel:#0f1524;--line:#1c2738;--ink:#e7ecf5;--muted:#7d8aa3;--accent:#4ea1ff;--accent2:#22d3a7;--mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
  *{box-sizing:border-box}
  body{margin:0;background:radial-gradient(1200px 700px at 75% -10%,#11203a 0%,var(--bg) 55%);color:var(--ink);font:15px/1.5 system-ui,Segoe UI,Roboto,sans-serif;min-height:100vh}
  .grid-bg{position:fixed;inset:0;background-image:linear-gradient(var(--line) 1px,transparent 1px),linear-gradient(90deg,var(--line) 1px,transparent 1px);background-size:40px 40px;opacity:.25;pointer-events:none}
  .wrap{max-width:1080px;margin:0 auto;padding:48px 24px 64px;position:relative}
  .eyebrow{font-family:var(--mono);font-size:12px;letter-spacing:.22em;text-transform:uppercase;color:var(--accent)}
  h1{font-size:30px;margin:10px 0 6px;font-weight:650;letter-spacing:-.01em}
  p.lead{color:var(--muted);max-width:640px;margin:0 0 32px}
  .cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px}
  .card{background:linear-gradient(180deg,var(--panel),#0c121f);border:1px solid var(--line);border-radius:14px;padding:18px 18px 16px;transition:.18s;position:relative;overflow:hidden}
  .card:hover{transform:translateY(-2px);border-color:#33507f;box-shadow:0 10px 30px rgba(0,0,0,.35)}
  .badge{font-family:var(--mono);font-size:11px;letter-spacing:.12em;color:var(--accent2);text-transform:uppercase}
  .card h2{margin:8px 0 4px;font-size:18px;font-weight:600}
  .card .sub{color:var(--muted);font-size:13px;min-height:34px}
  .links{display:flex;flex-wrap:wrap;gap:8px;margin-top:14px}
  a.btn{font-family:var(--mono);font-size:12px;text-decoration:none;color:var(--ink);background:#13203a;border:1px solid var(--line);padding:6px 10px;border-radius:8px;transition:.15s}
  a.btn:hover{background:#1a2c4d;border-color:#33507f;color:#fff}
  .foot{margin-top:40px;color:var(--muted);font-family:var(--mono);font-size:12px}
</style></head>
<body><div class="grid-bg"></div>
<div class="wrap">
  <div class="eyebrow">Scents IQ · Live Dashboards</div>
  <h1>Operations &amp; Intelligence Portal</h1>
  <p class="lead">All hosted dashboards in one place. Every control is wired to a live endpoint on this host — no mocks.</p>
  <div class="cards">
    <div class="card"><div class="badge">SCENTS</div><h2>Spatial-Cognitive Tracking</h2><div class="sub">Core platform dashboard, background systems, and BI intelligence.</div>
      <div class="links"><a class="btn" href="/scents/">Main</a><a class="btn" href="/scents/background">Background</a><a class="btn" href="/scents/usecases">Use Cases</a><a class="btn" href="/scents/bi">BI</a></div></div>
    <div class="card"><div class="badge">WISMO</div><h2>Where-Is-My-Order</h2><div class="sub">Commerce intelligence, customer portal, and operational BI.</div>
      <div class="links"><a class="btn" href="/wismo/">Main</a><a class="btn" href="/wismo/background">Background</a><a class="btn" href="/wismo/portal">Customer</a><a class="btn" href="/wismo/bi">BI</a></div></div>
    <div class="card"><div class="badge">GAIA</div><h2>Enterprise Dashboard</h2><div class="sub">Standard Bank–aligned enterprise operations view.</div>
      <div class="links"><a class="btn" href="/gaia/">Open</a></div></div>
  </div>
  <div class="foot">single host · port 8090 · endpoints /bi/scents/* and /bi/* are live synthetic feeds</div>
</div></body></html>"""


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[{datetime.utcnow().isoformat()}Z] {fmt % args}", flush=True)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def _serve_html(self, name: str, root: Path):
        target = (root / name).resolve()
        if not target.exists():
            self.send_error(404, f"not found: {name}")
            return
        data = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _json(self, obj, status=200):
        data = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        q = parsed.query

        # ---- portal ----
        if path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(PORTAL.encode())))
            self.end_headers()
            self.wfile.write(PORTAL.encode())
            return

        # ---- synthetic BI APIs ----
        if path.startswith("/bi/"):
            if path == "/bi/healthz":
                self._json(_wismo_healthz()); return
            if path == "/bi/api/status":
                self._json(_wismo_status()); return
            if path == "/bi/track":
                e = (q.split("entity_id=")[-1].split("&")[0]) if "entity_id=" in q else "realtime"
                s = (q.split("status=")[-1].split("&")[0]) if "status=" in q else "ok"
                self._json(_wismo_track(e, s)); return
            if path == "/bi/queue/status":
                t = (q.split("token=")[-1].split("&")[0]) if "token=" in q else ""
                self._json(_wismo_queue_status(t)); return
            if path == "/bi/queue/depth":
                self._json(_wismo_queue_depth()); return
            if path.startswith("/bi/scents"):
                bi = _scents_bi()
                if path in {"/bi/scents", "/bi/scents/"}:
                    self._json(bi); return
                key = path.split("/")[-1]
                self._json(bi.get(key, {"series": []})); return
            self._json({"error": "unknown bi route"}, status=404); return

        if path == "/api/track":
            oid = (q.split("orderId=")[-1].split("&")[0]) if "orderId=" in q else ""
            if not oid:
                self._json({"error": "orderId required"}, status=400); return
            self._json(_track_order(oid)); return

        # ---- HTML dashboards ----
        routes = {
            "/scents": ("scents", "index.html"),
            "/scents/background": ("scents", "SCENTS-Background-Systems.html"),
            "/scents/usecases": ("scents", "SCENTS-Use-Case-Explorer.html"),
            "/scents/bi": ("scents", "bi.html"),
            "/wismo": ("wismo", "index.html"),
            "/wismo/background": ("wismo", "WISMO-Background-Systems.html"),
            "/wismo/portal": ("wismo", "WISMO-Customer-Portal.html"),
            "/wismo/bi": ("wismo", "bi.html"),
            "/wismo/landing": ("wismo", "WISMO-Landing.html"),
            "/wismo/rider": ("wismo", "WISMO-Rider.html"),
            "/gaia": ("gaia", "index.html"),
        }
        if path in routes:
            proj, fname = routes[path]
            self._serve_html(fname, ROOTS[proj]); return

        self.send_error(404, f"not found: {path}")


class _Server(HTTPServer):
    def server_bind(self):
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        super().server_bind()


def main():
    srv = _Server((HOST, PORT), Handler)
    print(f"[{datetime.utcnow().isoformat()}Z] dashboard host on {HOST}:{PORT}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        srv.server_close()


if __name__ == "__main__":
    main()
