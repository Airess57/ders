"""Minimal Python standard-library bridge to the C temperature analyzer."""

import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parent
PORT = int(os.environ.get("PORT", "8000"))


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path)
        if path.path == "/health":
            return self.respond(200, "text/plain", b"OK\n")
        if path.path == "/":
            return self.respond(200, "text/html; charset=utf-8", (ROOT / "index.html").read_bytes())
        if path.path != "/analyze":
            return self.respond(404, "text/plain", b"Not found\n")
        values = parse_qs(path.query).get("readings", [""])[0].split(",")
        if len(values) > 20:
            return self.json_response(400, False, "Error: maximum 20 readings")
        try:
            result = subprocess.run(
                [str(ROOT / "monitor"), *[value.strip() for value in values]],
                capture_output=True,
                text=True,
                timeout=3,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            return self.json_response(500, False, "Error: monitor unavailable")
        ok = result.returncode == 0
        return self.json_response(
            200 if ok else 400, ok, (result.stdout if ok else result.stderr).strip()
        )

    def json_response(self, status, ok, output):
        return self.respond(
            status,
            "application/json; charset=utf-8",
            json.dumps({"ok": ok, "output": output}).encode(),
        )

    def respond(self, status, content_type, body):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    print(f"Temperature Analyzer listening on port {PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
